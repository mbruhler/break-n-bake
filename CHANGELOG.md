# Changelog

## 0.1.0 — 2026-04-17 — initial release

First public version. MVP scope.

### Included
- Manifest with `userConfig` for `max_fix_iterations` and `break_threshold_files`.
- Five sub-agents with explicit model assignments:
  - `bnb-explorer` (haiku) — prompt + repo reconnaissance
  - `bnb-breaker` (opus) — produces `.bnb/spec/`, `milestones/`, `quality/`
  - `bnb-baker` (sonnet) — implements one milestone per invocation
  - `bnb-validator` (haiku, `disallowedTools: Write, Edit`) — validation + severity classification
  - `bnb-fixer` (opus) — repairs blockers; blocked from test/config paths
- Four commands: `/init`, `/break`, `/bake`, `/fix`
- Orchestrator skill auto-suggesting break on long prompts, refactor keywords, or large blast radius
- Hook-based path guard for fixer: `SubagentStart/Stop` markers + `PreToolUse` Write/Edit filter
- SHA256 snapshot lock + verify as belt-and-suspenders over the hook
- Stack autodiscovery: node, python, rust, go, ruby, php, jvm
- Per-milestone validation runs with structured JSON + human summary
- Bounded fix cycle: configurable max iterations, hard stop at 3 consecutive no-progress iterations

### Known limitations
- `SubagentStart/Stop` matcher behavior is documented but runtime-specific; snapshot-verify runs as a second line of defense.
- Validation command inference for non-JS/TS stacks is best-effort; users may need to tweak `.bnb/config.json` after init.
- End-to-end workflow has not yet been run against a real large-refactor scenario.
