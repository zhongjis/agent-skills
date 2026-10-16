# Delegation contract

Every brief sent to a Herdr worker follows this template. Fill each section from the spec, the ticket, and what you and the user already agreed; write "None" rather than dropping a section. The worker is a peer orchestrator: state the outcome and its bounds, never a step list.

The worker shares none of your context: not the conversation, not your exploration. Write the brief so a fresh agent with only the brief and its links can act without guessing. Link what the worker can open; inline what exists only in the conversation.

<brief-template>

## Goal

The end-to-end outcome this unit makes work and why it matters, from the user's perspective, not a layer-by-layer implementation list. Under `--track`, the ticket identifier and URL; the ticket is authoritative for scope.

## Acceptance criteria

- [ ] Observable criterion the worker can prove (behavior, test, artifact, destination state)
- [ ] ...

## Binding decisions

Contract terms and implementation details the user and orchestrator already agreed. The worker follows them as written and reports a conflict instead of reinterpreting it. "None" when nothing was agreed beyond the goal.

## Context

What the worker cannot recover by reading: why this work exists, rejected approaches and why, user preferences, terms coined in the conversation, current environment state (branch, running services, known failures). "None" only when the Goal and Inputs are self-explanatory.

## Direction

General direction and suggested skills: preferred approach, prior art to follow, seams to test at. Advisory; the worker owns the plan.

## Scope

- **Worktree:** the assigned path and branch; work only there.
- **In scope:** what this unit may touch.
- **Out of scope:** exclusions, including work owned by sibling units.
- **Tripwires:** stop and report when the work needs a path, service, or data boundary outside scope, an unnamed migration or authority change, or a user decision.

## Inputs

References to read before starting (spec, ticket, docs, artifacts), by link or path instead of copied text, plus outputs from units that blocked this one. "None" when the unit can start cold.

## Transitional code

Code this unit rewires that a later unit deletes, and its agreed seams. "None" if nothing is transitional.

## Mode contract

The worker side of the active mode, embedded in full, never as a file path: the worker contract from [auto-merge.md](auto-merge.md) under `--auto`; requested external deliverables (update the ticket, open a PR) otherwise. "None" for a plain local task.

</brief-template>

## Rules

- **Batch briefs** share one filled template; only Goal (the item and its target), Inputs, and per-item overrides differ.
- **Link or inline.** Link sources the worker can open instead of copying them; inline anything that exists only in the conversation. Inline a snippet only when it encodes a decision more precisely than prose (schema, type shape, state machine).
- **Redact** secrets and sensitive data from every section.
- **Pi workers:** the prompt ends with the literal `ulw`, after the Mode contract.
