# Delegation contract

Every brief sent to a Herdr worker follows this template, the ticket shape of `to-tickets` plus what a fresh worker needs. Fill each section from the agreed conversation and the task's ticket, if any; write "None" rather than dropping a section. State what done is and what was agreed; the worker owns the rest of the approach.

The worker shares none of your context: not the conversation, not your exploration. Write the brief so a fresh agent with only the brief and its links can act without guessing.

<brief-template>

## What to build

The end-to-end behaviour this task makes work, from the user's perspective, not a layer-by-layer implementation list. When the task has a ticket, its identifier and URL; the ticket is authoritative for scope.

## Acceptance criteria

- [ ] Observable criterion the worker can prove (behaviour, test, artifact, destination state)
- [ ] ...

## Decisions

What the user and orchestrator already agreed: contract terms, interfaces, schema, testing seams. The worker follows them as written and reports a conflict instead of reinterpreting it.

## Context

What the worker cannot recover by reading: why this work exists, rejected approaches and why, user preferences, terms coined in the conversation, current environment state (branch, running services, known failures).

## Blocked by and inputs

Prerequisite tasks and the outputs they produced (branch, PR, artifact), plus references to read before starting (spec, ticket, docs) by link or path.

## Transitional code

Code this task rewires that a later task deletes, and its agreed seams.

## Scope

- **Worktree:** the assigned path and branch; work only there.
- **In scope:** what this task may touch.
- **Out of scope:** exclusions, including work owned by sibling tasks.
- **Authority:** local commits allowed unless the user restricted them; publication, merge, deployment, and history rewrites only as Deliverables grant.
- **Tripwires:** stop and report when the work needs a path, service, or data boundary outside scope, an unnamed migration or authority change, or a user decision.

## Deliverables

External results the mode or task requires, embedded in full: the worker contract from [auto-merge.md](auto-merge.md) under `--auto`; the ticket close-out from [track.md](track.md) under `--track`; any other requested external deliverables (open a PR). "None" for a plain local task.

</brief-template>

## Rules

- **Batch briefs** share one filled template; only the target in What to build, its inputs, and per-target overrides differ.
- **Link or inline.** Link sources the worker can open; inline anything that exists only in the conversation. Inline a snippet only when it encodes a decision more precisely than prose (schema, type shape, state machine).
- **Redact** secrets and sensitive data from every section.
