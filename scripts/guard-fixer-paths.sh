#!/usr/bin/env bash
# PreToolUse hook guard. Exits 2 (block) when:
#   1. bnb-fixer attempts to Write/Edit a forbidden path (contract files), OR
#   2. ANY agent attempts to Write/Edit a file in <run-dir>/validation/ that
#      is already recorded in <run-dir>/.snapshots/validation.lock. This
#      enforces the additive-only rule for the validation layer.
#
# When no .active-agent marker exists and the path is not under a locked
# validation/ tree, always exit 0 (allow).
#
# Run scoping: forbidden_write_patterns in .bnb/config.json use `.bnb/*/spec/**`
# etc., so glob matching catches contract paths in any run without needing to
# resolve the active run here. The project-level .bnb/.active-agent marker
# stays authoritative for "is fixer running?" — fixer-lock-on.sh writes it
# regardless of which run is active.

set -uo pipefail

PROJECT_ROOT="$(pwd)"
BNB="$PROJECT_ROOT/.bnb"

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

# --- Guard 1: validation/ immutability (all agents) --------------------------
# If the target path is inside any run's validation/ dir AND a matching
# validation.lock recorded this file's pre-existing hash, reject the write.
# New files (not in the lock) are allowed through.
case "$REL" in
  .bnb/*/validation/*)
    # Extract the run slug.
    RUN_SLUG="${REL#.bnb/}"
    RUN_SLUG="${RUN_SLUG%%/*}"
    LOCK="$BNB/$RUN_SLUG/.snapshots/validation.lock"
    if [ -f "$LOCK" ]; then
      # Exact-match relative path in the lock → file was sealed → reject.
      if grep -qE "  ${REL}$" "$LOCK" 2>/dev/null; then
        echo "break-n-bake guard: refused to edit sealed validation file: $REL" >&2
        echo "The validation/ layer is append-only. New numbered files are allowed;" >&2
        echo "existing files (recorded in $LOCK) may not be edited or deleted." >&2
        exit 2
      fi
    fi
    ;;
esac

# --- Guard 2: bnb-fixer contract paths --------------------------------------
if [ -f "$BNB/.active-agent" ]; then
  ACTIVE=$(cat "$BNB/.active-agent" 2>/dev/null || echo "")
  if [ "$ACTIVE" = "bnb-fixer" ] && [ -f "$BNB/config.json" ]; then
    CONFIG="$BNB/config.json"
    PATTERNS=$(
      if command -v node >/dev/null 2>&1; then
        node -e "const c=require('$CONFIG'); console.log((c.forbidden_write_patterns||[]).join('\n'))"
      else
        python3 -c "import json; print('\n'.join(json.load(open('$CONFIG')).get('forbidden_write_patterns', [])))"
      fi
    )

    MATCH=$(python3 - "$REL" "$PATTERNS" <<'PY'
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
    ) || MATCH=""

    if [ -n "$MATCH" ]; then
      echo "break-n-bake guard: bnb-fixer blocked from writing to contract path: $REL (matched pattern: $MATCH)" >&2
      echo "If you believe this file is NOT a contract, edit .bnb/config.json forbidden_write_patterns." >&2
      exit 2
    fi
  fi
fi

exit 0
