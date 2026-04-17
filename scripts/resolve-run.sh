#!/usr/bin/env bash
# Resolve the active break-n-bake run directory.
#
# Resolution order (first match wins):
#   1. $BNB_RUN_DIR env var (absolute or relative to project root)
#   2. $BNB_RUN env var — a slug, resolved to .bnb/$BNB_RUN
#   3. .bnb/CURRENT_RUN file — one line, the slug
#
# Prints the absolute path to the run dir on stdout. Exits 0 on success, 1 if no
# run could be resolved. The run dir is NOT required to exist — this only
# resolves the path.
#
# Layout note: runs live at `.bnb/<slug>/` (flattened; there is no `.bnb/runs/`
# parent). See scripts/slugify.sh for the reserved-slug denylist that prevents
# collisions with project-level files.
#
# Usage:
#   RUN_DIR=$("$PLUGIN_ROOT/scripts/resolve-run.sh") || exit 1
# or source as a helper:
#   # shellcheck source=/dev/null
#   . "$PLUGIN_ROOT/scripts/resolve-run.sh" --source
#   # now $BNB_RUN_DIR and $BNB_RUN_SLUG are exported

set -uo pipefail

_resolve_run() {
  local project_root="${PROJECT_ROOT:-$(pwd)}"
  local bnb="$project_root/.bnb"
  local slug=""
  local run_dir=""

  if [ -n "${BNB_RUN_DIR:-}" ]; then
    case "$BNB_RUN_DIR" in
      /*) run_dir="$BNB_RUN_DIR" ;;
      *)  run_dir="$project_root/$BNB_RUN_DIR" ;;
    esac
    slug="$(basename "$run_dir")"
  elif [ -n "${BNB_RUN:-}" ]; then
    slug="$BNB_RUN"
    run_dir="$bnb/$slug"
  elif [ -f "$bnb/CURRENT_RUN" ]; then
    slug=$(tr -d '[:space:]' < "$bnb/CURRENT_RUN" | head -c 200)
    [ -z "$slug" ] && return 1
    run_dir="$bnb/$slug"
  else
    return 1
  fi

  printf '%s\n' "$run_dir"
  printf '%s\n' "$slug" >&2  # secondary channel so callers can capture both
  return 0
}

if [ "${1:-}" = "--source" ]; then
  # Export vars into caller's env
  _project_root="${PROJECT_ROOT:-$(pwd)}"
  _bnb="$_project_root/.bnb"
  if [ -n "${BNB_RUN_DIR:-}" ]; then
    case "$BNB_RUN_DIR" in
      /*) : ;;
      *)  BNB_RUN_DIR="$_project_root/$BNB_RUN_DIR" ;;
    esac
    BNB_RUN_SLUG="$(basename "$BNB_RUN_DIR")"
  elif [ -n "${BNB_RUN:-}" ]; then
    BNB_RUN_SLUG="$BNB_RUN"
    BNB_RUN_DIR="$_bnb/$BNB_RUN_SLUG"
  elif [ -f "$_bnb/CURRENT_RUN" ]; then
    BNB_RUN_SLUG=$(tr -d '[:space:]' < "$_bnb/CURRENT_RUN" | head -c 200)
    BNB_RUN_DIR="$_bnb/$BNB_RUN_SLUG"
  else
    BNB_RUN_SLUG=""
    BNB_RUN_DIR=""
  fi
  export BNB_RUN_DIR BNB_RUN_SLUG
  return 0 2>/dev/null || exit 0
fi

# Called as a command — print run dir (slug on stderr for optional capture).
_resolve_run
