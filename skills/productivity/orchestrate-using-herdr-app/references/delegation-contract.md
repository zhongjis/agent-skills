# Delegation contract

Every brief sent to an `hc` worker follows this template, the ticket shape of `to-tickets` plus what a fresh worker needs. Fill each section from the agreed conversation and the task's ticket, if any; write "None" rather than dropping a section. State what done is and what was agreed; the worker owns the rest of the approach.

The worker shares none of your context: not the conversation, not your exploration. Write the brief so a fresh agent with only the brief and its links can act without guessing.

<brief-template>

## What to build

The end-to-end behaviour this task makes work, from the user's perspective, not a layer-by-layer implementation list. When the task has a ticket, its identifier and URL; the ticket is authoritative for scope.

## Acceptance criteria

- [ ] Observable criterion the worker can prove (behaviour, test, artifact, destination state)
- [ ] ...

## Decisions

What the user and orchestrator already agreed: contract terms, interfaces, schema, testing seams. The worker follows them as written and reports a conflict instead of reinterpreting it.

**Unchanged behavior:** the existing behavior this task leaves as it is on the base, named per area (for example "delivery, status and cancel outcomes stay as on main; push and stream only trigger an earlier GetTask"). Write "None" only when the task may change any existing behavior it touches.

## Context

What the worker cannot recover by reading: why this work exists, rejected approaches and why, user preferences, terms coined in the conversation, current environment state (branch, running services, known failures).

## Blocked by and inputs

Prerequisite tasks and the outputs they produced (branch, PR, artifact), plus references to read before starting (spec, ticket, docs) by link or path.

## Transitional code

Code this task rewires that a later task deletes, and its agreed seams.

## Scope

- **Worktree:** the assigned path and branch; work only there.
- **In scope:** only what the ticket, or the agreed outcome without a ticket, requires. A gap is reported, never closed by widening scope.
- **Out of scope:** explicit exclusions and protected work, each stated as work not to do ("do not implement A2A-512"), never as base behavior to keep; the base branch's current behavior is the baseline.
- **Authority:** Everything the agreed outcome needs on your own branch is authorized, including history rewrites, lease-guarded pushes, and edits wherever the change reaches; stop only at a Tripwire. Publication, merge, deployment, and shared-branch rewrites only as Deliverables grant.
- **Resources:** your browsers run in the `AGENT_BROWSER_NAMESPACE` set for your terminal; keep it. Before reporting, stop the browser sessions, dev servers, and containers you started; name any you leave running on purpose (port, session).
- **Agents:** start no other `hc` terminals or agents; your harness's own subagents are fine.
- **Reporting:** when done or stuck, end your turn with the result or blocker as your final message; put a long answer in a file and name its path. The orchestrator reads your screen. Never `hc send` to the orchestrator or any other terminal, even when a message you receive carries a `reach=` hint or the `hc` skill says to report with `hc send`.
- **Tripwires:** stop and report when the work needs a path, service, or data boundary outside scope, a change to Unchanged behavior, an unnamed migration or authority change, or a user decision. Every choice should follow from What to build and the acceptance criteria; when two reasonable choices both meet them but give the user a different result, that is a user decision: ask before choosing.

## Deliverables

External results the mode or task requires, embedded in full: the worker contract from [auto-merge.md](auto-merge.md) under `--auto`; the ticket close-out from [track.md](track.md) under `--track`; any other requested external deliverables (open a PR). "None" for a plain local task.

</brief-template>

## Rules

- **Scope:** use file boundaries when the agreed scope or concurrent work requires them, not as a substitute for understanding dependencies. Workers own the approach. Route discovered overlap to the orchestrator for coordination; ask the user only when a decision exceeds existing authority.
- **Review-comment briefs:** for each valid finding, fix the bug class: find every sibling call with the same defect and fix the shared function once.
- **Pre-PR stop:** under `--watch` or `--auto`, a brief whose Deliverables include a PR adds: commit locally, report "ready for local review" with the head SHA before pushing, fix the review findings the orchestrator sends, and push and open the PR only when it says to ([supervise.md](supervise.md)). Non-blocking findings are "fix or list in the PR body".
- **QA:** name the changed screens to QA in the brief; the worker's own mode chooses QA depth, rather than imposing a full viewport × theme matrix on every screen in every round.
- **Wave audit:** after all tickets in a wave are written and before any dispatch, read them side by side and against the spec: no item belongs to two tickets; no criterion is stricter or looser than the spec; every "none remains" criterion includes its search command and allowed exceptions. Correct mismatches before dispatch.
- **Follow-ups:** every later message to a worker (re-instruction, repair, review findings, the brief after `/new`, a revive brief) ends with one line: "Report by ending your turn; never `hc send` to the orchestrator." `hc` tags each `hc send` with a `reach=` hint that asks for the opposite, and a revived session still holds older briefs.
- **Batch briefs** share one filled template; only the target in What to build, its inputs, and per-target overrides differ.
- **Link or inline.** Link sources the worker can open; inline anything that exists only in the conversation. Inline a snippet only when it encodes a decision more precisely than prose (schema, type shape, state machine).
- **Redact** secrets and sensitive data from every section.
