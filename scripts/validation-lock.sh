#!/usr/bin/env bash
# Record SHA256 hashes of every file currently under the active run's
# validation/ directory, into <run-dir>/.snapshots/validation.lock.
#
# This is the authoritative record of which validation files were "sealed"
# at a given moment. The PreToolUse guard (guard-fixer-paths.sh) rejects any
# Write/Edit to a path already present in this lock. New files (not yet in
# the lock) are allowed — call this script again after adding them to seal.
#
# Call sites:
#   - Breaker: after seeding validation/{eslint,tests,prompts}/001-*.
#   - Baker: after adding new numbered files for a milestone.
#
# Exit 0 on success. Prints a one-line summary to stdout.

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_ROOT="$(pwd)"

RUN_DIR=$("$PLUGIN_ROOT/scripts/resolve-run.sh" 2>/dev/null || true)
if [ -z "$RUN_DIR" ]; then
  echo "error: no active run. Set BNB_RUN, BNB_RUN_DIR, or .bnb/CURRENT_RUN." >&2
  exit 1
fi

VAL_DIR="$RUN_DIR/validation"
if [ ! -d "$VAL_DIR" ]; then
  echo "error: $VAL_DIR does not exist; is the run scaffold complete?" >&2
  exit 1
fi

mkdir -p "$RUN_DIR/.snapshots"
LOCK="$RUN_DIR/.snapshots/validation.lock"
TMP="$LOCK.tmp"

: > "$TMP"

# Collect every file under validation/, relative to project root.
cd "$PROJECT_ROOT"
REL_VAL_DIR="${VAL_DIR#$PROJECT_ROOT/}"

find "$REL_VAL_DIR" -type f \
  ! -name 'README.md' \
  -print 2>/dev/null \
  | LC_ALL=C sort \
  | while IFS= read -r f; do
      [ -f "$f" ] || continue
      hash=$(shasum -a 256 "$f" | awk '{print $1}')
      printf '%s  %s\n' "$hash" "$f" >> "$TMP"
    done

mv "$TMP" "$LOCK"

count=$(wc -l < "$LOCK" | tr -d ' ')
echo "validation-lock: sealed $count file(s) under $REL_VAL_DIR → $LOCK"
