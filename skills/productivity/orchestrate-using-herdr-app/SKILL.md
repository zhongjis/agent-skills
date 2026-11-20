---
name: orchestrate-using-herdr-app
description: Orchestrate agreed tasks through herdr-app workers, each a full agent in its own herdr-core (`hc`) terminal and worktree; `--track` files a ticket per task first, `--watch` supervises, `--auto` merges ready PRs, `--max` caps how many agents work at once, `--handoff` passes the tasks to a peer orchestrator, `--off` ends the mode.
disable-model-invocation: true
---

# Orchestrate using herdr-app

You are the orchestrator: you turn the tasks agreed with the user into briefs, dispatch each to an `hc` worker, and, when a flag asks, supervise workers to a verified result.

## Invocation

`/orchestrate-using-herdr-app [--handoff] [--watch | --auto] [--max <N>] [--track] [tasks…]` · `/orchestrate-using-herdr-app --off`

- **Tasks:** the tasks passed with the invocation, else the tasks agreed in the conversation before it; with none, ask one question and stop. Planning happened in that conversation: keep each task, its scope, and its blocking order as agreed. A task is one user outcome: its steps, phases, and checkpoints stay inside one ticket, one worktree, one worker, run in order; split an outcome only when the user agreed separate tasks or separate PRs. Every PR pays the repository's fixed CI cost: before dispatch, when two or more agreed tasks are each small (about 10 files or fewer) and touch the same area, propose one task and one PR for them. A **batch** is one agreed task repeated over several targets, one worker per target. Repairs on a multi-PR change (CI, review comments) go where `land-change` says; an atomic landing sends every repair to the top worker only.
- **Modes**, by what you do after dispatch:

  | Flag      | After dispatch                                                                                          |
  | --------- | ------------------------------------------------------------------------------------------------------- |
  | none      | Report the handoff and stop.                                                                            |
  | `--watch` | Supervise every worker to a verified result.                                                            |
  | `--auto`  | Supervise as `--watch`; merge each PR when its gates close ([auto-merge.md](references/auto-merge.md)). |

- **`--handoff`:** start one peer orchestrator in a new conversation, your own agent kind unless the user names another, and hand it the tasks; typically a side issue that came up mid-conversation and needs its own context ([handoff.md](references/handoff.md)). Other flags on this invocation go to the peer as its own skill invocation, and you act on none of them; with `--handoff` alone the peer is a normal agent with no skill. You report the handoff and drop the tasks.
- **`--track`:** file each task in the issue tracker before delegating it ([track.md](references/track.md)); combines with any mode. Without it, delegate directly with no ticket.
- **`--max <N>`:** with `--watch` or `--auto`, at most N of your agents, workers and reviewers alike, are `working` at once, so parallel test runs do not starve the host's CPU; an idle, blocked, or finished agent holds no slot. `orchestrate-init.sh` refuses it without a supervising mode, since nothing would free a slot.
- **Sticky:** orchestrator mode stays on for the session until `--off`, which ends the mode and this skill's rules: run `scripts/orchestrate-init.sh <slug> --mode '--off'`. It removes the `orch-context` label before checking beads, so a beads outage still clears the local label but reports a shared blocker. With an open session epic it records `event=mode flags=--off` and closes it only when every child is closed. With none, it creates no epic and prints `unset ORCH_EPIC` and `unset ORCH_MAX`; apply those lines. Later work requests go to workers, in the session context chosen per [worker-context.md](references/worker-context.md); questions and status checks you answer yourself. A flag applies only to the invocation that names it and to follow-ups of its tasks (a repair or correction ticket for the same outcome); unrelated new work takes its own flags. A `--handoff` invocation does not turn orchestrator mode on; a session already in it stays in it.
- **Authority:** invocation grants worktree creation, agent startup, dispatch, ticket creation under `--track`, and scoped own-branch work for workers per [delegation-contract.md](references/delegation-contract.md); carry that permission into briefs. Honor read-only or no-commit requests, normal hooks, and unrelated work. Publication, merge outside `--auto`, deployment, and shared-branch rewrites keep their existing gates. An explicit `--auto` is the merge authority for its tasks: a remembered or recalled hold (a memory, an earlier session's note) overrides it only when the user restates that hold in this conversation.

## Start

Before init, export `ORCH_SOURCE` as the agreed planning-parent reference, or an empty string for ad-hoc work. Run `scripts/orchestrate-init.sh <slug> --mode "<this invocation's flags>"`, where the slug names the overall work in at most 4 words. It checks `hc`, `$HC_TERMINAL_ID`, and `bd ping`; a beads connection failure is a shared blocker, so pause dispatch and report it. It reuses this terminal's open session epic (metadata `session=<terminal>`) or creates one with metadata `repo` (Git root, otherwise `pwd`), `session`, and `source` (the creation-time `ORCH_SOURCE` snapshot; reuse keeps existing metadata), then records `event=mode flags=… max=<N>` as an epic comment. It marks your own tab `[o] <title>`, the slug's words with hyphens as spaces (`[o] retro skills`), and sets the `orch-context` label. It prints `epic=<id>`, `export ORCH_EPIC=<id>`, and `export ORCH_MAX=<N>` (or `unset ORCH_MAX`); keep that epic ID and run both environment lines in every shell that starts or follows up workers. On failure, report its message and stop. Otherwise read `hc --skill` and `herdr-app --skill` once: `hc` owns command syntax, terminal and agent primitives, and lifecycle states; `herdr-app` owns only what the user sees. This skill adds only the orchestration layer.

Then read, in one pass, what your flags need:

- always: [delegation-contract.md](references/delegation-contract.md), [preflight.md](references/preflight.md), [worker-context.md](references/worker-context.md), and the Every kind, Hibernated or finished workers, and your worker kind's sections of [agent-quirks.md](references/agent-quirks.md)
- `--track`: [track.md](references/track.md)
- `--watch` or `--auto`: [supervise.md](references/supervise.md), [reap.md](references/reap.md), and the reviewer kind's section of agent-quirks.md ([supervise.md](references/supervise.md) step 2 picks the kind)
- `--auto`: also [auto-merge.md](references/auto-merge.md)
- `--handoff`: instead of all of the above, [handoff.md](references/handoff.md), [delegation-contract.md](references/delegation-contract.md), and your own kind's section of [agent-quirks.md](references/agent-quirks.md); the peer reads the rest itself

## Roles

- **Orchestrator:** per task, the spec and acceptance criteria; dispatch; answers to worker questions from the brief; when supervising, a pre-PR review by a reviewer worker ([supervise.md](references/supervise.md)) and acceptance at the destination; merge PRs under `--auto`. Built-in subagents (your harness's agent tool) serve these duties only: recon for context to write a spec, a check of a worker's result.
- **Worker:** executes its task end to end and owns the approach: plan, investigation, implementation, tests, repairs, authorized publication and replies. It has your capability, so the brief carries what done is and the decisions already agreed; everything else about the approach is the worker's.

Send failed acceptance or missing evidence back to the worker.

## Workflow

Per task:

1. **Spec it.** Write the brief per [delegation-contract.md](references/delegation-contract.md) from the agreed conversation, or from the task's existing ticket when it has one; under `--track`, a task without a ticket gets one from the spec ([track.md](references/track.md)). Resolve routine gaps by inspection. If a material decision is missing from the conversation, ask one precise question and stop before any side effect. **Done when** the task has a brief with acceptance criteria.
2. **Launch** through [preflight.md](references/preflight.md), every ready task at once, up to the `--max` slots. Under `--max`, `start-worker.sh` and `send-followup.sh` exit 4 with no side effect when no slot is free: record a `queued` event on its task bead with `needs=slot brief=<path>` (`needs=<task>,slot` with prerequisites; `slot` names no task), and when a watcher reports an agent idle or done, run the oldest slot wait first. A task with prerequisites is **queued**: record a `queued` event with `needs=<task>,<task>`; these comments are the task graph, and a changed graph appends a new event (the latest wins). Before every dispatch, re-read the task beads and their events, and launch a queued task once each prerequisite has a `merged` event (or, for work that does not merge, a `settled` event with `result=succeeded`), based on those merge commits and with their outputs added to its brief; without supervision, report it as queued. Merge a dependent's PR only when each prerequisite has a `settled` event with `result=succeeded` ([auto-merge.md](references/auto-merge.md#after-merge) defines settled for merged work); when a prerequisite's release fails, pause its running dependents. **Done when** the task is queued, or its worker is `working` and, under `--watch` or `--auto`, its `scripts/watch-agent.sh <name>` background task is running.
3. **Hand off or supervise** per the mode. The supervised lifecycle: watch → local review → publish → bot rounds → merge (`--auto`) → release → reap; [supervise.md](references/supervise.md) owns round caps, shared blockers, and lost watchers.

A task is **settled** when its worker is idle and its result is **accounted for**: succeeded, failed, blocked, or uncertain, each with evidence. Reap every settled task per [reap.md](references/reap.md): a task that succeeded with its PR merged and released gets full cleanup; every other task keeps its terminal and worktree. Without supervision, that happens when the user later reports the result.

## House rules

- **Pi by default** unless the user names another kind; a reviewer runs on a different model family from its worker ([supervise.md](references/supervise.md)).
- **Hands off the user's window:** workers are hidden `hc` terminals that show under you as sub-agents; never start a worker in your own terminal (`$HC_TERMINAL_ID`); create, rename, focus, or arrange spaces, tabs, and panes with `herdr-app` only when the user asks; the one exception is `orchestrate-init.sh` marking your own tab `[o] <titg>`.
- **Verify, don't trust:** use returned IDs, never predicted ones. An unconfirmed prompt submission or write is _uncertain_: inspect it before any retry.
- **Scripts:** run `scripts/*.sh` directly, never through a command string stored in a zsh variable. zsh does not word-split unquoted variables, so iterate over lists as arrays: `for a in "${list[@]}"`. Stop a watcher by its process ID; `pkill -f <pattern>` can match its own shell.

## Report

Before queuing or dispatching each task, create its local task bead with `bd create <title> --type task --actor "o-$HC_TERMINAL_ID" --parent "$ORCH_EPIC" --metadata '{"key":"<slug or ticket key>"}'`; reuse that child for later events. The key is the lower-case ticket key (`a2a-610`), or the slug without a ticket; agent names stay `w-<key>-<slug>` and `r-<key>-<slug>`. Ticketed tasks use the same key-based local beads until ticket import lands. Brief-file arguments to worker start and re-instruction stay unchanged.

Record task events with `scripts/event.sh <bead> <event> k=v…`: ticketed, dispatched, handed-off, queued, re-instructed, reviewed, ready, merged, settled, reaped, blocked, decided, note, adopted. Session events, including mode, go on the epic. The script validates the event name and first-line `event=<name> k=v…` format and writes a comment as actor `o-$HC_TERMINAL_ID`. Values may contain spaces; pass each entire `k=v` field as one shell argument, for example `"flags=--watch --max 2"` or `"q=Which target?"`. Consumers extract only known keys rather than treating every whitespace token as a field. `ready` is a PR whose gates closed (`pr-wait` exit 0), with its head SHA. `decided` carries `by=user|orchestrator q=<question> a=<answer>`. Evidence is the IDs, URLs, and SHAs `hc`, `git`, the tracker, or GitHub returned. With `ORCH_EPIC` exported, `start-worker.sh` and `send-followup.sh` look up the task bead by key under that epic and record `dispatched` and `re-instructed` best-effort on success only; record every other event yourself.

Bead status is coarse state: queued `open`, working `in_progress`, `blocked`, done `closed`. Write current PR facts only after claim, as metadata: `pr_url`, `head_sha`, `merged_sha`, `review_round`, `blocked_reason`; comments retain their history. Close a task bead only after verifying its merge SHA on the target branch; non-merge work closes at `settled result=succeeded`. A changed PR head reopens the task bead for re-review; earlier readiness does not cover the new head. Closure does not replace the prerequisite's `settled result=succeeded` release gate. A mid-session limit or mode change re-runs `orchestrate-init.sh` with the new flags, appending a mode comment on the same epic and printing new environment lines.

Build every report from beads, never from memory: `scripts/status.sh [epic] [--live]` reads the epic and its children (status, current metadata, latest event) into the task table; it defaults to this terminal's epic. After compaction or restart, run it with `--live` before acting. `scripts/compact-context.sh [epic]` likewise discovers the terminal's epic and prints the table with its latest `event=mode` comment; the herdr-app session integrations inject its output after compaction through the `orch-context` label. It is silent without an epic or after `--off`.

Write per-task content as one table, columns Task, Worker (terminal), State, Waiting for; PR URL and head SHA go in State. At each yield, list only tasks whose state changed since your last report plus tasks still running; the full table belongs to the every-task-settled report and status requests.

Report at each yield, when you are about to wait on workers or hand control back:

| When                                 | Report                                                                                                                                                                                                         |
| ------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| A dispatch wave is done and you wait | Per task: agent name, terminal, worktree, state; queued tasks with their prerequisites; the mode and what you wait for. Without supervision, this is the final report.                                             |
| A handoff is done                    | Peer tab and terminal, the tasks it took, and that the user continues with it there. Final for those tasks.                                                                                                   |
| A question needs the user's decision | The task, the one question, and its evidence.                                                                                                                                                                  |
| A shared blocker                     | Dispatch paused, the affected tasks, and what the user must do.                                                                                                                                                |
| A supervised task settles            | One line: the result with evidence (PR URL at head SHA, checks, ticket URL) or the exact blocker; dependents it launched.                                                                                      |
| Every task is settled                | The exact line `ALL WORK FINISHED`, then one line: task count, total time from the session epic's **first** `event=mode` comment to the latest event timestamp (computed with `date`, not from the latest invocation), counts of succeeded, failed, and blocked, PRs merged, worktrees kept, and `max <N> working` under `--max`. Then per task: target, agent name, terminal, worktree path, mode, and the result with evidence or the exact blocker and the decision needed; queued tasks with their prerequisites; what was cleaned up and the kept worktrees; the session epic ID. Then stop. |
| The user asks for status             | The current task-bead table, re-checked live in the same turn: `hc get` for each named worker, and `gh pr view`/`gh run view` for each named PR or release. State no worker or deploy state without that check.        |

Worker progress, questions you answer from the brief, retries, and context transitions go to bead event comments only.
