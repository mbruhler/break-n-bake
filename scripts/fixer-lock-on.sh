#!/usr/bin/env bash
# Called by SubagentStart hook when bnb-fixer begins.
# Writes a marker that guard-fixer-paths.sh checks on every Write/Edit PreToolUse.

set -euo pipefail

BNB="$(pwd)/.bnb"
mkdir -p "$BNB"
echo "bnb-fixer" > "$BNB/.active-agent"

exit 0
