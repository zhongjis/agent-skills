# Spec: orchestrate-using-t3code

## Problem Statement

The user orchestrates agreed tasks through `orchestrate-using-herdr`: an orchestrator agent writes briefs, starts one worker agent per task in its own worktree, supervises it, and lands the result. When the user works inside T3 Code, that workflow does not apply. Herdr drives agent CLIs through terminal panes, while T3 Code hosts every provider behind one thread interface and injects its own orchestration rules. The user wants the same workflow, adapted to T3 Code's threads and tools, without new behavior the Herdr skill does not have.

## Solution

A new user-invoked skill, `orchestrate-using-t3code`, created as a full copy of `orchestrate-using-herdr` and adapted in place. Invocation, flags, sticky mode, authority, roles, the per-task workflow, the brief template, ticket tracking, auto-merge gates, and the log-built reports stay as in the Herdr skill. Worker lifecycle mechanics move from Herdr panes and agent CLIs to T3 Code top-level threads, T3 MCP tools, and the `t3` CLI. The orchestrator thread is marked with an `[o]` title prefix and pinned.

## User Stories

1. As a T3 Code user, I want to invoke `/orchestrate-using-t3code` with the same flags as the Herdr skill, so that I do not learn a second workflow.
2. As a T3 Code user, I want the tasks agreed earlier in the conversation dispatched without re-planning, so that orchestration starts from our agreement.
3. As a T3 Code user, I want the orchestrator thread titled `[o] <slug>` and pinned, so that I can tell it apart from worker threads in the sidebar.
4. As a T3 Code user, I want an existing `[o]` prefix preserved without doubling, so that re-invocation keeps one clean title.
5. As a T3 Code user, I want each worker to be a visible top-level thread with a friendly title, so that I can open and watch it like a Herdr pane.
6. As a T3 Code user, I want each worker in its own git worktree on its own branch, so that parallel tasks do not collide.
7. As a T3 Code user, I want dependent tasks to start from their prerequisite's branch, so that stacked work builds on verified output.
8. As a T3 Code user, I want Pi as the default worker, so that behavior matches the Herdr skill.
9. As a T3 Code user, I want to name another provider or model for a worker, so that I can mix Pi, Claude Code, or Codex.
10. As a T3 Code user, I want workers to inherit the orchestrator's runtime mode, so that no worker runs with broader permissions than I granted.
11. As a T3 Code user, I want worker approval prompts reported to me with the thread link, so that I know where to approve.
12. As a T3 Code user, I want worker questions answered from the brief by the orchestrator, so that workers do not stall on settled decisions.
13. As a T3 Code user, I want the orchestrator to use only returned thread IDs and worktree paths, so that it never acts on predicted state.
14. As a T3 Code user, I want an uncertain launch inspected before any retry, and retries to reuse the same request key, so that no duplicate worker is created.
15. As a T3 Code user, I want the brief to state that workers may use subagents, so that T3's child defaults do not weaken workers.
16. As a T3 Code user, I want each worker to use its own agent-browser namespace, so that cleanup closes only that worker's browsers.
17. As a T3 Code user running `--watch`, I want the orchestrator to wait for each worker to settle and then check the destination, so that a finished status is never mistaken for success.
18. As a T3 Code user with a Claude Code orchestrator, I want background thread watchers, so that each worker notifies independently.
19. As a T3 Code user with a Pi orchestrator, I want a foreground wait fallback, so that supervision works without background tasks.
20. As a T3 Code user, I want PR checks, reviews, comments, and conflicts to wake the orchestrator, so that it reacts without polling scripts.
21. As a T3 Code user, I want each worker's PR linked to its thread, so that I see PR status in the sidebar and the thread settles on merge.
22. As a T3 Code user, I want follow-ups to the same task sent to the same worker thread, so that context carries over.
23. As a T3 Code user, I want long Pi sessions compacted with `/compact`, so that context stays useful.
24. As a T3 Code user, I want a handoff or a fresh session to start a new thread on the same worktree, so that a new phase begins without noise.
25. As a T3 Code user, I want finished workers reaped, their threads stopped, and their worktrees removed, so that no daemons or checkouts leak.
26. As a T3 Code user running `--track`, I want each task filed in the tracker before dispatch, so that work is traceable.
27. As a T3 Code user running `--auto`, I want PRs merged only after every gate closes, so that branch protection and approvals are never bypassed.
28. As a T3 Code user, I want every event logged to a per-session log outside the repository, so that reports come from evidence.
29. As a T3 Code user, I want `--off` to end orchestrator mode, so that later requests return to normal handling.
30. As a skill maintainer, I want the files shared with the Herdr skill named in the owning AGENTS.md, so that a change to one prompts a check of the other.

## Implementation Decisions

- **Layout:** full self-contained copy of the Herdr skill tree in the productivity category, adapted in place. A shared orchestration-common skill is deferred.
- **Unchanged contracts:** invocation and flags, sticky mode, authority, roles, workflow, settlement and reaping triggers, the brief template, ticket tracking, auto-merge worker contract and gates, report table, and log format.
- **Interface:** T3 MCP tools for every orchestrator action; the `t3` CLI only inside scripts, because scripts cannot call MCP tools. `t3 thread start` lacks existing-worktree binding, `startFromOrigin`, runtime modes, stop, question answering, rename, and pin.
- **Worker:** one top-level thread per task via `t3_thread_launch` with a worktree workspace strategy (base ref and branch), the friendly label as title, Pi by default (model selection omitted when the orchestrator runs on Pi, so the worker inherits its model), a stable client request ID, and the brief plus `ulw` as the message. Dependent tasks use the parent branch as base ref with `startFromOrigin` off. T3's guidance to launch top-level threads only on user request is satisfied by the skill invocation.
- **Naming:** Herdr's agent-name rules stay; the name keys the log task, the browser namespace, and the branch suffix. The thread ID replaces the pane ID.
- **Verify, don't trust:** read the worker worktree path from T3's worktree listing for the worker thread and confirm its HEAD with git.
- **Runtime mode:** inherited; the skill never sets it unless the user asks. Approvals reach only the human; the orchestrator reports a blocked worker with its thread link. Questions are answered through T3's pending-request tool.
- **Waiting:** a thread watcher script loops on `t3 thread show --json` until the latest run settles, re-checks after 30 seconds, and runs as a background task where the harness supports it; otherwise the orchestrator waits in the foreground with `t3_thread_wait`.
- **PRs:** `watch_pull_request` on the orchestrator thread replaces the CI watcher script; `link_pull_request` attaches each worker PR to its worker thread. Stack order stays with `land-change`; T3's PR list is not used.
- **Worker context:** Keep sends to the worker thread; Compact sends Pi `/compact` (Claude relies on T3 idle compaction, else Handoff); Handoff has the worker write a handoff document, stops its thread, and launches a new thread bound to the existing worktree that reads it; New does the same with the full brief.
- **Reaping:** the thread is stopped through T3, the reap script runs on the worktree path, the worktree is removed with git, git's worktree list confirms removal, and a merged task's local branch is deleted.
- **Startup:** the orchestrator reads its own thread ID from T3's thread list; the init script checks for a T3 MCP session and the `t3` CLI and prints a log path keyed by that thread ID; the orchestrator then prefixes its thread title with `[o]` without doubling, pins the thread, and calls `orchestrator_capabilities` once.
- **Agent quirks:** terminal workarounds are dropped; the Pi section keeps `ulw`, `$skill:`, and `/compact`.
- **Scripts:** keep the log, pinned-push, and reap scripts; adapt init; add the thread watcher; drop worker-start, agent watcher, and CI watcher.

## Testing Decisions

- Good tests observe external behavior: the orchestrator's chosen actions and reports for a scenario, not wording.
- `evals/evals.json` is ported: each Herdr scenario keeps its intent with T3 mechanics; terminal-quirk scenarios are dropped and the pane-label scenario becomes a thread-title scenario.
- No `tests/check.sh` for this skill. Scripts get syntax checks during development.
- Prior art: the Herdr and Orca orchestration skills' `evals/evals.json`.

## Out of Scope

- An orchestration-common skill shared by Herdr, Orca, and T3 variants.
- `delegate_task` child workers.
- T3's PR stack listing, PR guides, scheduled tasks, devices, and remote environments.
- Changes to `orchestrate-using-herdr`.

## Further Notes

- Confirmed on a live T3 run (t3 v0.1.6): `t3 thread show --json` exposes the thread status, worktree path, branch, and pending request count; T3's worktree listing returns the worker worktree path; a manual title rename survives later runs; `$skill:` and `ulw` work under T3's Pi runtime. T3's thread list returns the caller's thread ID.
- Sources: T3 Code orchestration instructions and the Orchestrator MCP server doc in `pingdotgg/t3code`.
