#!/usr/bin/env bash
# Initialize .bnb/ skeleton in the current project.
#
# Project-level only: writes config.json, README, updates .gitignore, injects
# a break-n-bake block into the project CLAUDE.md, and seeds the project-root
# eslint.config.bnb.mjs overlay. Per-run scaffolding is created separately by
# init-run.sh when /break-n-bake:break starts a new run.
#
# Runs live at `.bnb/<slug>/` (no `runs/` parent). See scripts/slugify.sh for
# the reserved-slug denylist.
#
# Idempotent on missing directories; refuses to overwrite existing config.

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_ROOT="${1:-$(pwd)}"
BNB="$PROJECT_ROOT/.bnb"

if [ -f "$BNB/config.json" ]; then
  echo "break-n-bake already initialized at $BNB"
  echo "Existing config:"
  cat "$BNB/config.json"
  exit 0
fi

mkdir -p "$BNB"

STACK_JSON=$("$PLUGIN_ROOT/scripts/detect-stack.sh" "$PROJECT_ROOT")

MAX_FIX="${CLAUDE_PLUGIN_OPTION_MAX_FIX_ITERATIONS:-5}"
BREAK_THRESH="${CLAUDE_PLUGIN_OPTION_BREAK_THRESHOLD_FILES:-15}"

cat > "$BNB/config.json" <<EOF
{
  "version": "0.5.0",
  "detected": $STACK_JSON,
  "settings": {
    "max_fix_iterations": $MAX_FIX,
    "break_threshold_files": $BREAK_THRESH,
    "no_progress_hard_stop": 3
  },
  "forbidden_write_patterns": [
    "**/*.test.*",
    "**/*.spec.*",
    "**/__tests__/**",
    "**/tests/**",
    ".eslintrc*",
    "eslint.config.*",
    "eslint.config.bnb.mjs",
    "tsconfig*.json",
    "jsconfig.json",
    "vitest.config.*",
    "jest.config.*",
    "playwright.config.*",
    ".bnb/*/spec/**",
    ".bnb/*/quality/**",
    ".bnb/*/milestones/M*-*.md",
    ".bnb/*/validation/**"
  ]
}
EOF

cat > "$BNB/README.md" <<'EOF'
# .bnb/ — break-n-bake workspace

> If unsure — ask, don't guess.

This directory is produced by the `break-n-bake` Claude Code plugin. It holds
project-level config plus one sub-directory per run, addressed directly by slug
(no `runs/` parent).

## Layout

- `config.json` — detected stack, validation commands, forbidden-write patterns. Project-wide; survives across runs.
- `CURRENT_RUN` — plain-text pointer to the active run slug (written by `/break-n-bake:break`, read by every other command).
- `<slug>/` — one directory per `/break-n-bake:break` invocation. Contains `_PROMPT.md`, `spec/`, `milestones/`, `quality/`, `validation/`, `validation-results/`, `.snapshots/`, etc.

## Workflow

1. `/break-n-bake:init` — one time per project.
2. `/break-n-bake:break` — starts a new run under `<slug>/` and sets `CURRENT_RUN`.
3. Answer `<slug>/questions-before-start.md`.
4. `/break-n-bake:bake` — implements the next milestone of the active run.
5. Repeat 4 until `<slug>/milestones/STATUS.md` is all `done`.

## Run selection

The active run is resolved in this order: `$BNB_RUN_DIR` env var → `$BNB_RUN`
slug env var → contents of `.bnb/CURRENT_RUN`. To switch runs, either
`echo <slug> > .bnb/CURRENT_RUN` or set `BNB_RUN=<slug>` for one invocation.

## Immutable validation layer

Each run's `validation/` directory (with `eslint/`, `tests/`, `prompts/`) is
append-only after the Breaker seeds it: new numbered files may be added by the
Baker, but existing files are snapshot-locked and cannot be edited or deleted.
See `<slug>/validation/README.md` for details.
EOF

GITIGNORE="$PROJECT_ROOT/.gitignore"
GITIGNORE_LINES=(
  ".bnb/*/validation-results/raw/"
  ".bnb/*/.snapshots/"
  ".bnb/*/.active-agent"
)
if [ -f "$GITIGNORE" ]; then
  for line in "${GITIGNORE_LINES[@]}"; do
    grep -qxF "$line" "$GITIGNORE" || echo "$line" >> "$GITIGNORE"
  done
else
  printf '%s\n' "${GITIGNORE_LINES[@]}" > "$GITIGNORE"
fi

# Inject break-n-bake block into project CLAUDE.md (idempotent; only content
# between BEGIN/END markers is managed).
"$PLUGIN_ROOT/scripts/inject-claude-md.sh" "$PROJECT_ROOT" || true

# Seed the project-root eslint overlay (no-op when regenerated later per run).
"$PLUGIN_ROOT/scripts/regen-eslint-overlay.sh" "$PROJECT_ROOT" || true

echo "break-n-bake initialized at $BNB"
echo
echo "Detected stack:"
echo "$STACK_JSON"
echo
echo "Next: run /break-n-bake:break with your working prompt."
