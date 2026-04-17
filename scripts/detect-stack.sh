#!/usr/bin/env bash
# Detect the project's primary stack and emit inferred validation commands as JSON on stdout.
# Exit 0 always. Uncertain fields come out as null; human can edit .bnb/config.json.

set -uo pipefail

cd "${1:-.}"

stack="unknown"
lint_cmd="null"
typecheck_cmd="null"
test_cmd="null"
evidence=""

if [ -f package.json ]; then
  stack="node"
  evidence="package.json"
  has_script() { node -e "const p=require('./package.json'); process.exit(p.scripts&&p.scripts['$1']?0:1)" 2>/dev/null; }
  has_dep() { node -e "const p=require('./package.json'); const d={...p.dependencies,...p.devDependencies}; process.exit(d&&d['$1']?0:1)" 2>/dev/null; }

  if has_script lint; then lint_cmd='"npm run lint"'; fi
  if has_script typecheck; then typecheck_cmd='"npm run typecheck"';
  elif has_dep typescript; then typecheck_cmd='"npx tsc --noEmit"'; fi
  if has_script test; then test_cmd='"npm test -- --run"';
  elif has_dep vitest; then test_cmd='"npx vitest run"';
  elif has_dep jest; then test_cmd='"npx jest --ci"'; fi

elif [ -f pyproject.toml ] || [ -f setup.py ] || [ -f setup.cfg ]; then
  stack="python"
  evidence=$([ -f pyproject.toml ] && echo "pyproject.toml" || ([ -f setup.py ] && echo "setup.py" || echo "setup.cfg"))
  command -v ruff >/dev/null 2>&1 && lint_cmd='"ruff check ."' || (command -v flake8 >/dev/null 2>&1 && lint_cmd='"flake8"')
  command -v mypy >/dev/null 2>&1 && typecheck_cmd='"mypy ."' || (command -v pyright >/dev/null 2>&1 && typecheck_cmd='"pyright"')
  command -v pytest >/dev/null 2>&1 && test_cmd='"pytest -q"'

elif [ -f Cargo.toml ]; then
  stack="rust"
  evidence="Cargo.toml"
  lint_cmd='"cargo clippy -- -D warnings"'
  typecheck_cmd='"cargo check"'
  test_cmd='"cargo test"'

elif [ -f go.mod ]; then
  stack="go"
  evidence="go.mod"
  lint_cmd='"go vet ./..."'
  typecheck_cmd='"go build ./..."'
  test_cmd='"go test ./..."'

elif [ -f Gemfile ]; then
  stack="ruby"
  evidence="Gemfile"
  command -v rubocop >/dev/null 2>&1 && lint_cmd='"rubocop"'
  command -v rspec >/dev/null 2>&1 && test_cmd='"rspec"'

elif [ -f composer.json ]; then
  stack="php"
  evidence="composer.json"
  command -v phpstan >/dev/null 2>&1 && typecheck_cmd='"phpstan analyse"'
  command -v phpunit >/dev/null 2>&1 && test_cmd='"phpunit"'

elif [ -f pom.xml ] || [ -f build.gradle ] || [ -f build.gradle.kts ]; then
  stack="jvm"
  evidence=$([ -f pom.xml ] && echo "pom.xml" || echo "build.gradle")
  if [ -f pom.xml ]; then
    test_cmd='"mvn -q test"'
    typecheck_cmd='"mvn -q compile"'
  else
    test_cmd='"./gradlew test"'
    typecheck_cmd='"./gradlew build -x test"'
  fi
fi

total_source_files=0
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  total_source_files=$(git ls-files | wc -l | tr -d ' ')
fi

cat <<EOF
{
  "stack": "$stack",
  "evidence": "$evidence",
  "total_source_files": $total_source_files,
  "validation": {
    "lint": $lint_cmd,
    "typecheck": $typecheck_cmd,
    "test": $test_cmd
  }
}
EOF
