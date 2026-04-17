#!/usr/bin/env bash
# Called by SubagentStart hook when bnb-fixer begins.
# Writes a marker that guard-fixer-paths.sh checks on every Write/Edit PreToolUse.
# Marker is placed inside the active run dir; a project-level pointer mirrors it
# so the guard can find it without re-resolving the run from scratch on every call.

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_ROOT="$(pwd)"
BNB="$PROJECT_ROOT/.bnb"
mkdir -p "$BNB"

RUN_DIR=$("$PLUGIN_ROOT/scripts/resolve-run.sh" 2>/dev/null || true)
if [ -n "$RUN_DIR" ]; then
  mkdir -p "$RUN_DIR"
  echo "bnb-fixer" > "$RUN_DIR/.active-agent"
fi

# Project-level fallback so the guard can find the marker even if the run
# resolves differently (e.g., CURRENT_RUN flipped mid-flight).
echo "bnb-fixer" > "$BNB/.active-agent"

exit 0
