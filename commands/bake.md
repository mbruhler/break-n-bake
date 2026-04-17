---
description: Implement one milestone (or all sequentially with checkpoints) from .bnb/milestones/. Spawns Baker, then Validator, and on blocker-severity failures runs a bounded fix cycle via Fixer.
---

# /break-n-bake:bake

Execute implementation phase.

## Argument parsing

`$ARGUMENTS` interpretation:
- **Empty** → bake the next `pending` milestone in `.bnb/milestones/STATUS.md`.
- **`M<n>`** (e.g., `M3`) → bake that specific milestone.
- **`--all`** → bake every remaining milestone sequentially, stopping for a user "OK, next?" checkpoint between each.
- **`--no-auto-fix`** combined with any of the above → do not run the fix cycle automatically; just report Validator's results and stop.

## Preconditions

1. `.bnb/config.json` must exist. If not, stop and tell the user to run `/break-n-bake:init` and `/break-n-bake:break` first.
2. `.bnb/milestones/STATUS.md` must exist. If not, tell the user to run `/break-n-bake:break` first.
3. The milestone being baked must have unanswered `questions-before-start.md` questions resolved. If any open question is tagged relevant to this milestone, stop and ask the user.

## Preflight recap

**CRITICAL** — after parsing arguments and verifying preconditions, before spawning any agent, output to user in 4–6 lines:
- Target milestone(s): e.g., `M3` or `M3..Mn (--all)`.
- Risk tag and time budget from the milestone's frontmatter.
- Mode flags in effect: `--all`, `--no-auto-fix` (y/n each).
- Planned verdict branches: what you will do on `clean` / `deferrable-only` / `blocked`.
- Scripts you will invoke in order: `snapshot-lock.sh`, validation run, `snapshot-verify.sh`, `progress-check.sh`.

Do NOT spawn Baker or run any script until the recap is out. This confirms arguments parsed correctly and you will not improvise verdict handling.

## Single-milestone flow (M{n})

### Step 1 — Baker

Spawn Baker (`subagent_type: "bnb-baker"`). Pass it the milestone identifier. If `milestones/M{n}-*.md` has `risk: high` in its frontmatter/header, spawn Baker with model override `opus` (if supported) or note in the brief: "milestone is flagged high-risk, escalate any ambiguity immediately."

Wait for Baker to finish. Baker will write `.bnb/milestones/M{n}.bake-summary.md`.

### Step 2 — Snapshot lock

Run `${CLAUDE_PLUGIN_ROOT}/scripts/snapshot-lock.sh` — this records SHA256 hashes of all test/config files so we can verify Fixer didn't touch them later.

### Step 3 — Validator

Spawn Validator (`subagent_type: "bnb-validator"`) **with `run_in_background: true`**. Validator writes `.bnb/validation-results/M{n}-run-1.json` and `.bnb/validation-results/M{n}-run-1.summary.md`. You may continue other orchestration while Validator runs, but you must await its result before deciding next steps.

Read the summary when Validator finishes.

### Step 4 — Branch on verdict

**CRITICAL — read Validator's `summary.md` verdict field verbatim. Do not infer. Do not re-classify.** The verdict is one of: `clean`, `deferrable-only`, `blocked`. Anything else → stop and surface the artifact path to the user.

**Verdict = `clean`:**
- Mark `M{n}: done` in `.bnb/milestones/STATUS.md`.
- Git commit using the format from `.bnb/milestones/README.md`.
- If `--all`, ask "OK, next?" and **CRITICAL** — wait for explicit user confirmation before proceeding to M{n+1}. Else stop.

**Verdict = `deferrable-only`:**
- Mark `M{n}: done-with-deferrables` in STATUS.md.
- Append the deferrable IDs to `.bnb/validation-results/deferrables-accumulated.json`.
- Commit. Proceed as above (same "OK, next?" gate in `--all`).

**Verdict = `blocked`:**
- **CRITICAL — If `--no-auto-fix` was passed, stop here.** Print blocker summary and JSON artifact path. Tell the user to run `/break-n-bake:fix`. Do NOT enter the fix cycle.
- Else, enter fix cycle (next section).

### Step 5 — Fix cycle (bounded)

<hard_rules name="fix-cycle-invariants">
- **CRITICAL — `max_fix_iterations` = user config (default 5).** Never exceed.
- **CRITICAL — Hard stop** if the error set is identical to the previous iteration (no progress).
- **CRITICAL — Hard stop** if 3 consecutive iterations all show no progress.
- **CRITICAL — Never skip `snapshot-verify.sh`.** It is the only mechanical guard against Fixer escapes.
</hard_rules>

Loop, iteration `c` starting at 1:

1. Spawn Fixer (`subagent_type: "bnb-fixer"`). Pass the latest validation JSON path. Fixer writes to `.bnb/validation-results/fix-cycles/cycle-{c}/`.
2. **CRITICAL** — run `${CLAUDE_PLUGIN_ROOT}/scripts/snapshot-verify.sh`. If it exits nonzero (Fixer touched a forbidden file) — **abort fix cycle**, print the diff, alert the user, suggest `git checkout -- <paths>`, stop. Do NOT continue the loop.
3. Spawn Validator again (new run number: `run-{c+1}`).
4. Run `${CLAUDE_PLUGIN_ROOT}/scripts/progress-check.sh M{n} run-{c} run-{c+1}`. It prints `progress` or `no-progress`.
5. If verdict is `clean` or `deferrable-only` → exit loop, mark milestone done, commit.
6. If `no-progress` count reaches 3 → stop loop. Print the unresolved blocker list, path to cycle artifacts, and ask the user how to proceed.
7. If iteration count reaches `max_fix_iterations` → stop loop, same escalation as no-progress.
8. Else, continue loop with `c = c+1`.

### Step 6 — Report

After the loop exits (success or escalation), print the report using the format below.

<output_format name="bake-report">
```
M{n}: <clean | deferrable-only | blocked | escalated>
Iterations: <c>/<max_fix_iterations>
Files touched: <n> across <k> fix cycles
Artifacts:
  - bake-summary: .bnb/milestones/M{n}.bake-summary.md
  - latest validation: .bnb/validation-results/M{n}-run-{k}.summary.md
  - fix cycles: .bnb/validation-results/fix-cycles/ (if any)
Next: <"OK, next?" prompt | stopped at user request | escalation — user action needed>
```

CRITICAL: every line is mandatory. Do not omit artifact pointers even when empty — write `(none)` instead.
</output_format>

## `--all` flow

Run single-milestone flow for each `pending` milestone in STATUS.md order. Between milestones, ask "OK, next?" and wait for user confirmation. Never run the next milestone without explicit OK.

## End-of-run fix pass

After the last milestone (or any time `--all` completes or is stopped mid-way), check `.bnb/validation-results/deferrables-accumulated.json`. If non-empty, ask the user: "Run end-of-run fix pass on N deferrables?" If yes, run the same fix cycle against the accumulated deferrables list.

## Hard rules

<hard_rules>
- **CRITICAL — Never modify `.bnb/spec/`, `.bnb/quality/`, or `.bnb/milestones/M*-*.md` from this command.** Those are contracts.
- **CRITICAL — Never skip `snapshot-verify.sh`.** Fixer escapes are the primary integrity risk.
- **CRITICAL — Never run the next milestone without explicit user OK** when in `--all` mode. "OK, next?" requires a literal user reply.
- **CRITICAL — Never re-classify Validator's verdict.** Read the `verdict` field verbatim from `summary.md`.
- **CRITICAL — Never auto-enter the fix cycle when `--no-auto-fix` was passed.**
- **IMPORTANT — Never force-push, never amend** commits produced here.
</hard_rules>

## Reminder before you finish

<reminder>
CRITICAL — before declaring the command done, verify:
1. For every milestone touched, `STATUS.md` reflects the outcome (`done`, `done-with-deferrables`, `blocked`, or unchanged if halted).
2. Every fix cycle executed ran `snapshot-verify.sh` — none were skipped.
3. In `--all` mode, every milestone transition past the first was preceded by a literal user "OK, next?" confirmation.
4. If `--no-auto-fix` was set, the fix cycle was NOT invoked on any `blocked` verdict.
5. The final report uses the `<output_format name="bake-report">` structure, no fields omitted.

Any fail → surface it to the user, do not silently gloss over.
</reminder>
