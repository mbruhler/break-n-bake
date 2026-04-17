---
description: Manually run a bounded fix cycle against the latest validation failures. Use when /bake was invoked with --no-auto-fix, or when you want to retry after making manual changes.
---

# /break-n-bake:fix

Run a bounded fix cycle using Fixer + Validator until clean, deferrable-only, or hard-stop.

## Active run resolution

As with `/bake`, all paths resolve relative to the **active run dir** `$RUN_DIR = .bnb/<slug>/`, selected via `$BNB_RUN_DIR`, `$BNB_RUN`, or `.bnb/CURRENT_RUN`. If no run resolves, stop and tell the user to run `/break-n-bake:break` first.

## Argument parsing

`$ARGUMENTS`:
- **Empty** → find the latest milestone in `$RUN_DIR/validation-results/` with any blockers, fix that one.
- **`M<n>`** → fix blockers for that specific milestone (must have a validation run under the active run).

## Preconditions

- `.bnb/config.json` must exist.
- An active run must be resolvable.
- At least one `$RUN_DIR/validation-results/M{n}-run-{k}.json` file must exist for the target milestone and its `blockers` array must be non-empty. If empty, print "nothing to fix" and stop.

## Preflight recap

**CRITICAL** — before spawning any agent, output in 4–6 lines:
- **Active run slug** and `$RUN_DIR` path.
- Target milestone: `M{n}`.
- Source validation run: path to the latest `$RUN_DIR/validation-results/M{n}-run-{k}.json`, with blocker count and category breakdown.
- `max_fix_iterations` from user config.
- Hard-stop conditions in effect: max iters, 3 consecutive no-progress.
- Scripts to invoke in order: `snapshot-lock.sh`, `snapshot-verify.sh` per cycle, `progress-check.sh` per cycle.

Do NOT spawn Fixer until the recap is out.

## Steps

Identical to Step 6 of `/break-n-bake:bake` (the fix cycle). In short:

1. **Snapshot-lock** — hash test/config files before starting (writes to `$RUN_DIR/.snapshots/`).
2. **Loop** bounded by `max_fix_iterations` (user config) with hard stop after 3 no-progress iterations:
   - Spawn Fixer, passing the active run dir → writes `$RUN_DIR/validation-results/fix-cycles/cycle-{c}/{targets,changes,escalations}.md`.
   - **CRITICAL** — run `snapshot-verify.sh`. If Fixer touched a forbidden file → abort, alert user, stop. Never skip.
   - Spawn Validator → new run number.
   - Run `progress-check.sh` — compare error sets.
   - Exit if `clean` / `deferrable-only` / max-iter / no-progress cap.
3. **Report** using `<output_format>` below.

## After clean

If verdict ends `clean` or `deferrable-only`, mark the milestone `done` (or `done-with-deferrables`) in `$RUN_DIR/milestones/STATUS.md` and commit using the standard format.

## After escalation

If loop hit a hard stop:
- Print the unresolved blockers with file:line.
- Print any escalation entries Fixer wrote.
- Ask the user what to do (fix manually, change spec, mark out-of-scope, increase budget).
- **CRITICAL** — do not silently retry. Do not loop back without an explicit user decision.

## Output format

<output_format name="fix-report">
```
Run: <slug>
M{n}: <clean | deferrable-only | escalated-max-iter | escalated-no-progress | aborted-snapshot>
Iterations: <c>/<max_fix_iterations>
Files touched: <n> across <c> cycles
Unresolved blockers: <count>
Escalations written: <count> (path: .bnb/<slug>/validation-results/fix-cycles/cycle-{c}/escalations.md)
Next: <STATUS updated + committed | user decision needed>
```

CRITICAL: every line mandatory. Write `(none)` where empty — never omit.
</output_format>

## Hard rules

<hard_rules>
- **CRITICAL — Every file path must be under `$RUN_DIR`, never directly under `.bnb/`.**
- **CRITICAL — Same contract-protection as `/bake`:** Fixer cannot touch test/config files; hooks + `snapshot-verify.sh` enforce this.
- **CRITICAL — Never edit `$RUN_DIR/spec/`, `$RUN_DIR/quality/`, or milestone files** from this command.
- **CRITICAL — Never skip `snapshot-verify.sh`** between cycles.
- **CRITICAL — Never exceed `max_fix_iterations`** or bypass the 3-no-progress hard stop.
- **CRITICAL — Never switch the active run mid-command.**
- **IMPORTANT — Never silently retry** after an escalation — require an explicit user decision.
</hard_rules>

## Reminder before you finish

<reminder>
CRITICAL — before declaring `/fix` done, verify:
1. The active run was resolved at preflight and used consistently.
2. `snapshot-verify.sh` ran after every cycle — none skipped.
3. Iteration count never exceeded `max_fix_iterations`.
4. On `clean` / `deferrable-only`, `STATUS.md` (inside the run dir) was updated AND a commit was made.
5. On escalation, no commit was made silently — the user was asked what to do.
6. The report uses `<output_format name="fix-report">`.
</reminder>
