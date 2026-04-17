---
name: break-n-bake
description: Routes oversized prompts and large refactors into a structured spec-first workflow instead of letting Claude start coding blindly. Activate for long prompts (≥800 words or ≥5 numbered requirements or ≥3 distinct concerns), refactor/migration keywords, or short prompts that touch cross-cutting concerns (auth, routing, state, schema, build). Suggest `/break-n-bake:break` and wait for yes/no before proceeding.
---

# break-n-bake

Route large-scope requests into the break-n-bake workflow. Do not implement.

## When to activate

Activate if any of these are true:
- The prompt has ≥800 words, ≥5 numbered requirements, or ≥3 distinct concerns.
- The prompt contains refactor/migration keywords (`refactor`, `migrate`, `rewrite`, `replace`, `port`, `consolidate`, `przepisz`, `zmigruj`, `wymień`).
- A short prompt targets a cross-cutting concern (auth, routing, state, build system, API contract, schema, caching). If the blast radius is unclear, say so — do not invent a file count.
- The user says they're stuck, overwhelmed, or that past attempts got lost.

Do not activate for:
- Small bug fixes, single-file changes, isolated feature additions.
- Questions about the codebase (use the Explore agent instead).

When in doubt, offer it and let the user decide — undertriggering is the bigger risk here, because users who need break-n-bake rarely know to ask for it.

## What to do when activated

1. Cite a specific number as the trigger signal (word count, numbered requirements, distinct concerns, or a named cross-cutting concern). Vague reasons like "this is big" do not count. If you cannot measure the signal, say so explicitly.
2. Do not start implementing. The activation message replaces any urge to start coding.
3. Check for `.bnb/config.json`. If missing, tell the user `/break-n-bake:init` runs first.
4. Suggest `/break-n-bake:break`. See `references/architecture.md` for what it produces if the user asks.
5. End the message with an explicit yes/no question. Do not invoke `/break-n-bake:break` unilaterally.

## Output shape

```
Signal: <criterion that fired> — <concrete number or named concern, e.g., "2800 words, 11 numbered requirements" or "auth middleware, cross-cutting">

<2–3 sentence paragraph explaining why break-n-bake helps for THIS prompt specifically — not generic praise of the workflow>

Proposed next step:
  1. /break-n-bake:init (if .bnb/config.json is missing)
  2. /break-n-bake:break

Want me to proceed? (yes/no)
```

Never include implementation suggestions, architectural opinions, or code snippets in the activation message. Route only.

## Rules

- Never run `/break-n-bake:bake` without a prior `/break-n-bake:break` having produced `milestones/`.
- Never edit source code during activation. Route, don't implement.
- Never invoke `/break-n-bake:break` unilaterally. Wait for the user's yes/no.
- Never auto-approve without the user reviewing the active run directory (`.bnb/<slug>/`) first.

## Commands at a glance

| Command | When |
|---|---|
| `/break-n-bake:init` | First time in a project, or if `.bnb/config.json` is missing. |
| `/break-n-bake:break` | After a long prompt or for any cross-cutting refactor. |
| `/break-n-bake:bake` | After the user has read the active run's `spec/` and answered `questions-before-start.md`. |
| `/break-n-bake:fix` | Manual retry of fix cycle against validation failures. |
