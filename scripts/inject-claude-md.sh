#!/usr/bin/env bash
# Idempotently inject a break-n-bake block into the project's CLAUDE.md.
#
# The block is delimited by BEGIN/END markers. Anything between those markers
# is regenerated on every invocation; anything outside is left untouched. If
# CLAUDE.md does not exist, it is created with just the block.
#
# Usage: inject-claude-md.sh [project-root]

set -euo pipefail

PROJECT_ROOT="${1:-$(pwd)}"
FILE="$PROJECT_ROOT/CLAUDE.md"

BEGIN="<!-- BEGIN break-n-bake -->"
END="<!-- END break-n-bake -->"

read -r -d '' BLOCK <<'BLOCK_EOF' || true
<!-- BEGIN break-n-bake -->
## break-n-bake workflow

This project uses the [break-n-bake](https://github.com/mbruhler/break-n-bake) plugin for structured spec-driven implementation. Runs live at `.bnb/<slug>/` (flattened — no `runs/` parent). The active run is resolved via `$BNB_RUN_DIR`, `$BNB_RUN`, or `.bnb/CURRENT_RUN`.

### Commands

- `/break-n-bake:init` — one-time setup (detect stack, write `.bnb/config.json`, seed this block).
- `/break-n-bake:break <prompt>` — scout + plan; creates `.bnb/<slug>/` with `spec/`, `milestones/`, `quality/`, `validation/`.
- `/break-n-bake:bake [M<n>|--all]` — implement the next milestone (or all) under the active run.
- `/break-n-bake:fix` — manually re-run the fix cycle against the latest validation failures.

### Validation layer (append-only)

Each run's `.bnb/<slug>/validation/` directory contains `eslint/`, `tests/`, and `prompts/` subdirectories with numbered files (`001-*`, `002-*`, …). The Breaker seeds this layer from the scout-report and user intent; the Baker may add new numbered files for new surface area. Existing files are snapshot-locked — they can never be edited or deleted.

### IDE integration — ESLint overlay

`.bnb/<slug>/validation/eslint/*.json` are composed into `eslint.config.bnb.mjs` at the project root on every `/break-n-bake:break`. To surface these rules in your editor and CLI, add one line to your real eslint config:

```js
// eslint.config.js (or .mjs)
import bnb from "./eslint.config.bnb.mjs";
export default [
  // ...your existing configs
  ...bnb,
];
```

### Agent skill

The `break-n-bake` skill is auto-loaded when a prompt triggers its heuristics (long prompt, refactor keywords, cross-cutting blast radius). See `skills/break-n-bake/SKILL.md` in the plugin for the full trigger logic.
<!-- END break-n-bake -->
BLOCK_EOF

# Always end BLOCK with a single trailing newline for clean diffs.
BLOCK="${BLOCK%$'\n'}"$'\n'

if [ -f "$FILE" ]; then
  if grep -qF "$BEGIN" "$FILE" && grep -qF "$END" "$FILE"; then
    # Replace existing block via python (portable; handles marker span cleanly).
    BLOCK_CONTENT="$BLOCK" FILE="$FILE" BEGIN="$BEGIN" END="$END" python3 <<'PY'
import os
path = os.environ['FILE']
begin = os.environ['BEGIN']
end = os.environ['END']
block = os.environ['BLOCK_CONTENT']
with open(path, 'r', encoding='utf-8') as f:
    src = f.read()
bi = src.find(begin)
ei = src.find(end)
if bi == -1 or ei == -1 or ei < bi:
    raise SystemExit("markers malformed")
ei_end = ei + len(end)
# Consume a trailing newline after the END marker if present, to avoid drift.
if ei_end < len(src) and src[ei_end] == '\n':
    ei_end += 1
new = src[:bi] + block + src[ei_end:]
with open(path, 'w', encoding='utf-8') as f:
    f.write(new)
PY
    echo "CLAUDE.md: break-n-bake block refreshed ($FILE)"
  else
    printf '\n%s' "$BLOCK" >> "$FILE"
    echo "CLAUDE.md: break-n-bake block appended ($FILE)"
  fi
else
  printf '# Project instructions\n\n%s' "$BLOCK" > "$FILE"
  echo "CLAUDE.md: created with break-n-bake block ($FILE)"
fi
