#!/usr/bin/env bash
# Verify that no file in the active run's latest snapshot (or validation.lock)
# has been modified or deleted. Exit 0 if all hashes match, exit 2 if drift.
# Prints offending files to stderr.
#
# Covers two lock families:
#   - <run-dir>/.snapshots/latest.lock    (contract-file integrity; written by snapshot-lock.sh)
#   - <run-dir>/.snapshots/validation.lock (validation/ additive-only; written by validation-lock.sh)
#
# Both are optional individually; at least one must exist for a meaningful
# verification. When neither exists, exit 0 with a notice.

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

RUN_DIR=$("$PLUGIN_ROOT/scripts/resolve-run.sh" 2>/dev/null || true)
if [ -z "$RUN_DIR" ]; then
  echo "snapshot-verify: no active run resolved; did you run /break-n-bake:break?" >&2
  exit 1
fi

CONTRACT_LOCK="$RUN_DIR/.snapshots/latest.lock"
VAL_LOCK="$RUN_DIR/.snapshots/validation.lock"

if [ ! -e "$CONTRACT_LOCK" ] && [ ! -e "$VAL_LOCK" ]; then
  echo "snapshot-verify: no lock files found under $RUN_DIR/.snapshots/; nothing to verify."
  exit 0
fi

drift_count=0
drift_files=()

verify_lock() {
  local lock="$1"
  local label="$2"
  [ -f "$lock" ] || return 0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    local expected_hash="${line%% *}"
    local file="${line#*  }"
    if [ ! -f "$file" ]; then
      drift_count=$((drift_count+1))
      drift_files+=("DELETED [$label]: $file")
      continue
    fi
    local actual_hash
    actual_hash=$(shasum -a 256 "$file" | awk '{print $1}')
    if [ "$expected_hash" != "$actual_hash" ]; then
      drift_count=$((drift_count+1))
      drift_files+=("MODIFIED [$label]: $file")
    fi
  done < "$lock"
}

verify_lock "$CONTRACT_LOCK" "contract"
verify_lock "$VAL_LOCK" "validation"

if [ "$drift_count" -gt 0 ]; then
  echo "snapshot-verify: FAIL — $drift_count file(s) drifted:" >&2
  for f in "${drift_files[@]}"; do
    echo "  $f" >&2
  done
  echo "" >&2
  echo "Contract drift (fixer touched a protected file) requires: git checkout -- <paths>" >&2
  echo "Validation drift (edits to sealed additive layer) requires reverting the change;" >&2
  echo "validation/ is append-only — add a new numbered file instead of editing." >&2
  exit 2
fi

total=0
[ -f "$CONTRACT_LOCK" ] && total=$((total + $(wc -l < "$CONTRACT_LOCK" | tr -d ' ')))
[ -f "$VAL_LOCK" ] && total=$((total + $(wc -l < "$VAL_LOCK" | tr -d ' ')))
echo "snapshot-verify: OK — $total tracked file(s) unchanged across contract+validation locks"
exit 0
