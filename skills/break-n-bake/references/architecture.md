# break-n-bake architecture

Read this if the user asks what `/break-n-bake:break` actually does, or how run directories are laid out. The routing skill itself does not need these details to decide whether to activate.

## What `/break-n-bake:break` produces

`/break-n-bake:break` spawns two agents in sequence:

1. **Explorer** — read-only reconnaissance of the repo and the user's prompt. Produces a scout report the Breaker uses to size the work.
2. **Breaker** (Opus) — takes the prompt and scout report and writes a layered spec under `.bnb/<slug>/`.

## Run directory layout

Each `/break` creates its own run directory at `.bnb/<slug>/`, so artefacts from multiple tasks never collide. The slug is inferred from the prompt (e.g. `redesign-dashboard`).

```
.bnb/<slug>/
├── spec/                    — the contract: goals, constraints, open questions
├── milestones/              — ordered, checkpoint-able units of work
├── quality/                 — blocker/major/minor severity bars per milestone
├── validation/              — append-only overlays
│   ├── eslint overlays
│   ├── test files
│   └── LLM prompt checks
├── README.md
└── questions-before-start.md
```

## Why separate run directories

Two reasons:
- Multiple concurrent tasks (different branches, different prompts) don't stomp each other's specs.
- The slug makes it cheap to audit "what did we actually spec for this change" months later.

## Append-only validation

`validation/` is append-only on purpose. When `/bake` runs a milestone, Validator writes new overlays rather than editing old ones — so the history of what was checked, and what failed, is preserved across the whole run.
