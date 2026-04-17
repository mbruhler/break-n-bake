# break-n-bake

A Claude Code plugin that splits overwhelming prompts and large refactors into a structured, auditable workflow.

## The problem

Two failure modes of long-running Claude Code sessions:

1. **Long prompt, short scope** — user pastes 3000 words of requirements. Model gets lost, cherry-picks, forgets half.
2. **Short prompt, huge scope** — `"migrate auth to OAuth2"`. Sounds tiny, touches 40 files. Model underestimates and improvises.

Both fail for the same reason: no explicit plan the model can return to, and no checkpoint where the user can correct course before damage compounds.

## The shape

Two phases, five specialized sub-agents, one source of truth on disk (`.bnb/`). Every `/break-n-bake:break` invocation creates its own run directory at `.bnb/<slug>/` (flattened — no `runs/` parent), so artefacts from multiple tasks (e.g. `redesign-dashboard`, `migrate-payments`, `fix-checkout-flaky-tests`) never collide. A reserved-name denylist in `slugify.sh` prevents slugs colliding with project-level files (`config`, `CURRENT_RUN`, `README`, etc.).

### Layout

```
.bnb/
├── config.json                  project-level: stack, validation commands, forbidden_write_patterns
├── CURRENT_RUN                  plain-text pointer to the active run slug
├── README.md                    project-level map
└── <slug>/                      one dir per /break invocation
    ├── README.md                run-level map + navigation + "zero rule"
    ├── _PROMPT.md               original prompt, preserved verbatim
    ├── scout-report.json        Explorer output
    ├── questions-before-start.md
    ├── spec/                    what we are building (numbered docs)
    ├── milestones/              how we build it (M1-M{n}, each a checkpoint)
    ├── quality/                 how we know we're done
    │   ├── acceptance-scenarios.md
    │   ├── landmines.md
    │   └── out-of-scope.md
    ├── validation/              APPEND-ONLY programmatic checks (sealed by snapshot)
    │   ├── README.md            immutability rules
    │   ├── eslint/NNN-*.json    flat-config eslint overlays
    │   ├── tests/NNN-*.<ext>    test files per acceptance-scenario / landmine
    │   └── prompts/NNN-*.md     LLM-as-judge checks
    ├── validation-results/      validator reports + fix-cycle trail
    └── .snapshots/              contract + validation integrity hashes (gitignored)
```

At the project root, `/init` also writes:
- A `<!-- BEGIN break-n-bake -->…<!-- END -->` block into `CLAUDE.md` (workflow summary + IDE wiring snippet). Idempotent — only content between markers is managed.
- `eslint.config.bnb.mjs` — composed from the active run's `validation/eslint/*.json`. Add one line to your real eslint config to surface these rules in your editor.

Every file repeats one rule at the top: **if unsure, ask — don't guess.**

### Phase 1 — `break`

Slug is inferred from the prompt (e.g. `redesign-dashboard`). Explorer scouts the prompt and repo into `<slug>/scout-report.json`. Breaker turns the output into the five-layer structure shown above — including seeding the append-only `validation/` layer with eslint overlays, per-scenario test files, and LLM-as-judge prompts. After seeding, Breaker calls `validation-lock.sh` to snapshot-seal the layer and `regen-eslint-overlay.sh` to rebuild project-root `eslint.config.bnb.mjs`.

### Phase 2 — `bake`

Baker implements one milestone at a time from the **active run** (resolved via `BNB_RUN_DIR`, `BNB_RUN`, or `.bnb/CURRENT_RUN`). After each milestone:

- Validator (read-only, no Write/Edit tools) runs stack-level `test + lint + typecheck`, plus every file under the sealed `validation/` layer — each `eslint/*.json` overlay, each `tests/*` file, and spawns a read-only sub-agent per `prompts/*.md` to judge LLM-as-judge rules. All findings are classified by severity and written to `<slug>/validation-results/`.
- On **blocker** errors: halt main thread, run Fixer. Fixer cannot touch test/config files, cannot write to another run, cannot edit any sealed validation file.
- On **deferrable** errors only: continue to next milestone, accumulate for end-of-run fix pass.
- In `--all` mode, bake is fully automatic — no user gate between milestones, and Baker for M{n+1} is speculatively spawned while Validator for M{n} runs in the background.
- Baker may add new numbered files to `validation/` for newly introduced surface area; existing files are append-only and snapshot-sealed.
- Fix cycle hard-stops at 3 no-progress iterations.

## Commands

| Command | Purpose |
|---|---|
| `/break-n-bake:init` | Create `.bnb/` project-level skeleton, detect stack, write `config.json`, inject CLAUDE.md block, seed `eslint.config.bnb.mjs`. Run once per project. |
| `/break-n-bake:break` | Scout prompt + repo, create `.bnb/<slug>/`, generate `spec/`, `milestones/`, `quality/`, seed append-only `validation/` layer, regen project-root eslint overlay. Sets `.bnb/CURRENT_RUN`. |
| `/break-n-bake:bake [M<n>\|--all]` | Implement one milestone of the active run (default) or all sequentially (`--all` is automatic, no user gate). |
| `/break-n-bake:fix` | Manually run fix-cycle against latest validation results of the active run. |

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

- **Fixer cannot modify test files, lint configs, tsconfig, or any run's `quality/` / `spec/` / `validation/` / milestone docs.** Enforced via `PreToolUse` hook + SHA256 snapshot verification after each fix cycle. Patterns are glob-scoped (`.bnb/*/spec/**`, `.bnb/*/validation/**`) so protection covers every run.
- **`validation/` is append-only for everyone.** After Breaker seeds and locks, the `guard-fixer-paths.sh` hook rejects any Write/Edit to a path recorded in `.snapshots/validation.lock`. Baker may add new numbered files; existing files are immutable like database migrations.
- **Validator has no Write/Edit tools at all.** Declared in agent frontmatter — no way around it. Artifacts are written via Bash heredoc.
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
/break-n-bake:init                          once per project; detects stack, injects CLAUDE.md block, seeds eslint overlay
/break-n-bake:break <your big prompt>       creates .bnb/<slug>/, seeds validation/, regens eslint overlay
# → review .bnb/<slug>/spec/ + questions-before-start.md
# → wire eslint: add `import bnb from './eslint.config.bnb.mjs'` to your real eslint config (one-time)
# → answer questions
/break-n-bake:bake                          implement M1 of active run, validate (incl. validation/ layer), show result
/break-n-bake:bake                          next invocation → M2
# or
/break-n-bake:bake --all                    fully automatic chaining through all milestones
```

Switching between runs (rare):

```
echo other-slug > .bnb/CURRENT_RUN          # persistent switch
BNB_RUN=other-slug /break-n-bake:bake       # one-off override
```

## User config

Set via `/plugin config break-n-bake` or at install time:

| Key | Default | Purpose |
|---|---|---|
| `max_fix_iterations` | `5` | Cap on fix-cycle retries. |
| `break_threshold_files` | `15` | Blast-radius file count that triggers auto-break suggestion. |

## Core rule

> If unsure, ask. Don't guess. When a decision isn't in the spec, stop.
