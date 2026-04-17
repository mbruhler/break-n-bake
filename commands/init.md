---
description: Initialize break-n-bake in the current project. Creates .bnb/ skeleton, detects the stack, writes config.json, seeds the CLAUDE.md block and the project-root eslint overlay stub. Run once per project.
---

# /break-n-bake:init

Initialize the `.bnb/` directory and project-level configuration.

Per-run scaffolding (`spec/`, `milestones/`, `quality/`, `validation/`, …) is **not** created here — that happens inside `.bnb/<slug>/` each time `/break-n-bake:break` starts a new run.

## Preflight recap

**CRITICAL** — before running any script, output in 2–3 lines:
- Current working directory (confirm it is the intended project root).
- Whether `.bnb/config.json` already exists → plan is `init` or `abort`.
- Confirmation: this command does NOT touch source code. It WILL touch `.gitignore`, `CLAUDE.md` (adding a BEGIN/END-marked block), and create `eslint.config.bnb.mjs` at project root.

## Steps

1. Run `${CLAUDE_PLUGIN_ROOT}/scripts/init-bnb.sh` from the project root. This script:
   - Creates `.bnb/`.
   - Detects stack via `${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`.
   - Writes `.bnb/config.json` with the detected stack, inferred validation commands, and `forbidden_write_patterns` using `.bnb/*/…` globs so contract protection applies to every run.
   - Writes `.bnb/README.md` pointing at the workflow.
   - Adds `.bnb/*/validation-results/raw/`, `.bnb/*/.snapshots/`, `.bnb/*/.active-agent` to `.gitignore`.
   - Calls `${CLAUDE_PLUGIN_ROOT}/scripts/inject-claude-md.sh` to add/refresh the `<!-- BEGIN break-n-bake -->…<!-- END -->` block in the project's `CLAUDE.md` (creating it if absent).
   - Calls `${CLAUDE_PLUGIN_ROOT}/scripts/regen-eslint-overlay.sh` to write a stub `eslint.config.bnb.mjs` at project root (empty array until a run is active).

2. **CRITICAL — If `.bnb/config.json` already exists, abort** with a message showing current state. Do NOT overwrite, merge, or "refresh" it. The CLAUDE.md and eslint overlay steps are idempotent and may be re-run manually if needed.

3. Report back using `<output_format>` below.

4. If the user has provided a prompt that should be broken down, suggest running `/break-n-bake:break` next. Otherwise, confirm init is done.

## Output format

<output_format name="init-report">
```
.bnb/ initialized (project-level; per-run dirs created by /break).

Stack: <detected name> (evidence: <file>)
Validation commands:
  - lint: <command | (not inferred — please set validation.lint in .bnb/config.json)>
  - typecheck: <command | (not inferred)>
  - test: <command | (not inferred)>

.gitignore updated: .bnb/*/validation-results/raw/, .bnb/*/.snapshots/, .bnb/*/.active-agent
CLAUDE.md: break-n-bake block injected/refreshed.
eslint.config.bnb.mjs: stub at project root (empty until a run is active).

To wire ESLint into your IDE, add one line to your real eslint config:
  import bnb from './eslint.config.bnb.mjs';
  export default [ ...yourExistingConfigs, ...bnb ];

Next: /break-n-bake:break (creates the first run under .bnb/<slug>/)
```

CRITICAL: never write a command you did not actually infer. Missing commands must be marked `(not inferred)` so the user knows to supply them.
</output_format>

## Hard rules

<hard_rules>
- **CRITICAL — Never overwrite an existing `.bnb/config.json`.** Abort if it exists.
- **CRITICAL — Never create per-run directories here.** `spec/`, `milestones/`, `quality/`, `validation/` belong under `.bnb/<slug>/` and are the responsibility of `/break`.
- **CRITICAL — Never touch source files.** This command only writes `.bnb/`, `.gitignore`, `CLAUDE.md` (BEGIN/END block), and `eslint.config.bnb.mjs` (stub).
- **CRITICAL — Never fabricate validation commands.** If detection fails, mark `(not inferred)` — do not guess.
- **IMPORTANT — `config.json` is human-editable.** Tell the user which keys to tweak if autodiscovery was wrong: `validation.lint`, `validation.typecheck`, `validation.test`.
- **IMPORTANT — `CLAUDE.md` injection is contained.** Only content between the BEGIN/END markers is managed by this command; existing content is preserved verbatim.
</hard_rules>

## Reminder before you finish

<reminder>
CRITICAL — before declaring `/init` done, verify:
1. `.bnb/config.json` exists and parses as valid JSON.
2. `.bnb/` exists but contains no per-run artefacts (`spec/`, `milestones/`, `quality/`, `validation/`) — those belong in a run.
3. No source file (anything outside `.bnb/`, `.gitignore`, `CLAUDE.md`, `eslint.config.bnb.mjs`) was modified by this command.
4. The `<!-- BEGIN break-n-bake -->…<!-- END -->` block in `CLAUDE.md` is well-formed (both markers present).
5. `eslint.config.bnb.mjs` exists at project root and exports at least an empty array.
6. Any validation command that could not be inferred is labeled `(not inferred)` — not a guess.
7. The report uses `<output_format name="init-report">`.
</reminder>

## Notes

- Other break-n-bake commands check for `.bnb/config.json`. If missing, they run this init flow inline first. You do not need to pre-run `/init` if you already know you want to `/break` — but running it separately is cleaner.
- `config.json` is human-editable. If autodiscovery got the validation commands wrong, tell the user which keys to tweak: `validation.lint`, `validation.typecheck`, `validation.test`.
- The ESLint one-line integration snippet in the init-report is the only manual wiring step users need to perform; after that, every subsequent `/break` regenerates `eslint.config.bnb.mjs` automatically for the new active run.
