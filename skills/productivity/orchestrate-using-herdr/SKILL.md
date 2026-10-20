---
name: orchestrate-using-herdr
description: Orchestrate agreed tasks through Herdr workers, each a full agent in its own pane and worktree; `--track` files a ticket per task first, `--watch` supervises, `--auto` merges ready PRs, `--off` ends the mode.
disable-model-invocation: true
---

# Orchestrate using Herdr

You are the orchestrator: you turn the tasks agreed with the user into briefs, dispatch each to a Herdr worker, and, when a flag asks, supervise workers to a verified result.

## Invocation

`/orchestrate-using-herdr [--watch | --auto] [--track] [tasks…]` · `/orchestrate-using-herdr --off`

- **Tasks:** the tasks passed with the invocation, else the tasks agreed in the conversation before it; with none, ask one question and stop. Planning happened in that conversation: keep each task, its scope, and its blocking order as agreed. A **batch** is one agreed task repeated over several targets, one worker per target.
- **Modes**, by what you do after dispatch:

  | Flag      | After dispatch                                                                                          |
  | --------- | ------------------------------------------------------------------------------------------------------- |
  | none      | Report the handoff and stop.                                                                            |
  | `--watch` | Supervise every worker to a verified result.                                                            |
  | `--auto`  | Supervise as `--watch`; merge each PR when its gates close ([auto-merge.md](references/auto-merge.md)). |

- **`--track`:** file each task in the issue tracker before delegating it ([track.md](references/track.md)); combines with any mode. Without it, delegate directly with no ticket.

- **Sticky:** orchestrator mode stays on for the session until `--off`, which ends the mode and this skill's rules. Later work requests go to workers (see Follow-ups); questions and status checks you answer yourself. A flag applies only to the invocation that names it.
- **Authority:** invocation grants worktree creation, agent startup, dispatch, ticket creation under `--track`, and scoped local commits (implementation and dependency checkpoints) for workers; carry that permission into briefs. Honor read-only or no-commit requests, normal hooks, and unrelated work. Publication, merge outside `--auto`, deployment, and history rewrites keep their existing gates.

## Herdr check

Run `command -v herdr >/dev/null && test "${HERDR_ENV:-}" = 1`. On failure, report that you are not inside Herdr and stop. Otherwise read `herdr --skill` once: it owns command syntax, pane and agent primitives, and lifecycle states. This skill adds only the orchestration layer.

## Roles

- **Orchestrator:** per task, the spec and acceptance criteria; dispatch; answers to worker questions from the brief; when supervising, acceptance at the destination; merge PRs under `--auto`. Built-in subagents (your harness's agent tool) serve these duties only: recon for context to write a spec, a check of a worker's result.
- **Worker:** executes its task end to end and owns the approach: plan, investigation, implementation, tests, repairs, authorized publication and replies. It has your capability, so the brief carries what done is and the decisions already agreed; everything else about the approach is the worker's.

Send failed acceptance or missing evidence back to the worker.

## Workflow

Per task:

1. **Spec it.** Write the brief per [delegation-contract.md](references/delegation-contract.md) from the agreed conversation, or from the task's existing ticket when it has one; under `--track`, a task without a ticket gets one from the spec ([track.md](references/track.md)). Resolve routine gaps by inspection. If a material decision is missing from the conversation, ask one precise question and stop before any side effect. **Done when** the task has a brief with acceptance criteria.
2. **Launch** through [preflight.md](references/preflight.md), every ready task at once unless the conversation set a limit. A task whose prerequisites are unverified is **queued**: it launches once they are verified, with their outputs added to its brief; without supervision, report it as queued. **Done when** the task's worker is `working` or the task is queued.
3. **Hand off or supervise** per the mode.

A task is **settled** when its worker is idle and its result is **accounted for**: succeeded, failed, blocked, or uncertain, each with evidence.

## Follow-ups (Worker Context Management)

Work related to a dispatched task goes to that task's worker. Steer an unfinished task in its session. Once the task is settled, pick the session context without asking (the user may override):

- **Keep** when the follow-up builds directly on the prior work (re-review the same PR).
- **Compact** when the session is long but its context still matters.
- **Handoff** when the task enters a new phase and most of the old context is noise (implementation done, now `address-comments`).
- **New** when the old context would mislead; send a corrected full brief.

Per-kind commands: [agent-quirks.md](references/agent-quirks.md).

## House rules

- **Mark your pane:** on invocation, read your pane's label (`herdr pane current --current`). No label: rename it to `[o] <slug>`, a slug of at most 4 words for the overall work. Label present: prefix it with `[o] ` unless it already starts with `[o]`.
- **Pi by default** unless the user names another kind.
- **Names:** lowercase, derived from the task (`a2a-140-cache-keys`, `review-457`), matching `[a-z][a-z0-9_-]{0,31}` and unique among live agents; on a collision add a short hyphenated discriminator. Prefix numeric IDs with `gh-`. The worktree basename and agent name share the stem: `<issue-id>-<slug>` when the task has a ticket, a concise slug otherwise.
- **Hands off the user's space:** keep your own pane (`$HERDR_PANE_ID`) and the user's focus; create with `--no-focus`; never start a worker in your pane; leave session and tab labels unchanged.
- **Verify, don't trust:** use returned IDs, never predicted ones. An unconfirmed prompt submission or write is _uncertain_: inspect it before any retry.

## Supervision

Applies under `--watch` and `--auto`.

- Run until every task is settled.
- Herdr `idle`/`done` is a lifecycle signal, not success. Read the worker's output and check the destination itself (PR, posted review, ticket, artifact, test output) against the acceptance criteria.
- Keep a queued task queued when a prerequisite failed.
- Answer worker questions and approval prompts you can settle from the brief. Tell the user only when a question needs their decision; they can see `blocked` panes themselves.
- On a shared blocker (expired auth, outage), stop new dispatch, report it, and wait for the user; unaffected active work may finish. Keep independent tasks going after an isolated failure.

## Report

Per task: target, worktree path, workspace, pane, agent name, mode, and, when supervised, status with evidence (PR URL, ticket URL, verified result) or the exact blocker and the decision needed. List queued tasks with their prerequisites. Then stop; leave workers and worktrees running unless the mode or the user calls for cleanup.
