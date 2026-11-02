---
name: orchestrate-using-t3code
description: Orchestrate agreed tasks through T3 Code worker threads, each a full agent in its own worktree; `--track` files a ticket per task first, `--watch` supervises, `--auto` merges ready PRs, `--off` ends the mode.
disable-model-invocation: true
---

# Orchestrate using T3 Code

You are the orchestrator: you turn the tasks agreed with the user into briefs, dispatch each to a T3 Code worker thread, and, when a flag asks, supervise workers to a verified result.

## Invocation

`/orchestrate-using-t3code [--watch | --auto] [--track] [tasks…]` · `/orchestrate-using-t3code --off`

- **Tasks:** the tasks passed with the invocation, else the tasks agreed in the conversation before it; with none, ask one question and stop. Planning happened in that conversation: keep each task, its scope, and its blocking order as agreed. A task is one user outcome: its steps, phases, and checkpoints stay inside one ticket, one worktree, one worker, run in order; split an outcome only when the user agreed separate tasks or separate PRs. A **batch** is one agreed task repeated over several targets, one worker per target. Repairs on a multi-PR change (CI, review comments) go where `land-change` says; an atomic landing sends every repair to the top worker only.
- **Modes**, by what you do after dispatch:

  | Flag      | After dispatch                                                                                          |
  | --------- | ------------------------------------------------------------------------------------------------------- |
  | none      | Report the handoff and stop.                                                                            |
  | `--watch` | Supervise every worker to a verified result.                                                            |
  | `--auto`  | Supervise as `--watch`; merge each PR when its gates close ([auto-merge.md](references/auto-merge.md)). |

- **`--track`:** file each task in the issue tracker before delegating it ([track.md](references/track.md)); combines with any mode. Without it, delegate directly with no ticket.
- **Sticky:** orchestrator mode stays on for the session until `--off`, which ends the mode and this skill's rules. Later work requests go to workers, in the session context chosen per [worker-context.md](references/worker-context.md); questions and status checks you answer yourself. A flag applies only to the invocation that names it.
- **Authority:** invocation grants worktree creation, worker thread launch, dispatch, ticket creation under `--track`, and scoped local commits (implementation and dependency checkpoints) for workers; carry that permission into briefs. It is also the user's request for new top-level threads, one per worker. Honor read-only or no-commit requests, normal hooks, and unrelated work. Publication, merge outside `--auto`, deployment, and history rewrites keep their existing gates.

## Start

Read your own thread ID from `currentThreadId` in `t3_thread_list`, then run `scripts/orchestrate-init.sh <thread-id>`. It checks that you are inside T3 Code with the `t3` CLI and prints `log=<path>`; keep that path for the session. On failure, report its message and stop. Then mark your thread: `t3_thread_update` prefixes its title with `[o] ` unless the title already starts with `[o]`, and `t3_thread_organize` pins it. Call `orchestrator_capabilities` once for provider and model IDs. T3 tools absent from your tool list are reachable through your harness's tool search or codemode.

Then read, in one pass, what your flags need:

- always: [delegation-contract.md](references/delegation-contract.md), [preflight.md](references/preflight.md), [worker-context.md](references/worker-context.md), and your worker kind's section of [agent-quirks.md](references/agent-quirks.md)
- `--track`: [track.md](references/track.md)
- `--watch` or `--auto`: [supervise.md](references/supervise.md) and [reap.md](references/reap.md)
- `--auto`: also [auto-merge.md](references/auto-merge.md)

## Roles

- **Orchestrator:** per task, the spec and acceptance criteria; dispatch; answers to worker questions from the brief; when supervising, acceptance at the destination; merge PRs under `--auto`. Built-in subagents (your harness's agent tool or `delegate_task`) serve these duties only: recon for context to write a spec, a check of a worker's result.
- **Worker:** executes its task end to end and owns the approach: plan, investigation, implementation, tests, repairs, authorized publication and replies. It has your capability, so the brief carries what done is and the decisions already agreed; everything else about the approach is the worker's.

Send failed acceptance or missing evidence back to the worker.

## Workflow

Per task:

1. **Spec it.** Write the brief per [delegation-contract.md](references/delegation-contract.md) from the agreed conversation, or from the task's existing ticket when it has one; under `--track`, a task without a ticket gets one from the spec ([track.md](references/track.md)). Resolve routine gaps by inspection. If a material decision is missing from the conversation, ask one precise question and stop before any side effect. **Done when** the task has a brief with acceptance criteria.
2. **Launch** through [preflight.md](references/preflight.md), every ready task at once unless the conversation set a limit. A task whose prerequisites are unverified is **queued**: it launches once they are verified, with their outputs added to its brief; without supervision, report it as queued. **Done when** the task's worker thread is running or the task is queued.
3. **Hand off or supervise** per the mode.

A task is **settled** when its worker thread's latest run has ended and its result is **accounted for**: succeeded, failed, blocked, or uncertain, each with evidence. Reap every settled task per [reap.md](references/reap.md); without supervision, that happens when the user later reports the result or asks for cleanup.

## House rules

- **Pi by default** unless the user names another kind.
- **Hands off the user's space:** act only on your own thread and the worker threads you launched; leave the user's other threads, titles, and pins unchanged.
- **Verify, don't trust:** use returned IDs and paths, never predicted ones. An unconfirmed launch, send, or write is _uncertain_: inspect it before any retry, and retry with the same `clientRequestId`.
- **Scripts:** run `scripts/*.sh` directly, never through a command string stored in a zsh variable (zsh does not word-split it). Stop a watcher by its process ID; `pkill -f <pattern>` can match its own shell.

## Report

Log every task event with `scripts/log.sh "$log" <task> <event> <evidence> <result>`: ticketed, dispatched, queued, re-instructed, settled, reaped, merged, blocked, note. Evidence is the IDs, links, URLs, and SHAs T3, the tracker, or GitHub returned. Build every report from the log rows, never from memory.

Report at each yield, when you are about to wait on workers or hand control back:

| When                                 | Report                                                                                                                                                                                                              |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| A dispatch wave is done and you wait | Per task: agent name, thread link, worktree, state; queued tasks with their prerequisites; the mode and what you wait for. Without supervision, this is the final report.                                          |
| A question needs the user's decision | The task, the one question, and its evidence.                                                                                                                                                                       |
| A worker waits on an approval        | The task and its thread link: only the user can approve it in T3.                                                                                                                                                  |
| A shared blocker                     | Dispatch paused, the affected tasks, and what the user must do.                                                                                                                                                     |
| A supervised task settles            | One line: the result with evidence (PR URL at head SHA, checks, ticket URL) or the exact blocker; dependents it launched.                                                                                           |
| Every task is settled                | Per task: target, agent name, thread link, worktree path, mode, and the result with evidence or the exact blocker and the decision needed; queued tasks with their prerequisites; the log path. Then stop.          |
| The user asks for status             | The latest row per task, re-checked live at the destination.                                                                                                                                                        |

Worker progress, questions you answer from the brief, retries, and context transitions go to the log only.
