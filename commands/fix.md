---
description: Manually run a bounded fix cycle against the latest validation failures. Use when /bake was invoked with --no-auto-fix, or when you want to retry after making manual changes.
---

# /break-n-bake:fix

Run a bounded fix cycle using Fixer + Validator until clean, deferrable-only, or hard-stop.

## Argument parsing

`$ARGUMENTS`:
- **Empty** → find the latest milestone in `.bnb/validation-results/` with any blockers, fix that one.
- **`M<n>`** → fix blockers for that specific milestone (must have a validation run).

## Preconditions

- `.bnb/config.json` must exist.
- At least one `M{n}-run-{k}.json` file must exist for the target milestone and its `blockers` array must be non-empty. If it's empty, print "nothing to fix" and stop.

## Steps

Identical to Step 5 of `/break-n-bake:bake` (the fix cycle). In short:

1. **Snapshot-lock** — hash test/config files before starting.
2. **Loop** bounded by `max_fix_iterations` (user config) with hard stop after 3 no-progress iterations:
   - Spawn Fixer → writes `.bnb/validation-results/fix-cycles/cycle-{c}/{targets,changes,escalations}.md`.
   - Run `snapshot-verify.sh` — if Fixer touched a forbidden file, abort, alert, stop.
   - Spawn Validator → new run number.
   - Run `progress-check.sh` — compare error sets.
   - Exit if `clean` / `deferrable-only` / max-iter / no-progress cap.
3. **Report** — verdict, iterations used, pointers to artifacts.

## After clean

If verdict ends `clean` or `deferrable-only`, mark the milestone `done` (or `done-with-deferrables`) in `.bnb/milestones/STATUS.md` and commit using the standard format.

## After escalation

If loop hit a hard stop:
- Print the unresolved blockers with file:line.
- Print any escalation entries Fixer wrote.
- Ask the user what to do (fix manually, change spec, mark out-of-scope, increase budget).
- Do not silently retry.

## Rules

- Same contract-protection rules as `/bake`: Fixer cannot touch test/config files, hooks + snapshot-verify enforce this.
- Never edit `.bnb/spec/`, `.bnb/quality/`, or milestone files from this command.
