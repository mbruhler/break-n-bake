---
description: Scout the current prompt and repository, then spawn Breaker (Opus) to generate a layered spec/milestones/quality/validation structure under .bnb/<slug>/. Use when you've pasted a long prompt or the task has a large blast radius.
---

# /break-n-bake:break

Transform the current conversation's working prompt into a structured `.bnb/<slug>/` spec.

## Input

The "working prompt" is either:
- `$ARGUMENTS` if the user passed text after `/break-n-bake:break`, **or**
- The most recent substantive user message in this conversation (the one that prompted the break-n-bake workflow).

If both are present, `$ARGUMENTS` wins.

## Run scoping

**CRITICAL — every `/break` invocation creates a new run directory at `.bnb/<slug>/`.** The slug is inferred by you from the working prompt (see below). There is no `runs/` parent — slugs live directly under `.bnb/`, guarded from collisions with project-level files by a reserved-name denylist in `slugify.sh`.

### Slug inference

Pick a 2–5 word slug that summarises the *assignment*, not its mechanics. Examples:
- "Redesign the dashboard to use dark mode everywhere" → `redesign-dashboard`
- "Create an app for tracking habits with reminders" → `create-habits-app`
- "Migrate the payments service from Stripe to Adyen" → `migrate-payments-stripe-adyen`
- "Fix the flaky tests in the checkout flow" → `fix-checkout-flaky-tests`

Rules:
- Lowercase, alphanumeric + hyphens only.
- 2–5 words, 12–40 chars total.
- Prefer verbs that capture intent (`redesign-`, `create-`, `migrate-`, `fix-`, `add-`).
- Avoid reserved names (`config`, `CURRENT_RUN`, `README`, `runs`, `validation`, `snapshots`, `active-agent`, `validation-error`). `slugify.sh` auto-suffixes `-run` if you pick one.
- If you genuinely cannot infer, fall back to `run` and let `init-run.sh` suffix for uniqueness.

If the generated slug already exists under `.bnb/`, `init-run.sh` will append `-2`, `-3`, … automatically — you do not need to check yourself.

## Preflight recap

**CRITICAL** — before spawning any agent, output to user in 4–5 lines:
- Source of working prompt: `$ARGUMENTS` | last substantive user message (quote first ~80 chars).
- **Inferred run slug** and a one-line justification.
- Whether `.bnb/config.json` exists → skip or run init.
- Planned agents in order: Explorer → Breaker. Note Breaker will seed the append-only `validation/` layer and regenerate `eslint.config.bnb.mjs`.
- Confirmation: this command does NOT implement anything; it writes `.bnb/<slug>/` + regenerates project-root `eslint.config.bnb.mjs`.

Do NOT call any script or agent until the recap is out. If the user objects to the slug, regenerate before proceeding.

## Steps

1. **Verify project-level init.** If `.bnb/config.json` does not exist, run `${CLAUDE_PLUGIN_ROOT}/scripts/init-bnb.sh` first. Report the detected stack to the user before proceeding.

2. **Create the run dir.** Run `${CLAUDE_PLUGIN_ROOT}/scripts/init-run.sh <slug>`. Capture its stdout — that is the **final slug** (may differ from your inferred slug if a collision forced a `-N` suffix). The script also writes `.bnb/CURRENT_RUN` so subsequent `/bake` and `/fix` invocations target this run automatically. Let `$RUN_DIR = .bnb/<final-slug>`.

3. **Preserve the prompt.** Write the working prompt verbatim to `$RUN_DIR/_PROMPT.md`. Do not edit, trim, or "clean up" — auditability matters.

4. **Spawn Explorer.** Use the Agent tool with `subagent_type: "bnb-explorer"`. Pass it the working prompt, the path `$RUN_DIR`, and tell it to scout. Explorer will write `$RUN_DIR/scout-report.json`. Wait for Explorer to finish before continuing.

5. **Show the user the scout report summary** (terse — a few lines: blast radius estimate, detected cross-cutting signals, recommendation). If Explorer recommends `mode: "direct"` (task is too small to warrant break), ask the user whether to proceed with break anyway or abort. On abort, leave the run dir in place but note it is empty.

6. **Spawn Breaker.** Use the Agent tool with `subagent_type: "bnb-breaker"`. Pass Breaker a minimal brief: the paths `$RUN_DIR/_PROMPT.md`, `$RUN_DIR/scout-report.json`, `.bnb/config.json`, and the **run dir** `$RUN_DIR` itself. Instruct Breaker to produce the full content set under `$RUN_DIR/` per its system prompt — including seeding `validation/{eslint,tests,prompts}/001-*` and calling `validation-lock.sh` and `regen-eslint-overlay.sh`. Do not re-explain the structure.

7. **When Breaker finishes**, read `$RUN_DIR/README.md` and `$RUN_DIR/questions-before-start.md`. Show the user the report using the format below. Confirm `validation-lock.sh` and `regen-eslint-overlay.sh` both ran — check for `.snapshots/validation.lock` and a non-stub `eslint.config.bnb.mjs`.

8. **Next step for the user:** "Answer the questions in `$RUN_DIR/questions-before-start.md`, then run `/break-n-bake:bake` to implement M1. To surface the new eslint rules in your IDE, add `import bnb from './eslint.config.bnb.mjs';` to your real eslint config (one-time)."

## Output format

<output_format name="break-report">
```
Break complete.

Run: <final-slug>
Run dir: .bnb/<final-slug>/

Counts:
  - spec: <N> files
  - milestones: <N> (risk: low=<a>, medium=<b>, high=<c>)
  - quality: 3 files (fixed)
  - validation: eslint=<N>, tests=<N>, prompts=<N>
  - questions-before-start: <N>

Top open questions (up to 3):
  1. <question> — default if no preference: <default>
  2. ...

Artifacts:
  - .bnb/<final-slug>/README.md
  - .bnb/<final-slug>/questions-before-start.md
  - .bnb/<final-slug>/spec/ | milestones/ | quality/ | validation/
  - .bnb/<final-slug>/.snapshots/validation.lock (seal of the append-only layer)
  - eslint.config.bnb.mjs (project root — composed from validation/eslint/)

Active run set in .bnb/CURRENT_RUN.

Next: answer questions, then /break-n-bake:bake
IDE wiring (one-time): import bnb from './eslint.config.bnb.mjs'; then ...bnb in your real eslint config.
```

CRITICAL: every count must match the filesystem. If you cannot get a count, write `(unknown)` — do not guess.
</output_format>

## Hard rules

<hard_rules>
- **CRITICAL — Do not implement anything during `/break`.** This command only produces documentation under `.bnb/<slug>/` plus the regenerated project-root `eslint.config.bnb.mjs`.
- **CRITICAL — Do not edit the user's source code.** Explorer is read-only; Breaker writes only under the run dir (with the sole exception of `eslint.config.bnb.mjs`, which is regenerated by script, not hand-edited).
- **CRITICAL — Do not skip Explorer.** Breaker depends on `scout-report.json`.
- **CRITICAL — `_PROMPT.md` must be written verbatim** — no edits, no summarizing, no cleanup.
- **CRITICAL — Never write run-scoped files (spec/, milestones/, quality/, validation/, _PROMPT.md, etc.) outside `$RUN_DIR`.**
- **CRITICAL — Never overwrite an existing run.** `init-run.sh` handles collision by suffixing; trust it.
- **CRITICAL — The validation seed MUST be locked.** Confirm `.snapshots/validation.lock` exists at the end — without it, the append-only guard is inactive.
- **IMPORTANT — If Breaker pauses to ask the user**, relay the question faithfully and wait for a response before resuming. Do not answer on the user's behalf.
</hard_rules>

## Reminder before you finish

<reminder>
CRITICAL — before declaring `/break` done, verify:
1. `.bnb/CURRENT_RUN` contains the final slug you used.
2. `$RUN_DIR/_PROMPT.md` exists and is byte-identical to the working prompt source.
3. `$RUN_DIR/scout-report.json` exists (Explorer output).
4. `$RUN_DIR/spec/`, `$RUN_DIR/milestones/`, `$RUN_DIR/quality/`, `$RUN_DIR/validation/{eslint,tests,prompts}/` all contain files; `milestones/STATUS.md` lists every milestone.
5. `$RUN_DIR/.snapshots/validation.lock` exists (Breaker ran `validation-lock.sh`).
6. Project-root `eslint.config.bnb.mjs` has been regenerated (not just the init stub).
7. No source file outside `.bnb/` and `eslint.config.bnb.mjs` was modified by this command.
8. The report uses the `<output_format name="break-report">` structure.

Any fail → surface it, do not paper over.
</reminder>
