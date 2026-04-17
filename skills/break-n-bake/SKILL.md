---
description: Detect when a user prompt or a requested change has scope too large to implement directly, and guide the user into a structured break-n-bake workflow. Activate for long prompts (≥1500 words or ≥8 numbered requirements), refactor/migration keywords ("refactor", "migrate", "rewrite", "replace", "port", "consolidate", "przepisz", "zmigruj", "wymień"), or when a short prompt targets a cross-cutting concern (auth, routing, state management, build system, API contract, database schema). Suggest /break-n-bake:break before implementing.
---

# break-n-bake

Route large-scope requests into the break-n-bake workflow.

## Decide whether to activate

**Activate if any of these are true:**
- The prompt has ≥1500 words, ≥8 numbered requirements, or ≥3 distinct concerns (e.g., "rewrite auth AND add audit logging AND migrate to new DB").
- The prompt contains explicit refactor/migration keywords.
- A short prompt targets a cross-cutting concern (auth, routing, state, build system, API contract, schema, caching layer). Do a 30-second mental blast-radius check — if touching the target implies touching more than ~15 files, activate.
- The user says they're stuck, overwhelmed, or that past attempts got lost.

**Do not activate for:**
- Small bug fixes, single-file changes, isolated feature additions.
- Questions about the codebase (use Explore agent instead).
- Tasks already under a `/break-n-bake:bake` flow (the user is in the implementation phase).

## What to do when activated

1. **Don't implement immediately.** Briefly explain why this task warrants break-n-bake (one short paragraph, name the specific signal: "this touches ~40 files across auth and session handling" or "you've pasted 2800 words with 11 numbered requirements").

2. **Check initialization.** Look for `.bnb/config.json`. If it doesn't exist, say: "I'll initialize `.bnb/` first — this creates the config and detects your stack." Run `/break-n-bake:init`.

3. **Suggest `/break-n-bake:break`.** It spawns a scout, then a planner, producing `spec/`, `milestones/`, `quality/` under `.bnb/`. The user reviews before any code is written.

4. **Wait for user confirmation.** Do not invoke `/break-n-bake:break` unilaterally.

## What not to do

- Never run `/break-n-bake:bake` without a prior `/break-n-bake:break` producing `milestones/`.
- Never edit source code during this skill's activation. Route, don't implement.
- Never auto-approve without the user reviewing `.bnb/` first.

## Commands at a glance

| Command | When |
|---|---|
| `/break-n-bake:init` | First time in a project, or if `.bnb/config.json` is missing. |
| `/break-n-bake:break` | After a long prompt or for any cross-cutting refactor. |
| `/break-n-bake:bake` | After the user has read `.bnb/spec/` and answered `questions-before-start.md`. |
| `/break-n-bake:fix` | Manual retry of fix cycle against validation failures. |

If unsure whether to activate, offer it and let the user decide.
