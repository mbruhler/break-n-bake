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

## Preflight recap

**CRITICAL** — before spawning any agent, output to user in 3–4 lines:
- Source of working prompt: `$ARGUMENTS` | last substantive user message (quote first ~80 chars).
- Whether `.bnb/config.json` exists → skip or run init.
- Planned agents in order: Explorer → Breaker.
- Confirmation: this command does NOT implement anything and does NOT edit source code.

Do NOT call any script or agent until the recap is out.

## Steps

1. **Verify init.** If `.bnb/config.json` does not exist, run `${CLAUDE_PLUGIN_ROOT}/scripts/init-bnb.sh` first. Report the detected stack to the user before proceeding.

2. **Preserve the prompt.** Write the working prompt verbatim to `.bnb/_PROMPT.md`. Do not edit, trim, or "clean up" — auditability matters.

3. **Spawn Explorer.** Use the Agent tool with `subagent_type: "bnb-explorer"`. Pass it the working prompt and tell it to scout. Explorer will write `.bnb/scout-report.json`. Wait for Explorer to finish before continuing.

4. **Show the user the scout report summary** (terse — a few lines: blast radius estimate, detected cross-cutting signals, recommendation). If Explorer recommends `mode: "direct"` (task is too small to warrant break), ask the user whether to proceed with break anyway or abort.

5. **Spawn Breaker.** Use the Agent tool with `subagent_type: "bnb-breaker"`. Pass Breaker a minimal brief: the path `.bnb/_PROMPT.md`, the path `.bnb/scout-report.json`, the path `.bnb/config.json`, and the instruction to produce the full `.bnb/` content set per its system prompt. Do not re-explain the structure.

6. **When Breaker finishes**, read `.bnb/README.md` and `.bnb/questions-before-start.md`. Show the user the report using the format below.

7. **Next step for the user:** "Answer the questions in `.bnb/questions-before-start.md`, then run `/break-n-bake:bake` to implement M1."

## Output format

<output_format name="break-report">
```
Break complete.

Counts:
  - spec: <N> files
  - milestones: <N> (risk: low=<a>, medium=<b>, high=<c>)
  - quality: 3 files (fixed)
  - questions-before-start: <N>

Top open questions (up to 3):
  1. <question> — default if no preference: <default>
  2. ...

Artifacts:
  - .bnb/README.md
  - .bnb/questions-before-start.md
  - .bnb/spec/ | .bnb/milestones/ | .bnb/quality/

Next: answer questions, then /break-n-bake:bake
```

CRITICAL: every count must match the filesystem. If you cannot get a count, write `(unknown)` — do not guess.
</output_format>

## Hard rules

<hard_rules>
- **CRITICAL — Do not implement anything during `/break`.** This command only produces documentation under `.bnb/`.
- **CRITICAL — Do not edit the user's source code.** Explorer is read-only; Breaker writes only under `.bnb/`.
- **CRITICAL — Do not skip Explorer.** Breaker depends on `scout-report.json`.
- **CRITICAL — `_PROMPT.md` must be written verbatim** — no edits, no summarizing, no cleanup.
- **IMPORTANT — If Breaker pauses to ask the user**, relay the question faithfully and wait for a response before resuming. Do not answer on the user's behalf.
</hard_rules>

## Reminder before you finish

<reminder>
CRITICAL — before declaring `/break` done, verify:
1. `.bnb/_PROMPT.md` exists and is byte-identical to the working prompt source.
2. `.bnb/scout-report.json` exists (Explorer output).
3. `.bnb/spec/`, `.bnb/milestones/`, `.bnb/quality/` all contain files; `milestones/STATUS.md` lists every milestone.
4. No file outside `.bnb/` was modified by this command.
5. The report uses the `<output_format name="break-report">` structure.

Any fail → surface it, do not paper over.
</reminder>
