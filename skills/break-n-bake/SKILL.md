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

1. **CRITICAL — Activation recap.** Before anything else, output to the user (2–3 lines):
   - The specific trigger signal **with a number**: word count, numbered-req count, distinct-concerns count, or estimated blast-radius files.
   - Which activation criterion fired (long prompt / refactor keyword / cross-cutting short prompt / stuck-user signal).
   - Confirmation: "I will NOT implement; I will suggest `/break-n-bake:break`."

   Vague reasons ("this is big", "sounds complex") do not count. Cite a number.

2. **Don't implement immediately.** The recap replaces any urge to start coding.

3. **Check initialization.** Look for `.bnb/config.json`. If it doesn't exist, say: "I'll initialize `.bnb/` first — this creates the config and detects your stack." Suggest `/break-n-bake:init`.

4. **Suggest `/break-n-bake:break`.** It spawns Explorer, then Breaker, producing `spec/`, `milestones/`, `quality/` under `.bnb/`. The user reviews before any code is written.

5. **CRITICAL — Wait for user confirmation.** Do not invoke `/break-n-bake:break` unilaterally. Your message must end with an explicit yes/no question.

## Output format

<output_format name="activation-message">
Your activation message has exactly these parts, in order:

```
Signal: <criterion that fired> — <concrete number, e.g., "2800 words, 11 numbered requirements" or "auth middleware referenced by 42 files">

<2–3 sentence paragraph explaining why break-n-bake helps for THIS prompt specifically — not generic praise of the workflow>

Proposed next step:
  1. /break-n-bake:init (if .bnb/config.json is missing)
  2. /break-n-bake:break (to produce spec/milestones/quality)

Want me to proceed? (yes/no)
```

CRITICAL: the message must NOT include implementation suggestions, architectural opinions, or code snippets. Route only.
IMPORTANT: if the signal number is unknown (cannot estimate blast radius), say so explicitly — do not invent a number to justify activation.
</output_format>

## Hard rules

<hard_rules>
- **CRITICAL — Never run `/break-n-bake:bake` without a prior `/break-n-bake:break`** producing `milestones/`.
- **CRITICAL — Never edit source code during this skill's activation.** Route, don't implement.
- **CRITICAL — Never invoke `/break-n-bake:break` unilaterally.** Wait for the user's yes/no.
- **CRITICAL — Never auto-approve** without the user reviewing `.bnb/` first.
- **IMPORTANT — Never activate for small changes** (single-file fix, isolated feature). Overhead > value.
- **IMPORTANT — Never activate when already inside a `/break-n-bake:bake` flow.** The user is mid-implementation.
</hard_rules>

## Reminder before you send the activation message

<reminder>
CRITICAL — verify all four before sending:
1. You cited a specific number (words / requirements / files / concerns) — not a vibe.
2. You did NOT edit source code, and you did NOT invoke `/break-n-bake:break` yourself.
3. The message ends with an explicit yes/no question — not a plan you already started executing.
4. If the task is small (single-file, isolated fix), you did NOT activate this skill.
</reminder>

## Commands at a glance

| Command | When |
|---|---|
| `/break-n-bake:init` | First time in a project, or if `.bnb/config.json` is missing. |
| `/break-n-bake:break` | After a long prompt or for any cross-cutting refactor. |
| `/break-n-bake:bake` | After the user has read `.bnb/spec/` and answered `questions-before-start.md`. |
| `/break-n-bake:fix` | Manual retry of fix cycle against validation failures. |

If unsure whether to activate, offer it and let the user decide.
