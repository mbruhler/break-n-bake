---
description: Initialize break-n-bake in the current project. Creates .bnb/ skeleton, detects the stack, writes config.json with validation commands. Run once per project.
---

# /break-n-bake:init

Initialize the `.bnb/` directory and configuration for this project.

## Preflight recap

**CRITICAL** — before running any script, output in 2–3 lines:
- Current working directory (confirm it is the intended project root).
- Whether `.bnb/` already exists → plan is `init` or `abort`.
- Confirmation: this command does NOT touch any source file outside `.bnb/` and `.gitignore`.

## Steps

1. Run `${CLAUDE_PLUGIN_ROOT}/scripts/init-bnb.sh` from the project root. This script:
   - Creates `.bnb/` with subdirectories: `spec/`, `milestones/`, `quality/`, `validation-results/`, `validation-results/raw/`, `validation-results/fix-cycles/`, `.snapshots/`.
   - Detects stack via `${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`.
   - Writes `.bnb/config.json` with the detected stack and inferred validation commands.
   - Adds `.bnb/validation-results/raw/` and `.bnb/.snapshots/` to `.gitignore` (leaves the rest of `.bnb/` tracked — it's documentation you want in git).
   - Writes `.bnb/README.md` stub pointing at the workflow.

2. **CRITICAL — If `.bnb/` already exists, abort** with a message showing current state. Do NOT overwrite, merge, or "refresh" it.

3. Report back using `<output_format>` below.

4. If the user has provided a prompt that should be broken down, suggest running `/break-n-bake:break` next. Otherwise, confirm init is done.

## Output format

<output_format name="init-report">
```
.bnb/ initialized.

Stack: <detected name> (evidence: <file>)
Validation commands:
  - lint: <command | (not inferred — please set validation.lint in .bnb/config.json)>
  - typecheck: <command | (not inferred)>
  - test: <command | (not inferred)>

.gitignore updated: .bnb/validation-results/raw/, .bnb/.snapshots/

Next: /break-n-bake:break (if you have a prompt to break down)
```

CRITICAL: never write a command you did not actually infer. Missing commands must be marked `(not inferred)` so the user knows to supply them.
</output_format>

## Hard rules

<hard_rules>
- **CRITICAL — Never overwrite an existing `.bnb/`.** Abort if it exists.
- **CRITICAL — Never touch any file outside `.bnb/` and `.gitignore`.**
- **CRITICAL — Never fabricate validation commands.** If detection fails, mark `(not inferred)` — do not guess.
- **IMPORTANT — `config.json` is human-editable.** Tell the user which keys to tweak if autodiscovery was wrong: `validation.lint`, `validation.typecheck`, `validation.test`.
</hard_rules>

## Reminder before you finish

<reminder>
CRITICAL — before declaring `/init` done, verify:
1. `.bnb/config.json` exists and parses as valid JSON.
2. No file outside `.bnb/` and `.gitignore` was modified.
3. Any validation command that could not be inferred is labeled `(not inferred)` — not a guess.
4. The report uses `<output_format name="init-report">`.
</reminder>

## Notes

- Other break-n-bake commands check for `.bnb/config.json`. If missing, they run this init flow inline first. You do not need to pre-run `/init` if you already know you want to `/break` — but running it separately is cleaner.
- `config.json` is human-editable. If autodiscovery got the validation commands wrong, tell the user which keys to tweak: `validation.lint`, `validation.typecheck`, `validation.test`.
