#!/usr/bin/env bash
# Compare two validation runs for the same milestone. Print "progress" or "no-progress" on stdout.
#
# Usage: progress-check.sh <milestone-id> <prev-run> <curr-run>
# Example: progress-check.sh M3 run-1 run-2
#
# "progress"      = current blocker set is a proper subset of, or fully different from, previous.
# "no-progress"   = current blocker set matches previous (by id-sorted join) exactly.

set -uo pipefail

MILESTONE="${1:-}"
PREV="${2:-}"
CURR="${3:-}"

if [ -z "$MILESTONE" ] || [ -z "$PREV" ] || [ -z "$CURR" ]; then
  echo "error: usage: progress-check.sh <milestone> <prev-run> <curr-run>" >&2
  exit 1
fi

PROJECT_ROOT="$(pwd)"
BNB="$PROJECT_ROOT/.bnb/validation-results"
PREV_JSON="$BNB/${MILESTONE}-${PREV}.json"
CURR_JSON="$BNB/${MILESTONE}-${CURR}.json"

if [ ! -f "$PREV_JSON" ] || [ ! -f "$CURR_JSON" ]; then
  echo "error: missing one of $PREV_JSON or $CURR_JSON" >&2
  exit 1
fi

extract_signature() {
  local file="$1"
  if command -v node >/dev/null 2>&1; then
    node -e "
      const j = require('$file');
      const sig = (j.blockers || []).map(b => \`\${b.category}:\${b.file}:\${b.line}:\${b.message||''}\`).sort().join('|');
      process.stdout.write(sig);
    "
  else
    python3 -c "
import json, sys
j = json.load(open('$file'))
blockers = j.get('blockers', [])
sig = '|'.join(sorted(f\"{b.get('category')}:{b.get('file')}:{b.get('line')}:{b.get('message','')}\" for b in blockers))
sys.stdout.write(sig)
"
  fi
}

PREV_SIG=$(extract_signature "$PREV_JSON")
CURR_SIG=$(extract_signature "$CURR_JSON")

if [ -z "$CURR_SIG" ]; then
  echo "clean"
  exit 0
fi

if [ "$PREV_SIG" = "$CURR_SIG" ]; then
  echo "no-progress"
else
  echo "progress"
fi
