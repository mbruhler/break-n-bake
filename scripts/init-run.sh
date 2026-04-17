#!/usr/bin/env bash
# Initialize a per-run directory at .bnb/<slug>/.
#
# Usage:
#   init-run.sh <slug>
#
# Behavior:
#   - If .bnb/<slug>/ does not exist, create it with the full scaffold
#     (spec/, milestones/, quality/, validation/{eslint,tests,prompts}/,
#     validation-results/raw/, validation-results/fix-cycles/, .snapshots/).
#   - If .bnb/<slug>/ already exists, suffix with -2, -3, … until free.
#   - The slug is passed through slugify.sh's reserved-name guard by the caller;
#     this script trusts the input but will refuse anything that collides with
#     a known project-level file name.
#   - Write the final slug to .bnb/CURRENT_RUN.
#   - Print the final slug on stdout (so callers can capture it) and the
#     absolute run dir path on stderr.

set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
BNB="$PROJECT_ROOT/.bnb"

SLUG="${1:-}"
if [ -z "$SLUG" ]; then
  echo "error: usage: init-run.sh <slug>" >&2
  exit 1
fi

if [ ! -f "$BNB/config.json" ]; then
  echo "error: $BNB/config.json missing; run /break-n-bake:init first." >&2
  exit 1
fi

# Defensive reserved-name check (slugify.sh is the primary guard, but this
# script can be called directly).
case "$SLUG" in
  config|CURRENT_RUN|README|runs|validation|snapshots|active-agent|validation-error)
    echo "error: slug '$SLUG' collides with a reserved project-level name." >&2
    exit 1
    ;;
esac

mkdir -p "$BNB"

FINAL="$SLUG"
i=2
while [ -d "$BNB/$FINAL" ]; do
  FINAL="${SLUG}-${i}"
  i=$((i + 1))
done

RUN_DIR="$BNB/$FINAL"

mkdir -p \
  "$RUN_DIR/spec" \
  "$RUN_DIR/milestones" \
  "$RUN_DIR/quality" \
  "$RUN_DIR/validation/eslint" \
  "$RUN_DIR/validation/tests" \
  "$RUN_DIR/validation/prompts" \
  "$RUN_DIR/validation-results/raw" \
  "$RUN_DIR/validation-results/fix-cycles" \
  "$RUN_DIR/.snapshots"

cat > "$RUN_DIR/README.md" <<EOF
# Run: $FINAL

This directory holds the plan, validation trail, and fix-cycle history for one
break-n-bake run. It is created by \`/break-n-bake:break\` and consumed by
\`/break-n-bake:bake\` and \`/break-n-bake:fix\`.

## Files

- \`_PROMPT.md\` — original prompt, preserved verbatim.
- \`scout-report.json\` — Explorer's reconnaissance output.
- \`questions-before-start.md\` — clarifications to answer before implementation.
- \`spec/\` — what we're building (numbered docs).
- \`milestones/\` — how we build it (M1…M{n} + STATUS + README).
- \`quality/\` — acceptance scenarios, landmines, out-of-scope.
- \`validation/\` — **append-only** programmatic checks (eslint configs, test files, LLM prompts). Seeded by Breaker, added-to by Baker, never edited. See validation/README.md.
- \`validation-results/\` — Validator reports and fix-cycle trail (raw logs gitignored).
- \`.snapshots/\` — integrity hashes (gitignored).

## Activating this run

This run is selected when \`.bnb/CURRENT_RUN\` contains \`$FINAL\`. Override with
\`BNB_RUN=$FINAL\` or \`BNB_RUN_DIR=.bnb/$FINAL\` env vars for a single
invocation.
EOF

cat > "$RUN_DIR/validation/README.md" <<'EOF'
# validation/ — append-only programmatic checks

> If unsure — ask, don't guess.
> **This directory is additive. Existing files are snapshot-locked. New numbered files may be added; existing files may never be edited or deleted.**

## Layout

- `eslint/NNN-<name>.json` — ESLint config overlays. Each file is a valid ESLint config composed into the project's `eslint.config.bnb.mjs` at run activation.
- `tests/NNN-<name>.<ext>` — test files targeting spec acceptance scenarios, discovered landmines, or invariants. Executed via the project's configured test command.
- `prompts/NNN-<name>.md` — LLM-as-judge checks for rules that eslint/tests can't express (e.g., "no business logic in controllers", "no direct DB access from route handlers"). Each prompt is run by a read-only sub-agent during validation.

## Numbering

Files are numbered three-digit prefixes (`001-`, `002-`, …) to preserve creation order and support migration-style reasoning.

- Breaker seeds `001-*` files when the run is created.
- Baker may add `002-*`, `003-*`, … for new surface area introduced by each milestone.
- Numbers never repeat; gaps are allowed but discouraged.

## Immutability

On seed and after each Baker addition, `scripts/validation-lock.sh` records SHA256 hashes of every file here. `snapshot-verify.sh` and the `guard-fixer-paths.sh` hook together refuse any edit or deletion of an already-locked file. New files are allowed.

## Contract

Validator runs every file here every milestone. A failure in any one blocks the milestone. Adding files costs the whole run, not just one milestone — number them only for checks you want to enforce for the remainder of the run.
EOF

printf '%s\n' "$FINAL" > "$BNB/CURRENT_RUN"

printf '%s\n' "$FINAL"
printf '%s\n' "$RUN_DIR" >&2
