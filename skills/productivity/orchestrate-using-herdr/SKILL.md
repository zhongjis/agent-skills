---
name: orchestrate-using-herdr
description: Orchestrate work through Herdr agents, one task or a batch, each worker in its own pane and worktree; `--watch` supervises, `--track` adds an issue-tracker ticket, `--auto` merges ready PRs.
disable-model-invocation: true
---

# Orchestrate using Herdr

You are the orchestrator. You turn the agreed work into briefs, dispatch each to its own Herdr agent, and, when a flag asks, supervise those agents to a verified result. Invoking this skill authorizes worktree creation, agent startup, and dispatch for the agreed work; the flags below authorize the rest.

## Preflight

Run `command -v herdr >/dev/null && test "${HERDR_ENV:-}" = 1`. If it fails, report that you are not inside Herdr and stop. Otherwise read `herdr --skill` once: it owns command syntax, pane/agent primitives, and lifecycle states. This skill adds only the orchestration layer; read [herdr-pitfalls.md](references/herdr-pitfalls.md) before your first Herdr command and the matching section of [agent-quirks.md](references/agent-quirks.md) before starting or reading an agent of that kind.

## Herdr agent or built-in subagent

Choose per work unit, by the task:

- **Built-in subagent** (your harness's agent tool): the result returns into your context and you need it this turn to continue (recon, research, a bounded check). It shares your checkout and the user does not see it.
- **Herdr agent**: the unit stands alone and can finish without you. It lives in a visible pane the user can watch or take over, gets its own worktree, may run another harness, and outlives your turn.

A Herdr agent is a peer orchestrator, not a specialist: it plans, delegates to its own subagents, verifies, and delivers. Mix both freely, for example subagent recon first, then Herdr workers for the implementation units.

## Modes

| Flag | Orchestrator after dispatch |
| --- | --- |
| none | Fire and forget: report the handoff and stop. |
| `--watch` | Supervise every worker to a verified result (see Supervision). |
| `--track` | Use an issue-tracker ticket per unit ([track.md](references/track.md)) and supervise as `--watch`. |
| `--auto` | Supervise as `--watch`; merge each worker's PR when its gates close ([auto-merge.md](references/auto-merge.md)). Combines with `--track`. |

## Tasks

The invocation's task list is the work. With no list, the work is the task or tasks already agreed in this session; if none is agreed, ask one question and stop.

- Each distinct task runs the one-task workflow.
- Tasks that repeat one instruction over items run as a batch.

## Workflow

Pick the shape, then follow its reference:

- **One task** (build work with its own outcome): [single.md](references/single.md).
- **Batch** (the same repeatable task over a list of items, one worker per item): [batch.md](references/batch.md).

## House rules

- **Worktree per unit.** Create it from the repository's parent source, never from a linked worktree's cwd; when the user asks, base it on the current worktree instead.
- **Pi by default.** Start workers as `pi` unless the user names another kind.
- **Local commits.** Invocation authorizes scoped implementation commits and dependency checkpoints for you and workers. Include permission in briefs; honor read-only/no-commit requests, normal hooks, and unrelated work. Publication, merge, deployment, and history changes retain their existing authorization gates.
- **Names.** Derive lowercase agent names from the unit (`a2a-140-cache-keys`, `review-457`), matching `[a-z][a-z0-9_-]{0,31}` and unique among live agents.
- **Hands off the user's space.** Keep your own pane (`$HERDR_PANE_ID`) and the user's focus; create with `--no-focus`; never start a worker in your pane; leave session and tab labels unchanged.
- **Briefs, not recipes.** Every brief follows [delegation-contract.md](references/delegation-contract.md): a self-contained brief with outcome, acceptance criteria, binding agreed details, conversation-only context, direction, and scope with tripwires. The worker owns the plan.
- **Verify, don't trust.** Use returned IDs, never predicted ones. An unconfirmed prompt submission or write is *uncertain*: inspect before any retry, and never resubmit blindly.

## Supervision

Applies under `--watch`, `--track`, and `--auto`.

- Run until every unit is **accounted for**: succeeded, failed, blocked, or uncertain, each with evidence.
- Herdr `idle`/`done` is a lifecycle signal, not success. Read the worker's output and check the destination itself (PR, posted review, ticket, artifact, test output).
- Answer worker questions and approval prompts you can settle from the brief. Tell the user only when a question needs their decision; they can see `blocked` panes themselves.
- On a shared blocker (expired auth, outage), stop new dispatch, report it, and wait for the user; unaffected active work may finish. Keep independent units going after an isolated failure.
- Integrate or merge worker results only under `--auto` or when the user asks.

## Worker context

Context management applies only when you send a live worker a **follow-up**: new work after its task settles, in any mode. The first dispatch always starts fresh. Steering a blocked or drifting worker back onto its original task is not a context decision; steer it in the same session. Decide per follow-up without asking; the user may override in the request:

- **Keep** the session when the follow-up builds directly on the worker's prior work (re-review the same PR).
- **Handoff** when the same unit enters a new phase and most of the old context is noise (implementation done, now `address-review`).
- **New** when the unit restarts because its context would mislead; send a corrected full brief.

Unrelated work always gets a new worker in its own worktree. The commands for each kind are in [agent-quirks.md](references/agent-quirks.md).

## Report

Per unit: target, worktree path, workspace, pane, agent name, mode, and, when supervised, status with evidence (PR URL, ticket URL, verified result) or the exact blocker and the decision needed. Then stop; leave workers and worktrees running unless the mode or the user calls for cleanup.
