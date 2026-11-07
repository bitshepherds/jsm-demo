#!/usr/bin/env bash
# Replays docs/deployed-versions.md, so the page cannot drift from what jsm really does.
#
# The page records deployments with throwaway tags, so it runs in a throwaway repo: this copies the
# checkout as it stands to a temporary directory, makes it a git repo of its own, and runs every step
# of the page there. Each step asserts its exit code and a key line of jsm's output, and that the page
# quotes that line. The key lines avoid output that a known jsm issue will change: the run counts
# (bitshepherds/json-schema-manager#154) and absolute paths (#156).
#
# The checkout and its tags are never touched, and the last step proves it.
#
# Usage: scripts/replay-deployed-versions.sh
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
page="$repo/docs/deployed-versions.md"
name=replay-deployed-versions

# An exported registry root overrides the current folder (bitshepherds/json-schema-manager#158).
unset JSM_REGISTRY_ROOT_DIR

# tag-deployment makes an annotated tag, which needs a git identity. Give the throwaway repo its
# own, and don't sign, whatever the machine's git config says.
export GIT_AUTHOR_NAME=replay GIT_AUTHOR_EMAIL=replay@example.invalid
export GIT_COMMITTER_NAME=replay GIT_COMMITTER_EMAIL=replay@example.invalid
export GIT_CONFIG_COUNT=2
export GIT_CONFIG_KEY_0=commit.gpgsign GIT_CONFIG_VALUE_0=false
export GIT_CONFIG_KEY_1=tag.gpgsign GIT_CONFIG_VALUE_1=false

tmp=$(mktemp -d "${TMPDIR:-/tmp}/$name.XXXXXX")
work="$tmp/jsm-deployed"
out="$tmp/out"
trap 'rm -rf "$tmp"' EXIT

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

# The checkout's state: tracked changes, every file git doesn't ignore, and every tag.
snapshot() {
  (
    cd "$repo"
    git status --porcelain=v1 --untracked-files=all
    git diff HEAD --binary
    git ls-files -o --exclude-standard | git hash-object --stdin-paths
    git for-each-ref refs/tags
  )
}

before=$(snapshot)

# The throwaway repo: the checkout as it stands, committed or not, minus what git ignores. The page
# clones instead, which gives the same tree once the reader's work is committed.
mkdir -p "$work"
(
  cd "$repo"
  git ls-files -co --exclude-standard | while IFS= read -r f; do
    if [ -e "$f" ]; then printf '%s\n' "$f"; fi
  done
) | (cd "$repo" && tar -cf - -T -) | (cd "$work" && tar -xf -)

cd "$work"
git init -q
git add -A
git commit -qm "clean checkout"

# The page's commands, with colour off so the output can be matched. jsm has no NO_COLOR.
jsm() { go tool jsm -c -r registry "$@"; }

# Make sure jsm is built before the first step, so a build failure isn't read as a step's.
go tool jsm --version > /dev/null

# step NAME EXIT KEY... -- COMMAND...: runs COMMAND, and asserts its exit code, and that its output
# and the page hold each line KEY.
step() {
  local title=$1 want=$2 got=0 key
  local keys=()
  shift 2
  while [ "$1" != "--" ]; do
    keys+=("$1")
    shift
  done
  shift
  "$@" > "$out" 2>&1 || got=$?
  if [ "$got" -ne "$want" ]; then not_ok "$title" "expected exit $want, got $got"; fi
  for key in "${keys[@]}"; do
    if ! grep -qF -- "$key" "$out"; then not_ok "$title" "jsm's output lacks the line: $key"; fi
    if ! grep -qF -- "$key" "$page"; then
      : > "$out"
      not_ok "$title" "docs/deployed-versions.md no longer quotes the line: $key"
    fi
  done
  ok "$title"
}

# shows TEXT: asserts that the page shows TEXT, such as a hand edit or a file it creates.
shows() {
  if ! grep -qF -- "$1" "$page"; then
    : > "$out"
    not_ok "the page shows: $1" "docs/deployed-versions.md no longer shows it"
  fi
}

# edit FILE OLD NEW: the reader's hand edit, which must find OLD exactly once, and which the page
# must show.
edit() {
  local file=$1 old=$2 new=$3 content before after
  shows "$new"
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

# The page's way back to the deployed state.
restore() {
  git restore registry
  git clean -fdq registry
}

# --- Step 1: record a deployment ---

step "tag-deployment prod --no-push records a tag (exit 0)" 0 \
  'Tagged deployment locally (not pushed): jsm-deploy/prod/' -- jsm tag-deployment prod --no-push
: > "$out"
if [ -z "$(git tag -l 'jsm-deploy/prod/*')" ]; then not_ok "tag-deployment prod --no-push records a tag (exit 0)" "no jsm-deploy/prod/* tag"; fi

step "tag-deployment dev --no-push records a tag (exit 0)" 0 \
  'Tagged deployment locally (not pushed): jsm-deploy/dev/' -- jsm tag-deployment dev --no-push

step "check-changes prod passes straight after the deployment (exit 0)" 0 \
  'All changes are valid' -- jsm check-changes prod

# --- Step 2: a deployed version can't change ---

edit registry/order/placed/1/1/0/order_placed_1_1_0.schema.json \
  '"An ISO 4217 code, such as GBP."' '"An ISO 4217 currency code, such as GBP."'
step "editing a deployed schema fails check-changes prod (exit 1)" 1 \
  'Error: cannot modify deployed schemas or their test documents' \
  'order/placed/1/1/0/order_placed_1_1_0.schema.json]' -- jsm check-changes prod
restore

edit registry/deployer/settings/1/0/0/pass/with-timeout.json '"timeout": 300' '"timeout": 600'
step "editing a deployed test document fails check-changes prod (exit 1)" 1 \
  'Error: cannot modify deployed schemas or their test documents' \
  'deployer/settings/1/0/0/pass/with-timeout.json]' -- jsm check-changes prod
restore

# --- Step 3: a deployed version can gain test documents, and a family new versions ---

delivered='{ "parcelId": "PX-0044", "status": "delivered" }'
shows "$delivered"
echo "$delivered" > registry/carrier/tracking/1/0/0/pass/delivered.json
step "create-schema-version makes order response 1.2.0 (exit 0)" 0 \
  'Successfully created new schema with key: order_response_1_2_0' \
  -- jsm create-schema-version order_response_1_1_0 minor
step "adding a test document or a new version passes check-changes prod (exit 0)" 0 \
  'All changes are valid' -- jsm check-changes prod
restore

# --- Step 4: deleting a deployed version ---

shows 'rm -r registry/deployer/settings/1/0/0'
rm -r registry/deployer/settings/1/0/0
step "deleting a deployed config-file version fails check-changes prod (exit 1)" 1 \
  "this family's documents live indefinitely, so documents written under 1.0.0 may still be read" \
  -- jsm check-changes prod
restore

shows 'rm -r registry/order/placed/1/0/0'
rm -r registry/order/placed/1/0/0
step "deleting a retained-stream version at oldestLive fails check-changes prod (exit 1)" 1 \
  "1.0.0 is not below this family's oldestLive 1.0.0, so its documents may still exist" \
  -- jsm check-changes prod

edit registry/order/placed/family.yml 'oldestLive: 1.0.0' 'oldestLive: 1.1.0'
step "deleting a retained-stream version below oldestLive passes check-changes prod (exit 0)" 0 \
  'All changes are valid' -- jsm check-changes prod
restore

# --- Step 5: a deployed version's exceptions ---

longer='{ "customerId": "cus-2026-9012", "name": "Pablo Diego José Francisco de Paula Juan Nepomuceno Ruiz Picasso" }'
shows "$longer"
echo "$longer" > registry/customer/summary/1/1/0/pass/longer-name.json
step "a longer name in a new pass document fails validate (exit 1)" 1 \
  'summary/1/1/0/pass/longer-name.json (no-loosening broken: pass document of 1.1.0 rejected by 1.0.0)' \
  -- jsm validate all -C
entry='  - version: 1.0.0
    document: pass/longer-name.json
    rule: no-loosening
    reason: 1.1.0 sends names of up to 100 characters, which 1.0.0 wrongly rejected.'
shows '    document: pass/longer-name.json'
printf '%s\n' "$entry" >> registry/customer/summary/1/1/0/compat-exceptions.yml
step "a new exception entry clears it in validate (exit 0)" 0 \
  'summary/1/1/0/pass/longer-name.json (no-loosening excepted: pass document of 1.1.0 rejected by 1.0.0)' \
  -- jsm validate all -C
step "adding a new compat-exceptions.yml entry to a deployed version passes check-changes prod (exit 0)" 0 \
  'All changes are valid' -- jsm check-changes prod
restore

edit registry/customer/summary/1/1/0/compat-exceptions.yml \
  'reason: 1.0.0 wrongly rejected names over 50 characters.' \
  'reason: Names over 50 characters were always valid, and 1.0.0 was wrong to reject them.'
step "editing a deployed exception entry fails check-changes prod (exit 1)" 1 \
  'Error: cannot change a deployed exception' \
  "the entry for version 1.0.0, fail/too-long.json, no-loosening can't be edited, or removed while it clears something" \
  -- jsm check-changes prod

# --- Step 6: dev allows mutation ---

step "the same edit passes check-changes dev (exit 0)" 0 \
  'All changes are valid' -- jsm check-changes dev
restore

# --- All ---

: > "$out"
if [ "$(snapshot)" != "$before" ]; then not_ok "leaves the checkout and its tags unchanged" "the checkout or its tags changed during the replay"; fi
ok "leaves the checkout and its tags unchanged"

echo "$name: all $passed steps passed"
