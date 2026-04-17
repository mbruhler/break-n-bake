#!/usr/bin/env bash
# Estimate blast radius: files changed in a milestone's bake step, plus files that import them.
# Used to decide which earlier milestones need re-validation.
#
# Usage: blast-radius.sh <milestone-id>
# Output: JSON with changed_files and dependents arrays.

set -uo pipefail

MILESTONE="${1:-}"
PROJECT_ROOT="$(pwd)"

if [ -z "$MILESTONE" ]; then
  echo '{"error": "usage: blast-radius.sh <milestone-id>"}'
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo '{"error": "not a git repository"}'
  exit 0
fi

LAST_COMMIT_FOR_MILESTONE=$(git log --oneline --grep="^$MILESTONE:" -n 1 --format="%H" || echo "")

if [ -z "$LAST_COMMIT_FOR_MILESTONE" ]; then
  CHANGED=$(git diff --name-only HEAD 2>/dev/null || echo "")
else
  PREV=$(git rev-parse "$LAST_COMMIT_FOR_MILESTONE^" 2>/dev/null || echo "")
  CHANGED=$(git diff --name-only "$PREV" "$LAST_COMMIT_FOR_MILESTONE" 2>/dev/null || echo "")
fi

CHANGED_JSON=$(echo "$CHANGED" | grep -v '^$' | sort -u | awk 'BEGIN{printf "["} {printf "%s\"%s\"", (NR>1?",":""), $0} END{print "]"}')

DEPENDENTS=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  base=$(basename "$f" | sed 's/\.[^.]*$//')
  [ -z "$base" ] && continue
  matches=$(git grep -l -E "(from ['\"].*${base}['\"]|import.*${base}|require\(['\"].*${base}['\"])" 2>/dev/null | grep -v "$f" || true)
  DEPENDENTS="$DEPENDENTS"$'\n'"$matches"
done <<< "$CHANGED"

DEPENDENTS_JSON=$(echo "$DEPENDENTS" | grep -v '^$' | sort -u | awk 'BEGIN{printf "["} {printf "%s\"%s\"", (NR>1?",":""), $0} END{print "]"}')

cat <<EOF
{
  "milestone": "$MILESTONE",
  "changed_files": $CHANGED_JSON,
  "dependents": $DEPENDENTS_JSON
}
EOF
