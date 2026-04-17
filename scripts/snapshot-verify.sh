#!/usr/bin/env bash
# Verify that no file in the latest snapshot has been modified.
# Exit 0 if all hashes match, exit 2 (block-worthy) if any drift detected.
# Prints the offending files to stderr.

set -uo pipefail

PROJECT_ROOT="$(pwd)"
BNB="$PROJECT_ROOT/.bnb"
LOCK="$BNB/.snapshots/latest.lock"

if [ ! -e "$LOCK" ]; then
  echo "snapshot-verify: no lock file found at $LOCK; did you run snapshot-lock.sh?" >&2
  exit 1
fi

drift_count=0
drift_files=()

while IFS= read -r line; do
  [ -z "$line" ] && continue
  expected_hash="${line%% *}"
  file="${line#*  }"
  [ -f "$file" ] || { drift_count=$((drift_count+1)); drift_files+=("DELETED: $file"); continue; }
  actual_hash=$(shasum -a 256 "$file" | awk '{print $1}')
  if [ "$expected_hash" != "$actual_hash" ]; then
    drift_count=$((drift_count+1))
    drift_files+=("MODIFIED: $file")
  fi
done < "$LOCK"

if [ "$drift_count" -gt 0 ]; then
  echo "snapshot-verify: FAIL — $drift_count contract file(s) modified:" >&2
  for f in "${drift_files[@]}"; do
    echo "  $f" >&2
  done
  echo "" >&2
  echo "These files are under contract protection. If the changes were legitimate," >&2
  echo "review them manually or run: git checkout -- <paths>" >&2
  exit 2
fi

echo "snapshot-verify: OK — all $(wc -l < "$LOCK" | tr -d ' ') tracked files unchanged"
exit 0
