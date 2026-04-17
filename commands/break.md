---
description: Scout the current prompt and repository, then spawn Breaker (Opus) to generate a layered spec/milestones/quality structure under .bnb/. Use when you've pasted a long prompt or the task has a large blast radius.
---

# /break-n-bake:break

Transform the current conversation's working prompt into a structured `.bnb/` spec.

## Input

The "working prompt" is either:
- `$ARGUMENTS` if the user passed text after `/break-n-bake:break`, **or**
- The most recent substantive user message in this conversation (the one that prompted the break-n-bake workflow).

If both are present, `$ARGUMENTS` wins.

## Steps

1. **Verify init.** If `.bnb/config.json` does not exist, run `${CLAUDE_PLUGIN_ROOT}/scripts/init-bnb.sh` first. Report the detected stack to the user before proceeding.

2. **Preserve the prompt.** Write the working prompt verbatim to `.bnb/_PROMPT.md`. Do not edit, trim, or "clean up" — auditability matters.

3. **Spawn Explorer (Haiku).** Use the Agent tool with `subagent_type: "bnb-explorer"`. Pass it the working prompt and tell it to scout. Explorer will write `.bnb/scout-report.json`. Wait for Explorer to finish before continuing.

4. **Show the user the scout report summary** (terse — a few lines: blast radius estimate, detected cross-cutting signals, recommendation). If Explorer recommends `mode: "direct"` (task is too small to warrant break), ask the user whether to proceed with break anyway or abort.

5. **Spawn Breaker (Opus).** Use the Agent tool with `subagent_type: "bnb-breaker"`. Pass Breaker a minimal brief: the path `.bnb/_PROMPT.md`, the path `.bnb/scout-report.json`, the path `.bnb/config.json`, and the standing instruction to produce the full `.bnb/` content set per its system prompt. Do not re-explain the structure — Breaker's system prompt already contains it.

6. **When Breaker finishes**, read `.bnb/README.md` and `.bnb/questions-before-start.md`. Show the user:
   - A one-line count per directory (e.g., "spec: 9 files, milestones: 5, quality: 3")
   - The risk distribution of milestones (from `.bnb/milestones/STATUS.md`)
   - The top questions from `questions-before-start.md`

7. **Next step for the user:** "Answer the questions in `.bnb/questions-before-start.md`, then run `/break-n-bake:bake` to implement M1."

## Rules

- Do not implement anything during `/break`. This command only produces documentation.
- Do not edit the user's source code. Explorer and Breaker are read-mostly agents; any edits go to `.bnb/`.
- If Breaker pauses to ask the user a question (per its system prompt), relay it faithfully and wait for a response before resuming.
