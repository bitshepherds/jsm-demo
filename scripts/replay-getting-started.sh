#!/usr/bin/env bash
# Replays docs/getting-started.md, so the page cannot drift from what jsm really does.
#
# It copies this checkout to a temporary directory and runs both of the page's routes there:
# every hand edit the page describes, scripted, then the ready-made fix folders copied over the
# registry. Each step asserts its exit code and one key line of jsm's output, and that the page
# quotes that line. The key lines avoid output that a known jsm issue will change: the run counts
# (bitshepherds/json-schema-manager#154), absolute paths (#156) and "a owner-reads" (#153).
#
# The checkout itself is never touched, and the last step proves it.
#
# Usage: scripts/replay-getting-started.sh
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
page="$repo/docs/getting-started.md"
name=replay-getting-started

# An exported registry root overrides the current folder (bitshepherds/json-schema-manager#158).
unset JSM_REGISTRY_ROOT_DIR

work=$(mktemp -d "${TMPDIR:-/tmp}/$name.XXXXXX")
out="$work.out"
trap 'rm -rf "$work" "$out"' EXIT

passed=0

ok() {
  passed=$((passed + 1))
  echo "ok - $name: $1"
}

not_ok() {
  echo "not ok - $name: $1"
  shift
  for line in "$@"; do echo "  $line"; done
  if [ -s "$out" ]; then
    echo "  jsm output:"
    sed 's/^/    /' "$out"
  fi
  exit 1
}

# The checkout's state: tracked changes, and every file git doesn't ignore.
snapshot() {
  (
    cd "$repo"
    git status --porcelain=v1 --untracked-files=all
    git diff HEAD --binary
    git ls-files -o --exclude-standard | git hash-object --stdin-paths
  )
}

before=$(snapshot)

# Copy the checkout as it stands, committed or not, minus what git ignores, and make it a repo of
# its own so the page's git restore works there.
(
  cd "$repo"
  git ls-files -co --exclude-standard | while IFS= read -r f; do
    if [ -e "$f" ]; then printf '%s\n' "$f"; fi
  done
) | (cd "$repo" && tar -cf - -T -) | (cd "$work" && tar -xf -)

cd "$work"
git init -q
git add -A
git -c user.name=replay -c user.email=replay@example.invalid -c commit.gpgsign=false commit -qm "clean checkout"

# The page's commands, with colour off so the output can be matched. jsm has no NO_COLOR.
jsm() { go tool jsm -c -r registry "$@"; }

# Make sure jsm is built before the first step, so a build failure isn't read as a step's.
go tool jsm --version > /dev/null

# step NAME EXIT KEY -- COMMAND...: runs COMMAND, and asserts its exit code and that its output,
# and the page, hold the line KEY.
step() {
  local title=$1 want=$2 key=$3
  shift 4
  local got=0
  "$@" > "$out" 2>&1 || got=$?
  if [ "$got" -ne "$want" ]; then not_ok "$title" "expected exit $want, got $got"; fi
  if ! grep -qF -- "$key" "$out"; then not_ok "$title" "jsm's output lacks the line: $key"; fi
  if ! grep -qF -- "$key" "$page"; then
    : > "$out"
    not_ok "$title" "docs/getting-started.md no longer quotes the line: $key"
  fi
  ok "$title"
}

# edit FILE OLD NEW: the reader's hand edit, which must find OLD exactly once.
edit() {
  local file=$1 old=$2 new=$3 content before after
  content=$(< "$file")
  case $content in
    *"$old"*"$old"*) not_ok "hand edit of $file" "found more than once: $old" ;;
    *"$old"*) ;;
    *) not_ok "hand edit of $file" "not found: $old" ;;
  esac
  # Split around OLD rather than use ${var/old/new}, whose quoting differs in macOS's bash 3.2.
  before=${content%%"$old"*}
  after=${content#*"$old"}
  printf '%s%s%s\n' "$before" "$new" "$after" > "$file"
}

# The page's way back to green.
restore() {
  git restore registry
  git clean -fdq registry
}

request_1_1_0=registry/order/request/1/1/0/order_request_1_1_0.schema.json
response_1_1_0=registry/order/response/1/1/0/order_response_1_1_0.schema.json
make_currency_required() {
  edit "$request_1_1_0" '"required": ["productId", "quantity"]' '"required": ["productId", "quantity", "currency"]'
}

# The exception entry the page shows, word for word.
write_exception() {
  cat > registry/order/request/1/1/0/compat-exceptions.yml << 'EOF'
exceptions:
  - version: 1.0.0
    document: pass/two-widgets.json
    rule: no-tightening
    reason: Every client already sends currency, as the order service has asked since 1.1.0 shipped.
EOF
}

# --- Hand-edit route ---

edit "$response_1_1_0" '"required": ["orderId", "status"]' '"required": ["orderId", "status", "currency"]'
step "hand edit making response currency required validates green (exit 0)" 0 \
  '[PASS] order_response_1_1_0.schema.json' -- jsm validate all -C

step "validate --verbose shows the response's cross-version run" 0 \
  'response/1/1/0/pass/with-currency.json (no-loosening holds: pass document of 1.1.0 accepted by 1.0.0)' \
  -- jsm validate all -C --verbose

make_currency_required
step "hand edit making request currency required fails no-tightening (exit 1)" 1 \
  'no-tightening broken: pass document of 1.0.0 rejected by 1.1.0' -- jsm validate all -C

# Runs both of the page's diffs, and exits with the first non-zero status, so that neither
# command's failure is hidden by the other's success.
diff_both() {
  local response=0 request=0
  jsm diff order_response_1_0_0 order_response_1_1_0 || response=$?
  jsm diff order_request_1_0_0 order_request_1_1_0 || request=$?
  if [ "$response" -ne 0 ]; then return "$response"; fi
  return "$request"
}
step "jsm diff marks both edits narrows" 0 'narrows  /: required requires "currency"' -- diff_both
if [ "$(grep -cF 'narrows  /: required requires "currency"' "$out")" -ne 2 ]; then
  not_ok "jsm diff marks both edits narrows" "expected the narrows line for both families"
fi

step "check-party writer on request 1.0.0 fails (exit 1)" 1 \
  '[FAIL] order_request_1_0_0' -- jsm check-party getting-started/parties/writer.yml

step "check-party reader on request 1.0.0 prints the NOTICE (exit 0)" 0 \
  'no later version can harm a reader on order_request_1_0_0' -- jsm check-party getting-started/parties/reader.yml

restore
step "create-schema-version makes request 2.0.0 (exit 0)" 0 \
  'Successfully created new schema with key: order_request_2_0_0' -- jsm create-schema-version order_request_1_1_0 major
edit registry/order/request/2/0/0/order_request_2_0_0.schema.json \
  '"required": ["productId", "quantity"]' '"required": ["productId", "quantity", "currency"]'
echo '{ "productId": "widget", "quantity": 2 }' > registry/order/request/2/0/0/fail/no-currency.json
step "hand-made major bump validates green (exit 0)" 0 \
  '[PASS] order_request_2_0_0.schema.json' -- jsm validate all -C
: > "$out"
if ! diff -r registry/order/request/2 "$repo/getting-started/fixes/major-bump/order/request/2" > "$out" 2>&1; then
  not_ok "the major-bump fix folder matches the hand edits"
fi
ok "the major-bump fix folder matches the hand edits"

step "after the major bump, check-party warns the 1.0.0 writer to move" 0 \
  'the family has a newer major version, order_request_2_0_0' -- jsm check-party getting-started/parties/writer.yml

restore
make_currency_required
write_exception
step "hand-written exception entry validates green with the run excepted (exit 0)" 0 \
  'no-tightening excepted: pass document of 1.0.0 rejected by 1.1.0' -- jsm validate all -C
: > "$out"
if ! diff registry/order/request/1/1/0/compat-exceptions.yml \
  "$repo/getting-started/fixes/exception/order/request/1/1/0/compat-exceptions.yml" > "$out" 2>&1; then
  not_ok "the exception fix folder matches the hand edit"
fi
ok "the exception fix folder matches the hand edit"

restore
edit "$response_1_1_0" '"enum": ["placed", "shipped"]' '"enum": ["placed", "shipped", "refunded"]'
step "refunded in the response only warns (exit 0)" 0 \
  '/status: enum adds "refunded" (widens): needs a pass document' -- jsm validate all -C

echo '{ "orderId": "ord-1001", "status": "refunded", "currency": "GBP" }' > registry/order/response/1/1/0/pass/refunded.json
step "a pass document using refunded fails (exit 1)" 1 \
  'no-loosening broken: pass document of 1.1.0 rejected by 1.0.0' -- jsm validate all -C

restore
step "git restore returns the registry to green (exit 0)" 0 \
  'Test summary:' -- jsm validate all -C
: > "$out"
if [ -n "$(git status --porcelain)" ]; then not_ok "git restore returns the registry to green (exit 0)" "the copy still has changes"; fi

# --- Fix-folder route ---

make_currency_required
cp -R "$repo/getting-started/fixes/major-bump/." registry/
step "major-bump fix folder over the broken request validates green (exit 0)" 0 \
  '[PASS] order_request_2_0_0.schema.json' -- jsm validate all -C

restore
make_currency_required
cp -R "$repo/getting-started/fixes/exception/." registry/
step "exception fix folder over the broken request validates green with the run excepted (exit 0)" 0 \
  'no-tightening excepted: pass document of 1.0.0 rejected by 1.1.0' -- jsm validate all -C

# --- Both ---

: > "$out"
if [ "$(snapshot)" != "$before" ]; then not_ok "leaves the checkout unchanged" "the checkout changed during the replay"; fi
ok "leaves the checkout unchanged"

echo "$name: all $passed steps passed"
