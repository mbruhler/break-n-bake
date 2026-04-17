#!/usr/bin/env bash
# Called by SubagentStop hook when bnb-fixer finishes. Removes both the
# per-run and project-level active-agent markers.

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_ROOT="$(pwd)"
BNB="$PROJECT_ROOT/.bnb"

RUN_DIR=$("$PLUGIN_ROOT/scripts/resolve-run.sh" 2>/dev/null || true)
if [ -n "$RUN_DIR" ]; then
  rm -f "$RUN_DIR/.active-agent"
fi
rm -f "$BNB/.active-agent"

exit 0
