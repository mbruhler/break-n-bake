# break-n-bake

A Claude Code plugin that splits overwhelming prompts and large refactors into a structured, auditable workflow.

## The problem

Two failure modes of long-running Claude Code sessions:

1. **Long prompt, short scope** — user pastes 3000 words of requirements. Model gets lost, cherry-picks, forgets half.
2. **Short prompt, huge scope** — `"migrate auth to OAuth2"`. Sounds tiny, touches 40 files. Model underestimates and improvises.

Both fail for the same reason: no explicit plan the model can return to, and no checkpoint where the user can correct course before damage compounds.

## The shape

Two phases, five specialized sub-agents, one source of truth on disk (`.bnb/`).

### Phase 1 — `break`

Explorer scouts the prompt and the repo. Breaker turns the output into a four-layer structure:

```
.bnb/
├── README.md                 map + navigation + "zero rule"
├── _PROMPT.md                original prompt, preserved verbatim
├── config.json               stack, validation commands, settings
├── questions-before-start.md clarifications agent must ask before M1
├── spec/                     what we are building (numbered docs)
├── milestones/               how we build it (M1-M{n}, each a checkpoint)
└── quality/                  how we know we're done
    ├── acceptance-scenarios.md
    ├── landmines.md
    └── out-of-scope.md
```

Every file repeats one rule at the top: **if unsure, ask — don't guess.**

### Phase 2 — `bake`

Baker implements one milestone at a time. After each milestone:

- Validator (read-only, no Write/Edit tools) runs `test + lint + typecheck`, classifies errors by severity, writes structured reports to `.bnb/validation-results/`.
- On **blocker** errors: halt main thread, run Fixer. Fixer cannot touch test or config files.
- On **deferrable** errors only: continue to next milestone, accumulate for end-of-run fix pass.
- Fix cycle hard-stops at 3 no-progress iterations.

## Commands

| Command | Purpose |
|---|---|
| `/break-n-bake:init` | Create `.bnb/` skeleton, detect stack, write `config.json`. Run once per project. |
| `/break-n-bake:break` | Scout prompt + repo, generate `spec/`, `milestones/`, `quality/`. |
| `/break-n-bake:bake [M<n>\|--all]` | Implement one milestone (default: next pending) or all sequentially with checkpoints. |
| `/break-n-bake:fix` | Manually run fix-cycle against latest validation results. |

Skill `break-n-bake` auto-triggers on long prompts or refactor-keyword signals — Claude will suggest running `/break-n-bake:break` before implementing.

## Sub-agents and model assignments

| Agent | Model | Tools | Role |
|---|---|---|---|
| `bnb-explorer` | Sonnet 4.6, medium effort | Read, Grep, Glob, Bash | Prompt + repo reconnaissance. |
| `bnb-breaker` | Opus | Read, Write, Edit, Grep, Glob, Bash | Produces `spec/`, `milestones/`, `quality/`. |
| `bnb-baker` | Sonnet | Read, Write, Edit, Grep, Glob, Bash | Implements one milestone per invocation. Opus when milestone is `risk: high`. |
| `bnb-validator` | Sonnet 4.6, medium effort | Read, Bash, Grep — **no Write, no Edit** | Runs validation, classifies severity. |
| `bnb-fixer` | Opus | Read, Write, Edit, Grep, Bash | Fixes blockers. Blocked from test/config paths. |

## Hard rules enforced mechanically

- **Fixer cannot modify test files, lint configs, tsconfig, quality/ docs.** Enforced via `PreToolUse` hook + SHA256 snapshot verification after each fix cycle.
- **Validator has no Write/Edit tools at all.** Declared in agent frontmatter — no way around it.
- **Fix loop cannot spin forever.** Max 5 iterations (configurable); hard stop if error set unchanged for 3 consecutive iterations.

## Installation

Three ways, in order of convenience:

```shell
# 1. Via marketplace (recommended)
/plugin marketplace add mbruhler/break-n-bake
/plugin install break-n-bake@mbruhler-plugins

# 2. Clone + --plugin-dir (useful for development)
git clone https://github.com/mbruhler/break-n-bake
claude --plugin-dir ./break-n-bake

# 3. CLI equivalent of the marketplace flow
claude plugin marketplace add mbruhler/break-n-bake
claude plugin install break-n-bake@mbruhler-plugins
```

## Workflow

```
/break-n-bake:init           once per project, detects stack
/break-n-bake:break          after pasting a big prompt
# → review .bnb/spec/ + .bnb/questions-before-start.md
# → answer questions
/break-n-bake:bake           implement M1, validate, show result
# "OK, dalej?" → /break-n-bake:bake for M2
# ...
```

## User config

Set via `/plugin config break-n-bake` or at install time:

| Key | Default | Purpose |
|---|---|---|
| `max_fix_iterations` | `5` | Cap on fix-cycle retries. |
| `break_threshold_files` | `15` | Blast-radius file count that triggers auto-break suggestion. |

## Core rule

> If unsure, ask. Don't guess. When a decision isn't in the spec, stop.
