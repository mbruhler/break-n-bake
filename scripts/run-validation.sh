#!/usr/bin/env bash
# Run all configured validation commands, collect raw output to .bnb/validation-results/raw/.
# Always exits 0 — we want raw output, not a crash. Validator agent reads and classifies.
#
# Usage: run-validation.sh <milestone-id> <run-id>
# Example: run-validation.sh M3 run-2

set -uo pipefail

MILESTONE="${1:-unknown}"
RUN="${2:-run-1}"

PROJECT_ROOT="$(pwd)"
BNB="$PROJECT_ROOT/.bnb"
CONFIG="$BNB/config.json"
RAW_DIR="$BNB/validation-results/raw"
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

run_step lint "$LINT_CMD"
run_step typecheck "$TYPECHECK_CMD"
run_step test "$TEST_CMD"

echo "validation complete for $MILESTONE $RUN. raw logs in $RAW_DIR"
exit 0
