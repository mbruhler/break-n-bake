#!/usr/bin/env bash
# Convert free-form text into a run slug.
#
# Rules:
#   - lowercase
#   - keep a-z, 0-9, hyphen
#   - collapse whitespace/punctuation into single hyphen
#   - trim leading/trailing hyphens
#   - cap length at 40 chars
#   - if empty after processing, output "run"
#   - if result matches a reserved slug (see RESERVED below), suffix "-run"
#
# The reserved list exists because runs now live at `.bnb/<slug>/` (no `runs/`
# parent), so a slug named `config` or `CURRENT_RUN` would collide with
# project-level files.
#
# Usage:
#   echo "Redesign the app dashboard" | scripts/slugify.sh
#   # → redesign-the-app-dashboard
#
#   scripts/slugify.sh "Redesign the app"
#   # → redesign-the-app

set -uo pipefail

# Slugs that must never be used as a run directory name because they collide
# with project-level files under `.bnb/`.
RESERVED=(
  "config"
  "current_run"
  "readme"
  "runs"
  "validation"
  "snapshots"
  "active-agent"
  "validation-error"
)

input="${1:-}"
if [ -z "$input" ] && [ ! -t 0 ]; then
  input=$(cat)
fi

slug=$(printf '%s' "$input" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9]+/-/g' \
  | sed -E 's/^-+|-+$//g')

if [ ${#slug} -gt 40 ]; then
  slug="${slug:0:40}"
  slug=$(printf '%s' "$slug" | sed -E 's/-+$//')
fi

if [ -z "$slug" ]; then
  slug="run"
fi

# Guard against reserved names.
for r in "${RESERVED[@]}"; do
  if [ "$slug" = "$r" ]; then
    slug="${slug}-run"
    break
  fi
done

printf '%s\n' "$slug"
