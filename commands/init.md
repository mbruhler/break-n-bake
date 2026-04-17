---
description: Initialize break-n-bake in the current project. Creates .bnb/ skeleton, detects the stack, writes config.json with validation commands. Run once per project.
---

# /break-n-bake:init

Initialize the `.bnb/` directory and configuration for this project.

## Steps

1. Run `${CLAUDE_PLUGIN_ROOT}/scripts/init-bnb.sh` from the project root. This script:
   - Creates `.bnb/` with subdirectories: `spec/`, `milestones/`, `quality/`, `validation-results/`, `validation-results/raw/`, `validation-results/fix-cycles/`, `.snapshots/`.
   - Detects stack via `${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`.
   - Writes `.bnb/config.json` with the detected stack and inferred validation commands.
   - Adds `.bnb/validation-results/raw/` and `.bnb/.snapshots/` to `.gitignore` (leaves the rest of `.bnb/` tracked — it's documentation you want in git).
   - Writes `.bnb/README.md` stub pointing at the workflow.

2. If a `.bnb/` already exists, abort with a message showing the current state. Do not overwrite.

3. Report back to the user:
   - Detected stack
   - Validation commands that will be used
   - Any commands that could not be inferred (ask the user to supply them)

4. If the user has provided a prompt that should be broken down, suggest running `/break-n-bake:break` next. Otherwise, confirm init is done.

## Notes

- Other break-n-bake commands check for `.bnb/config.json`. If missing, they run this init flow inline first. You do not need to pre-run `/init` if you already know you want to `/break` — but running it separately is cleaner.
- `config.json` is human-editable. If autodiscovery got the validation commands wrong, tell the user which keys to tweak: `validation.lint`, `validation.typecheck`, `validation.test`.
