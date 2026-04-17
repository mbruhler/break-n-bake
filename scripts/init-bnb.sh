#!/usr/bin/env bash
# Initialize .bnb/ skeleton in the current project.
# Idempotent on missing directories; refuses to overwrite existing content.

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

mkdir -p \
  "$BNB/spec" \
  "$BNB/milestones" \
  "$BNB/quality" \
  "$BNB/validation-results/raw" \
  "$BNB/validation-results/fix-cycles" \
  "$BNB/.snapshots"

STACK_JSON=$("$PLUGIN_ROOT/scripts/detect-stack.sh" "$PROJECT_ROOT")

MAX_FIX="${CLAUDE_PLUGIN_OPTION_MAX_FIX_ITERATIONS:-5}"
BREAK_THRESH="${CLAUDE_PLUGIN_OPTION_BREAK_THRESHOLD_FILES:-15}"

cat > "$BNB/config.json" <<EOF
{
  "version": "0.1.0",
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
    "tsconfig*.json",
    "jsconfig.json",
    "vitest.config.*",
    "jest.config.*",
    "playwright.config.*",
    ".bnb/spec/**",
    ".bnb/quality/**",
    ".bnb/milestones/M*-*.md"
  ]
}
EOF

cat > "$BNB/README.md" <<'EOF'
# .bnb/ — break-n-bake workspace

> If unsure — ask, don't guess.

This directory is produced by the `break-n-bake` Claude Code plugin. It contains the plan, the validation trail, and the fix-cycle history for non-trivial work in this project.

## Layout (populated by `/break-n-bake:break`)

- `_PROMPT.md` — original prompt, preserved verbatim.
- `scout-report.json` — Explorer's reconnaissance output.
- `questions-before-start.md` — clarifications to answer before implementation.
- `spec/` — what we're building (numbered docs).
- `milestones/` — how we build it (M1…M{n} + STATUS + README).
- `quality/` — acceptance scenarios, landmines, out-of-scope.
- `validation-results/` — Validator reports and fix-cycle trail (mostly gitignored).
- `.snapshots/` — integrity hashes (gitignored).

## Workflow

1. `/break-n-bake:break` — scout + plan.
2. Answer `questions-before-start.md`.
3. `/break-n-bake:bake` — implement next milestone.
4. Repeat 3 until `STATUS.md` is all `done`.

If nothing is here yet, run `/break-n-bake:break` with your working prompt.
EOF

GITIGNORE="$PROJECT_ROOT/.gitignore"
GITIGNORE_LINES=(
  ".bnb/validation-results/raw/"
  ".bnb/.snapshots/"
  ".bnb/.active-agent"
)
if [ -f "$GITIGNORE" ]; then
  for line in "${GITIGNORE_LINES[@]}"; do
    grep -qxF "$line" "$GITIGNORE" || echo "$line" >> "$GITIGNORE"
  done
else
  printf '%s\n' "${GITIGNORE_LINES[@]}" > "$GITIGNORE"
fi

echo "break-n-bake initialized at $BNB"
echo
echo "Detected stack:"
echo "$STACK_JSON"
echo
echo "Next: run /break-n-bake:break with your working prompt."
