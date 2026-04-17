#!/usr/bin/env bash
# Run all configured validation commands AND the per-run programmatic checks
# under <run-dir>/validation/. Collects raw output to
# <run-dir>/validation-results/raw/. Always exits 0 — we want raw output,
# not a crash. Validator agent reads and classifies.
#
# Usage: run-validation.sh <milestone-id> <run-id>
# Example: run-validation.sh M3 run-2
#
# Phases:
#   1. Stack-level checks from .bnb/config.json (lint, typecheck, test)
#   2. Per-run eslint overlays in <run-dir>/validation/eslint/*.json
#   3. Per-run test files in <run-dir>/validation/tests/*
#   4. Per-run LLM prompts in <run-dir>/validation/prompts/*.md (see note below)
#
# Prompts are executed by the Validator agent itself (not this shell script)
# — the validator spawns a read-only sub-agent per prompt. This script just
# enumerates the prompt files into a manifest the validator reads.

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
MILESTONE="${1:-unknown}"
RUN="${2:-run-1}"

PROJECT_ROOT="$(pwd)"
BNB="$PROJECT_ROOT/.bnb"
CONFIG="$BNB/config.json"

RUN_DIR=$("$PLUGIN_ROOT/scripts/resolve-run.sh" 2>/dev/null || true)
if [ -z "$RUN_DIR" ]; then
  mkdir -p "$BNB"
  echo '{"error": "no active run; run /break-n-bake:break first"}' > "$BNB/validation-error.json"
  exit 0
fi

RAW_DIR="$RUN_DIR/validation-results/raw"
mkdir -p "$RAW_DIR"

if [ ! -f "$CONFIG" ]; then
  echo '{"error": "no .bnb/config.json; run /break-n-bake:init"}' > "$RAW_DIR/${MILESTONE}-${RUN}.error.json"
  exit 0
fi

read_cmd() {
  local key="$1"
  if command -v node >/dev/null 2>&1; then
    node -e "const c=require('$CONFIG'); const v=c.detected&&c.detected.validation&&c.detected.validation['$key']; process.stdout.write(v||'')"
  else
    python3 -c "import json; c=json.load(open('$CONFIG')); print(c.get('detected',{}).get('validation',{}).get('$key') or '', end='')"
  fi
}

LINT_CMD=$(read_cmd lint)
TYPECHECK_CMD=$(read_cmd typecheck)
TEST_CMD=$(read_cmd test)

run_step() {
  local label="$1"
  local cmd="$2"
  local out="$RAW_DIR/${MILESTONE}-${RUN}.${label}.log"
  if [ -z "$cmd" ]; then
    echo "skipped: no $label command configured" > "$out"
    echo "$label: skipped"
    return 0
  fi
  echo "running $label: $cmd"
  {
    echo "# $label"
    echo "# command: $cmd"
    echo "# cwd: $PROJECT_ROOT"
    echo "# started: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "---"
    eval "$cmd" 2>&1
    echo "---"
    echo "# exit_code: $?"
    echo "# finished: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$out"
  echo "$label: done → $out"
}

# --- Phase 1: stack-level ----------------------------------------------------
run_step lint "$LINT_CMD"
run_step typecheck "$TYPECHECK_CMD"
run_step test "$TEST_CMD"

# --- Phase 2: per-run eslint overlays ---------------------------------------
# Each file in validation/eslint/ is a standalone eslint config applied to the
# project's source tree. We invoke eslint once per file so failures are
# attributable to a specific sealed rule file.
ESLINT_DIR="$RUN_DIR/validation/eslint"
if [ -d "$ESLINT_DIR" ]; then
  # Locate an eslint binary: prefer project-local.
  ESLINT_BIN=""
  if [ -x "$PROJECT_ROOT/node_modules/.bin/eslint" ]; then
    ESLINT_BIN="$PROJECT_ROOT/node_modules/.bin/eslint"
  elif command -v eslint >/dev/null 2>&1; then
    ESLINT_BIN="$(command -v eslint)"
  fi

  for cfg in "$ESLINT_DIR"/*.json; do
    [ -f "$cfg" ] || continue
    base="$(basename "$cfg" .json)"
    out="$RAW_DIR/${MILESTONE}-${RUN}.val-eslint-${base}.log"
    if [ -z "$ESLINT_BIN" ]; then
      echo "skipped: eslint binary not found" > "$out"
      echo "val-eslint/$base: skipped (no eslint)"
      continue
    fi
    echo "running val-eslint/$base"
    {
      echo "# val-eslint"
      echo "# config: $cfg"
      echo "# started: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
      echo "---"
      "$ESLINT_BIN" --config "$cfg" --no-eslintrc . 2>&1
      echo "---"
      echo "# exit_code: $?"
      echo "# finished: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    } > "$out"
    echo "val-eslint/$base: done → $out"
  done
fi

# --- Phase 3: per-run test files --------------------------------------------
# Each file in validation/tests/ is executed via the stack's test runner. We
# rely on the runner to pick up the file by path; for node stacks we pass the
# path directly. Non-node stacks fall back to running the configured TEST_CMD
# with the path as the sole argument.
TESTS_DIR="$RUN_DIR/validation/tests"
if [ -d "$TESTS_DIR" ]; then
  for tf in "$TESTS_DIR"/*; do
    [ -f "$tf" ] || continue
    base="$(basename "$tf")"
    # Skip README / hidden files.
    case "$base" in README*|.*) continue ;; esac

    out="$RAW_DIR/${MILESTONE}-${RUN}.val-test-${base%.*}.log"
    if [ -z "$TEST_CMD" ]; then
      echo "skipped: no test command configured" > "$out"
      echo "val-test/$base: skipped"
      continue
    fi
    echo "running val-test/$base"
    {
      echo "# val-test"
      echo "# file: $tf"
      echo "# command: $TEST_CMD $tf"
      echo "# started: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
      echo "---"
      eval "$TEST_CMD \"$tf\"" 2>&1
      echo "---"
      echo "# exit_code: $?"
      echo "# finished: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    } > "$out"
    echo "val-test/$base: done → $out"
  done
fi

# --- Phase 4: prompts manifest (validator consumes) -------------------------
PROMPTS_DIR="$RUN_DIR/validation/prompts"
MANIFEST="$RAW_DIR/${MILESTONE}-${RUN}.val-prompts.manifest"
: > "$MANIFEST"
if [ -d "$PROMPTS_DIR" ]; then
  for pf in "$PROMPTS_DIR"/*.md; do
    [ -f "$pf" ] || continue
    base="$(basename "$pf")"
    case "$base" in README*) continue ;; esac
    printf '%s\n' "$pf" >> "$MANIFEST"
  done
fi
prompt_count=$(wc -l < "$MANIFEST" | tr -d ' ')
echo "val-prompts: $prompt_count prompt(s) queued for validator → $MANIFEST"

echo "validation complete for $MILESTONE $RUN. raw logs in $RAW_DIR"
exit 0
