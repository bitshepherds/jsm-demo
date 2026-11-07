#!/usr/bin/env bash
# Checks the breaking edit on each page under docs/scenarios/, so the pages cannot drift from what jsm
# really does.
#
# It copies registry/ to a temporary directory, and for each page makes the page's one-line hand edit
# there, on a fresh copy each time. It asserts jsm's exit code, and that jsm names the expected rule
# and document, and that the page shows the edit and quotes those lines. It checks too that config-file
# needs its migration statement, and that moving retained-stream's oldestLive forward retires the
# older version. The key lines avoid output that a known jsm issue will change: the run counts
# (bitshepherds/json-schema-manager#154), absolute paths (#156) and "a owner-reads" (#153).
#
# The checkout itself is never touched, and the last step proves it.
#
# Usage: scripts/check-scenarios.sh
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
pages="$repo/docs/scenarios"
name=check-scenarios

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

# A fresh copy of the checkout's registry, as it stands, committed or not.
fresh() {
  rm -rf "$work/registry"
  cp -R "$repo/registry" "$work/registry"
}

# jsm on the copy, with colour off so the output can be matched. jsm has no NO_COLOR. It runs from
# the checkout, since go tool needs go.mod, but reads and writes only the copy.
jsm() { (cd "$repo" && go tool jsm -c -r "$work/registry" "$@"); }

# Make sure jsm is built before the first check, so a build failure isn't read as a check's.
jsm --version > /dev/null

# edit PAGE FILE OLD NEW: the page's hand edit, on the copy. It must find OLD exactly once in FILE,
# and the page must show NEW, so the page and this check make the same edit.
edit() {
  local page=$1 file=$2 old=$3 new=$4 content before after
  if ! grep -qF -- "$new" "$pages/$page"; then
    : > "$out"
    not_ok "hand edit of $file" "docs/scenarios/$page no longer shows the edit: $new"
  fi
  content=$(< "$work/$file")
  case $content in
    *"$old"*"$old"*) not_ok "hand edit of $file" "found more than once: $old" ;;
    *"$old"*) ;;
    *) not_ok "hand edit of $file" "not found: $old" ;;
  esac
  # Split around OLD rather than use ${var/old/new}, whose quoting differs in macOS's bash 3.2.
  before=${content%%"$old"*}
  after=${content#*"$old"}
  printf '%s%s%s\n' "$before" "$new" "$after" > "$work/$file"
}

# delete PAGE FILE LINE: the page's hand edit that deletes LINE, on the copy. FILE must hold LINE
# exactly once, and the page must quote it.
delete() {
  local page=$1 file=$2 line=$3
  if ! grep -qF -- "$line" "$pages/$page"; then
    : > "$out"
    not_ok "hand edit of $file" "docs/scenarios/$page no longer shows the line to delete: $line"
  fi
  if [ "$(grep -cxF -- "$line" "$work/$file")" -ne 1 ]; then
    not_ok "hand edit of $file" "not found exactly once: $line"
  fi
  grep -vxF -- "$line" "$work/$file" > "$work/$file.new" || true
  mv "$work/$file.new" "$work/$file"
}

# validate TITLE PAGE EXIT KEY...: validates the copy, and asserts its exit code, and that its output
# and the page hold each line KEY.
validate() {
  local title=$1 page=$2 want=$3 got=0 key
  shift 3
  jsm validate all -C > "$out" 2>&1 || got=$?
  if [ "$got" -ne "$want" ]; then not_ok "$title" "expected exit $want, got $got"; fi
  for key in "$@"; do
    if ! grep -qF -- "$key" "$out"; then not_ok "$title" "jsm's output lacks the line: $key"; fi
    if [ -n "$page" ] && ! grep -qF -- "$key" "$pages/$page"; then
      : > "$out"
      not_ok "$title" "docs/scenarios/$page no longer quotes the line: $key"
    fi
  done
  ok "$title"
}

# --- The registry as committed ---

fresh
validate "the registry starts green" "" 0 'Test summary:'

# --- owner-writes: the order API's response ---

fresh
edit owner-writes.md registry/order/response/1/1/0/order_response_1_1_0.schema.json \
  '"status": { "enum": ["placed", "shipped"] }' '"status": { "type": "string" }'
validate "owner-writes breaking edit is refused by no-loosening" owner-writes.md 1 \
  '[FAIL] order_response_1_1_0.schema.json' \
  'response/1/0/0/fail/unknown-status.json (no-loosening broken: fail document of 1.0.0 accepted by 1.1.0)'

# --- owner-reads: the order API's request ---

fresh
edit owner-reads.md registry/order/request/1/1/0/order_request_1_1_0.schema.json \
  '"required": ["productId", "quantity"]' '"required": ["productId", "quantity", "currency"]'
validate "owner-reads breaking edit is refused by no-tightening" owner-reads.md 1 \
  '[FAIL] order_request_1_1_0.schema.json' \
  'request/1/0/0/pass/two-widgets.json (no-tightening broken: pass document of 1.0.0 rejected by 1.1.0)'

# --- config-file: a deployment tool's settings ---

fresh
edit config-file.md registry/deployer/settings/1/1/0/deployer_settings_1_1_0.schema.json \
  '"timeout": {' '"timeoutSeconds": {'
validate "config-file breaking edit is refused by no-tightening" config-file.md 1 \
  '[FAIL] deployer_settings_1_1_0.schema.json' \
  'settings/1/0/0/pass/with-timeout.json (no-tightening broken: pass document of 1.0.0 rejected by 1.1.0)'

fresh
delete config-file.md registry/deployer/settings/family.yml 'migrations:'
delete config-file.md registry/deployer/settings/family.yml \
  "  2: The deployer's upgrade command renames timeout to timeoutSeconds in each settings file it finds."
validate "config-file without its migration statement is refused" config-file.md 1 \
  '[FAIL] deployer_settings_2_0_0.schema.json' \
  'major 2 needs a migration statement: in a config-file family old documents stay around'

# --- stored-one-schema: customer profiles ---

fresh
edit stored-one-schema.md registry/customer/profile/1/1/0/customer_profile_1_1_0.schema.json \
  '"required": ["customerId", "name"]' '"required": ["customerId", "name", "email"]'
validate "stored-one-schema breaking edit is refused by no-tightening" stored-one-schema.md 1 \
  '[FAIL] customer_profile_1_1_0.schema.json' \
  'profile/1/0/0/pass/signed-up-without-email.json (no-tightening broken: pass document of 1.0.0 rejected by 1.1.0)'

# --- stored-self-naming: issued invoices ---

fresh
edit stored-self-naming.md registry/billing/invoice/1/1/0/billing_invoice_1_1_0.schema.json \
  '"schemaVersion": { "const": "1.1.0" }' '"schemaVersion": { "const": "1.0.0" }'
validate "stored-self-naming edit is refused as its own pass document failing" stored-self-naming.md 1 \
  '[FAIL] billing_invoice_1_1_0.schema.json' \
  'invoice/1/1/0/pass/issued-2026.json (failed)'

# --- retained-stream: an order event log ---

fresh
edit retained-stream.md registry/order/placed/1/1/0/order_placed_1_1_0.schema.json \
  '"required": ["orderId", "total"]' '"required": ["orderId", "total", "currency"]'
validate "retained-stream breaking edit is refused while oldestLive names the older version" retained-stream.md 1 \
  '[FAIL] order_placed_1_1_0.schema.json' \
  'placed/1/0/0/pass/no-currency.json (no-tightening broken: pass document of 1.0.0 rejected by 1.1.0)'

edit retained-stream.md registry/order/placed/family.yml 'oldestLive: 1.0.0' 'oldestLive: 1.1.0'
validate "retained-stream breaking edit passes once oldestLive moves forward" retained-stream.md 0 \
  '[PASS] order_placed_1_1_0.schema.json'

# --- uncoordinated: synced notes ---

fresh
edit uncoordinated.md registry/notes/note/1/1/0/notes_note_1_1_0.schema.json \
  '"required": ["noteId", "text", "state"]' '"required": ["noteId", "text", "state", "updatedAt"]'
validate "uncoordinated breaking edit is refused" uncoordinated.md 1 \
  '[FAIL] notes_note_1_1_0.schema.json' \
  'note/1/0/0/pass/shopping-list.json (no-tightening broken: pass document of 1.0.0 rejected by 1.1.0)'

# --- lock-step: a batch job's plan ---

fresh
edit lock-step.md registry/batch/plan/1/1/0/batch_plan_1_1_0.schema.json \
  '"required": ["jobId", "tasks"]' '"required": ["jobId", "taks"]'
validate "lock-step edit is refused as its own pass document failing" lock-step.md 1 \
  '[FAIL] batch_plan_1_1_0.schema.json' \
  'plan/1/1/0/pass/nightly.json (failed)'

# --- third-party-format: a carrier's tracking webhook ---

fresh
edit third-party-format.md registry/carrier/tracking/1/1/0/carrier_tracking_1_1_0.schema.json \
  '"in-transit", "out-for-delivery", "held-at-customs"' '"in-transit", "held-at-customs"'
validate "third-party-format breaking edit is refused by no-tightening" third-party-format.md 1 \
  '[FAIL] carrier_tracking_1_1_0.schema.json' \
  'tracking/1/0/0/pass/out-for-delivery.json (no-tightening broken: pass document of 1.0.0 rejected by 1.1.0)' \
  'this says the real format has changed'

# --- All ---

: > "$out"
if [ "$(snapshot)" != "$before" ]; then not_ok "leaves the checkout unchanged" "the checkout changed during the check"; fi
ok "leaves the checkout unchanged"

echo "$name: all $passed checks passed"
