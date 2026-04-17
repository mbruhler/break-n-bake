#!/usr/bin/env bash
# Called by SubagentStop hook when bnb-fixer finishes. Removes the active-agent marker.

set -euo pipefail

BNB="$(pwd)/.bnb"
rm -f "$BNB/.active-agent"

exit 0
