#!/usr/bin/env bash
# PreToolUse hook guard. Exits 2 (block) when bnb-fixer attempts to Write/Edit a forbidden path.
# When no marker exists (i.e., fixer is not the active agent), always exit 0 (allow).
#
# Hook input arrives as JSON on stdin; we read tool_input.file_path via jq or python.

set -uo pipefail

PROJECT_ROOT="$(pwd)"
BNB="$PROJECT_ROOT/.bnb"

[ -f "$BNB/.active-agent" ] || exit 0
ACTIVE=$(cat "$BNB/.active-agent" 2>/dev/null || echo "")
[ "$ACTIVE" = "bnb-fixer" ] || exit 0

CONFIG="$BNB/config.json"
[ -f "$CONFIG" ] || exit 0

INPUT=$(cat)

extract_file_path() {
  if command -v jq >/dev/null 2>&1; then
    echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty'
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    ti = d.get('tool_input', {})
    print(ti.get('file_path') or ti.get('path') or '')
except Exception:
    print('')
" <<< "$INPUT"
  else
    echo ""
  fi
}

FILE_PATH=$(extract_file_path)
[ -z "$FILE_PATH" ] && exit 0

# Normalize to relative if absolute under project root
case "$FILE_PATH" in
  "$PROJECT_ROOT"/*) REL="${FILE_PATH#$PROJECT_ROOT/}" ;;
  /*) REL="$FILE_PATH" ;;
  *) REL="$FILE_PATH" ;;
esac

# Load patterns
PATTERNS=$(
  if command -v node >/dev/null 2>&1; then
    node -e "const c=require('$CONFIG'); console.log((c.forbidden_write_patterns||[]).join('\n'))"
  else
    python3 -c "import json; print('\n'.join(json.load(open('$CONFIG')).get('forbidden_write_patterns', [])))"
  fi
)

match_any_glob() {
  python3 - "$REL" "$PATTERNS" <<'PY'
import sys, re
path = sys.argv[1]
patterns = [p for p in sys.argv[2].splitlines() if p.strip()]

def glob_to_re(p):
    out = []
    i = 0
    while i < len(p):
        c = p[i]
        if c == '*':
            if i + 1 < len(p) and p[i+1] == '*':
                if i + 2 < len(p) and p[i+2] == '/':
                    out.append('(?:.*/)?')
                    i += 3
                    continue
                out.append('.*')
                i += 2
                continue
            out.append('[^/]*')
        elif c == '?':
            out.append('[^/]')
        else:
            out.append(re.escape(c))
        i += 1
    return '^' + ''.join(out) + '$'

for p in patterns:
    if re.match(glob_to_re(p), path):
        print(p)
        sys.exit(0)
sys.exit(1)
PY
}

if MATCH=$(match_any_glob); then
  echo "break-n-bake guard: bnb-fixer blocked from writing to contract path: $REL (matched pattern: $MATCH)" >&2
  echo "If you believe this file is NOT a contract, edit .bnb/config.json forbidden_write_patterns." >&2
  exit 2
fi

exit 0
