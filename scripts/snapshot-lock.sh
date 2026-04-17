#!/usr/bin/env bash
# Record SHA256 hashes of all files matching forbidden_write_patterns in .bnb/config.json.
# Output: <run-dir>/.snapshots/forbidden-{timestamp}.lock  and  <run-dir>/.snapshots/latest.lock (symlink)
#
# This is the primary mechanical guarantee that Fixer didn't touch contract files.
# The validation/ layer has its own companion lock (validation.lock) written by
# validation-lock.sh; both are verified together by snapshot-verify.sh.

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_ROOT="$(pwd)"
BNB="$PROJECT_ROOT/.bnb"
CONFIG="$BNB/config.json"

if [ ! -f "$CONFIG" ]; then
  echo "error: $CONFIG not found. Run /break-n-bake:init first." >&2
  exit 1
fi

RUN_DIR=$("$PLUGIN_ROOT/scripts/resolve-run.sh" 2>/dev/null || true)
if [ -z "$RUN_DIR" ]; then
  echo "error: no active run. Set BNB_RUN, BNB_RUN_DIR, or .bnb/CURRENT_RUN." >&2
  exit 1
fi

PATTERNS=$(node -e "const c=require('$CONFIG'); console.log((c.forbidden_write_patterns||[]).join('\n'))" 2>/dev/null || \
  python3 -c "import json; print('\n'.join(json.load(open('$CONFIG')).get('forbidden_write_patterns', [])))")

TS=$(date -u +%Y%m%dT%H%M%SZ)
OUT="$RUN_DIR/.snapshots/forbidden-$TS.lock"
mkdir -p "$RUN_DIR/.snapshots"

cd "$PROJECT_ROOT"

> "$OUT"
while IFS= read -r pattern; do
  [ -z "$pattern" ] && continue
  # Convert glob ** to find-compatible; use shopt globstar if available
  # Simpler: rely on git ls-files then filter with shell glob via case
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git ls-files -- "$pattern" 2>/dev/null || true
  else
    find . -path "./node_modules" -prune -o -path "./.git" -prune -o -type f -print 2>/dev/null \
      | grep -E "$(echo "$pattern" | sed -e 's#\*\*/#.*#g' -e 's#\*#[^/]*#g' -e 's#\.#\\.#g')" || true
  fi
done <<< "$PATTERNS" | sort -u | while IFS= read -r f; do
  [ -z "$f" ] && continue
  [ -f "$f" ] || continue
  hash=$(shasum -a 256 "$f" | awk '{print $1}')
  echo "$hash  $f" >> "$OUT"
done

ln -sf "$(basename "$OUT")" "$RUN_DIR/.snapshots/latest.lock"

echo "snapshot locked: $OUT ($(wc -l < "$OUT" | tr -d ' ') files tracked)"
