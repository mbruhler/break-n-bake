# Changelog

## 0.2.1 — 2026-04-17 — trim prose from prompts

Removed rationale, philosophy, and self-referential commentary from agent system prompts, command files, the orchestrator skill, and the README. Only rules and procedures remain. No functional change.

## 0.2.0 — 2026-04-17 — raise minimum model to Sonnet 4.6

### Changed
- **`bnb-explorer`**: `model: haiku` → `model: sonnet` with `effort: medium`. Scout's `break vs direct` recommendation is load-bearing — a Haiku miss here skips the whole structured workflow. Sonnet with medium thinking reads the prompt and repo well enough to make the judgment reliably.
- **`bnb-validator`**: `model: haiku` → `model: sonnet` with `effort: medium`. Severity classification (blocker vs deferrable) requires reading spec and import graph to judge whether a failing test breaks a contract or just an edge case. Haiku guessed; Sonnet actually reads.

### Rationale
Haiku was tempting for cost but both affected agents make judgment calls, not lookups. The cost of one falsely-`clean` milestone that propagates into M+2 is larger than the marginal spend of running Sonnet on reconnaissance and classification.

### Unchanged
- `bnb-breaker` stays Opus (partitioning and cross-refs are the heaviest cognitive step).
- `bnb-baker` stays Sonnet default, Opus for `risk: high` milestones.
- `bnb-fixer` stays Opus (root-cause work on blockers).

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
