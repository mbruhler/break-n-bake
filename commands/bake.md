---
description: Implement one milestone (or all sequentially with checkpoints) from the active run's milestones/. Spawns Baker, then Validator, and on blocker-severity failures runs a bounded fix cycle via Fixer.
---

# /break-n-bake:bake

Execute implementation phase.

## Active run resolution

Every path in this command is resolved relative to the **active run dir** — never to `.bnb/` directly. Let `$RUN_DIR = .bnb/<slug>/` where `<slug>` comes from (in order):

1. `$BNB_RUN_DIR` env var
2. `$BNB_RUN` env var → `.bnb/$BNB_RUN`
3. Contents of `.bnb/CURRENT_RUN`

If none of the above resolves, stop and tell the user to run `/break-n-bake:break` first.

Scripts (`snapshot-lock.sh`, `snapshot-verify.sh`, `run-validation.sh`, `progress-check.sh`) resolve the same way automatically — you do not need to pass the run dir to them.

## Argument parsing

`$ARGUMENTS` interpretation:
- **Empty** → bake the next `pending` milestone in `$RUN_DIR/milestones/STATUS.md`, then **STOP**. Do not continue to the next milestone. Exiting after one milestone is the correct and expected behavior — the user must re-invoke `/break-n-bake:bake` (or pass `--all`) to proceed.
- **`M<n>`** (e.g., `M3`) → bake that specific milestone, then **STOP**. Same single-milestone rule as empty.
- **`--all`** → bake every remaining milestone of the active run sequentially, no user gate between milestones (automatic chaining).
- **`--no-auto-fix`** combined with any of the above → do not run the fix cycle automatically; just report Validator's results and stop.

**CRITICAL — Default (no args) is single-milestone.** If `--all` was not explicitly passed in `$ARGUMENTS`, you MUST halt after the first milestone finishes (whether `clean`, `deferrable-only`, `blocked`, or escalated). Do not ask "OK, next?". Do not auto-continue. Print the report and end the command.

## Preconditions

1. `.bnb/config.json` must exist. If not, stop and tell the user to run `/break-n-bake:init` and `/break-n-bake:break` first.
2. An active run must be resolvable (see "Active run resolution" above).
3. `$RUN_DIR/milestones/STATUS.md` must exist. If not, tell the user to run `/break-n-bake:break` first.
4. The milestone being baked must have unanswered `$RUN_DIR/questions-before-start.md` questions resolved. If any open question is tagged relevant to this milestone, stop and ask the user.

## Preflight recap

**CRITICAL** — after parsing arguments and verifying preconditions, before spawning any agent, output to user in 5–7 lines:
- **Active run slug** and `$RUN_DIR` path.
- Target milestone(s): e.g., `M3` or `M3..Mn (--all)`.
- Risk tag and time budget from the milestone's frontmatter.
- Mode flags in effect: `--all`, `--no-auto-fix` (y/n each).
- Planned verdict branches: what you will do on `clean` / `deferrable-only` / `blocked`.
- Scripts you will invoke in order: `snapshot-lock.sh`, validation run, `snapshot-verify.sh`, `progress-check.sh`.

Do NOT spawn Baker or run any script until the recap is out. This confirms arguments parsed correctly, you are operating on the intended run, and you will not improvise verdict handling.

## Single-milestone flow (M{n})

### Step 1 — Baker

Spawn Baker (`subagent_type: "bnb-baker"`). Pass it the milestone identifier **and the active run dir path** so it reads spec/milestones/quality from the right place. If `$RUN_DIR/milestones/M{n}-*.md` has `risk: high` in its frontmatter/header, spawn Baker with model override `opus` (if supported) or note in the brief: "milestone is flagged high-risk, escalate any ambiguity immediately."

Wait for Baker to finish. Baker will write `$RUN_DIR/milestones/M{n}.bake-summary.md`.

### Step 2 — Post-bake summary

**CRITICAL — before running any script or spawning Validator**, read `$RUN_DIR/milestones/M{n}.bake-summary.md` (written by Baker) and output a short summary to the user:
- A bullet list of the key changes Baker made (files added/modified, behaviour introduced).
- Any notable decisions or deviations Baker flagged.

Keep it concise (≤10 bullets). This gives the user a chance to spot obvious mistakes before validation runs.

### Step 3 — Snapshot lock

Run `${CLAUDE_PLUGIN_ROOT}/scripts/snapshot-lock.sh` — this records SHA256 hashes of all test/config files into `$RUN_DIR/.snapshots/` so we can verify Fixer didn't touch them later. The script resolves the active run automatically.

### Step 4 — Validator

Spawn Validator (`subagent_type: "bnb-validator"`) **with `run_in_background: true`**, and pass it the active run dir. Validator writes `$RUN_DIR/validation-results/M{n}-run-1.json` and `$RUN_DIR/validation-results/M{n}-run-1.summary.md`. You may continue other orchestration while Validator runs, but you must await its result before deciding next steps.

Read the summary when Validator finishes.

### Step 5 — Branch on verdict

**CRITICAL — read Validator's `summary.md` verdict field verbatim. Do not infer. Do not re-classify.** The verdict is one of: `clean`, `deferrable-only`, `blocked`. Anything else → stop and surface the artifact path to the user.

**Verdict = `clean`:**
- Mark `M{n}: done` in `$RUN_DIR/milestones/STATUS.md`.
- Git commit using the format from `$RUN_DIR/milestones/README.md`.
- If `--all` was explicitly passed, proceed automatically to M{n+1} (no user gate). If a speculative Baker for M{n+1} was already spawned in parallel during Step 4, resume with its bake-summary. **Otherwise (default / `M<n>` mode) STOP** — do not continue to the next milestone, do not prompt the user to continue. The command ends here.

**Verdict = `deferrable-only`:**
- Mark `M{n}: done-with-deferrables` in STATUS.md.
- Append the deferrable IDs to `$RUN_DIR/validation-results/deferrables-accumulated.json`.
- Commit. Proceed as above (automatic in `--all`; stop otherwise).

**Verdict = `blocked`:**
- **CRITICAL — If `--no-auto-fix` was passed, stop here.** Print blocker summary and JSON artifact path. Tell the user to run `/break-n-bake:fix`. Do NOT enter the fix cycle.
- Else, enter fix cycle (next section).

### Step 6 — Fix cycle (bounded)

<hard_rules name="fix-cycle-invariants">
- **CRITICAL — `max_fix_iterations` = user config (default 5).** Never exceed.
- **CRITICAL — Hard stop** if the error set is identical to the previous iteration (no progress).
- **CRITICAL — Hard stop** if 3 consecutive iterations all show no progress.
- **CRITICAL — Never skip `snapshot-verify.sh`.** It is the only mechanical guard against Fixer escapes.
</hard_rules>

Loop, iteration `c` starting at 1:

1. Spawn Fixer (`subagent_type: "bnb-fixer"`). Pass the latest validation JSON path and the active run dir. Fixer writes to `$RUN_DIR/validation-results/fix-cycles/cycle-{c}/`.
2. **CRITICAL** — run `${CLAUDE_PLUGIN_ROOT}/scripts/snapshot-verify.sh`. If it exits nonzero (Fixer touched a forbidden file) — **abort fix cycle**, print the diff, alert the user, suggest `git checkout -- <paths>`, stop. Do NOT continue the loop.
3. Spawn Validator again (new run number: `run-{c+1}`).
4. Run `${CLAUDE_PLUGIN_ROOT}/scripts/progress-check.sh M{n} run-{c} run-{c+1}`. It prints `progress` or `no-progress`.
5. If verdict is `clean` or `deferrable-only` → exit loop, mark milestone done, commit.
6. If `no-progress` count reaches 3 → stop loop. Print the unresolved blocker list, path to cycle artifacts, and ask the user how to proceed.
7. If iteration count reaches `max_fix_iterations` → stop loop, same escalation as no-progress.
8. Else, continue loop with `c = c+1`.

### Step 7 — Report

After the loop exits (success or escalation), print the report using the format below.

<output_format name="bake-report">
```
Run: <slug>
M{n}: <clean | deferrable-only | blocked | escalated>
Iterations: <c>/<max_fix_iterations>
Files touched: <n> across <k> fix cycles
Artifacts:
  - bake-summary: .bnb/<slug>/milestones/M{n}.bake-summary.md
  - latest validation: .bnb/<slug>/validation-results/M{n}-run-{k}.summary.md
  - fix cycles: .bnb/<slug>/validation-results/fix-cycles/ (if any)
Next: <continuing with M{n+1} | stopped at user request | escalation — user action needed>
```

CRITICAL: every line is mandatory. Do not omit artifact pointers even when empty — write `(none)` instead.
</output_format>

## `--all` flow

`--all` is **automatic** — no "OK, next?" gate between milestones. Run the single-milestone flow for each `pending` milestone of the active run in STATUS.md order, chaining automatically on `clean` / `deferrable-only` verdicts.

### Parallel speculative bake (only in `--all`)

Because Validator runs in the background (Step 4), you do not have to idle while it runs. As soon as Validator for M{n} is spawned with `run_in_background: true`:

1. **Speculatively spawn Baker for M{n+1}** in parallel, provided M{n+1} exists and is `pending` in STATUS.md.
2. Continue to wait for Validator M{n}'s result.
3. When Validator M{n} finishes:
   - **Verdict `clean` / `deferrable-only`** → commit M{n}, then wait for speculative Baker M{n+1} to finish (if still running), run its bake-summary step, snapshot-lock, and spawn Validator M{n+1} (again in background). Repeat.
   - **Verdict `blocked`** → the speculative M{n+1} bake is now **invalid** because the fix cycle on M{n} will change the baseline. **CRITICAL — abort/discard the speculative M{n+1} work**: if Baker M{n+1} already produced file changes, `git checkout -- .` / reset those paths (only the ones Baker M{n+1} touched, identifiable from its bake-summary). Then enter M{n}'s fix cycle as normal. After M{n} is resolved, re-bake M{n+1} from a clean baseline.

### Hard rules for parallel bake

<hard_rules name="parallel-bake">
- **CRITICAL — Only in `--all` mode.** Single-milestone invocations (empty args, `M<n>`) never speculatively bake the next milestone.
- **CRITICAL — Never commit M{n+1} before M{n} is confirmed `clean` or `deferrable-only`.** Commits must be sequential and gated on the prior milestone's verdict.
- **CRITICAL — On `blocked` verdict for M{n}, discard speculative M{n+1} changes before entering fix cycle.** The fix cycle must operate on a clean baseline matching M{n}'s post-Baker state.
- **CRITICAL — Never speculatively bake more than one milestone ahead.** At most one speculative Baker may be in flight at any time.
- Do not speculatively bake across `risk: high` boundaries — if M{n+1} is tagged `risk: high`, wait for M{n}'s verdict before spawning Baker M{n+1}.
</hard_rules>

## End-of-run fix pass

After the last milestone of the active run (or any time `--all` completes or is stopped mid-way), check `$RUN_DIR/validation-results/deferrables-accumulated.json`. If non-empty, ask the user: "Run end-of-run fix pass on N deferrables?" If yes, run the same fix cycle against the accumulated deferrables list.

## Hard rules

<hard_rules>
- **CRITICAL — Every file path must be under `$RUN_DIR`, never directly under `.bnb/` (apart from `.bnb/config.json`, `.bnb/CURRENT_RUN`, `.bnb/README.md`).** Files like `.bnb/milestones/...` or `.bnb/spec/...` at `.bnb/` root are bugs — they belong under `.bnb/<slug>/...`.
- **CRITICAL — Never modify `$RUN_DIR/spec/`, `$RUN_DIR/quality/`, or `$RUN_DIR/milestones/M*-*.md` from this command.** Those are contracts.
- **CRITICAL — Never edit an existing file under `$RUN_DIR/validation/`.** That layer is append-only and sealed by `.snapshots/validation.lock`. Baker may add new numbered files and must re-run `validation-lock.sh` + `regen-eslint-overlay.sh` when it does.
- **CRITICAL — Never skip `snapshot-verify.sh`.** Fixer escapes are the primary integrity risk.
- **CRITICAL — `--all` is automatic: no user gate between milestones.** But parallel speculative bake may never commit M{n+1} before M{n}'s verdict is `clean` / `deferrable-only`, and must discard M{n+1} changes on a `blocked` verdict for M{n}.
- **CRITICAL — Never re-classify Validator's verdict.** Read the `verdict` field verbatim from `summary.md`.
- **CRITICAL — Never auto-enter the fix cycle when `--no-auto-fix` was passed.**
- **CRITICAL — Never switch the active run mid-command.** If `.bnb/CURRENT_RUN` changes during a bake, you already resolved it at start and must keep using that value throughout.
- **IMPORTANT — Never force-push, never amend** commits produced here.
</hard_rules>

## Reminder before you finish

<reminder>
CRITICAL — before declaring the command done, verify:
1. The active run was resolved at preflight and used consistently throughout (no writes outside `$RUN_DIR`).
2. For every milestone touched, `$RUN_DIR/milestones/STATUS.md` reflects the outcome (`done`, `done-with-deferrables`, `blocked`, or unchanged if halted).
3. Every fix cycle executed ran `snapshot-verify.sh` — none were skipped.
4. In `--all` mode, milestone transitions were automatic; any speculative M{n+1} bake was committed only after M{n}'s verdict was `clean` / `deferrable-only`, and discarded on `blocked`.
5. If `--no-auto-fix` was set, the fix cycle was NOT invoked on any `blocked` verdict.
6. The final report uses the `<output_format name="bake-report">` structure, no fields omitted.

Any fail → surface it to the user, do not silently gloss over.
</reminder>
