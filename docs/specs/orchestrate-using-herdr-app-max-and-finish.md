# Spec: orchestrate-using-herdr-app `--max` and finish banner

## Problem Statement

The user runs several `orchestrate-using-herdr-app` workers on one host. When four workers run test suites at once, the CPU sits at 99-100% and tests fail on timeouts. The skill has no way to cap how many agents work at the same time; a "limit" exists only as conversation text with no enforcement.

When a supervised orchestration ends, its final report has no fixed marker and no total time, so the user cannot tell at a glance that all work finished or how long it took.

## Solution

- A `--max <N>` flag caps how many of this orchestrator's agents (workers and reviewers) are `working` at the same time. It combines with `--watch` or `--auto`. The orchestrator holds extra dispatches and follow-ups as slot waits; `start-worker.sh` and `send-followup.sh` refuse a start that would exceed the cap.
- The every-task-settled report opens with the exact line `ALL WORK FINISHED` and a one-line summary that includes total time.

## User Stories

1. As a user, I want `--max 2` to keep at most two of my orchestrator's agents working at once, so that test suites do not starve each other of CPU.
2. As a user, I want idle workers (waiting on review, PR bots, merge, or release) to free their slot, so that the cap limits CPU load, not open tasks.
3. As a user, I want a reviewer to count like a worker, so that a reviewer running tests is capped too.
4. As a user, I want agents outside this orchestrator ignored, so that the cap stays within this skill's scope.
5. As a user, I want held dispatches and follow-ups to run oldest first when a slot frees, so that no task starves.
6. As a user, I want the cap enforced by the scripts as well as the orchestrator's rule, so that one missed check cannot overshoot it.
7. As a user, I want the cap to survive a context compaction, so that a recovered orchestrator keeps it.
8. As a user, I want `--max` without `--watch` or `--auto` refused before any side effect, so that I am not left with tasks no one will launch.
9. As a user, I want a supervised run to end with `ALL WORK FINISHED`, total time, and result counts, so that I see completion at a glance.

## Implementation Decisions

- **Flag:** `/orchestrate-using-herdr-app [--handoff] [--watch | --auto] [--max <N>] [--track] [tasks…]`. N is a positive integer. Without `--max`, behavior is unchanged: every ready task launches at once.
- **Slot:** an agent occupies a slot while its `hc` status is `working`. Count = live terminals labelled `orch=$HC_TERMINAL_ID`, named `w-*` or `r-*`, with status `working`. `blocked`, `idle`, `done`, and finished terminals hold no slot. Workers end their turn at every handoff point and the orchestrator runs `pr-wait` (delegation-contract Waits, supervise.md), so `working` tracks local work.
- **Scope label:** `start-worker.sh` starts each terminal with `hc run --label orch=$HC_TERMINAL_ID`, so it counts from launch; revival through `send-followup.sh` goes through `start-worker.sh`, so revived workers keep it. Query: `hc ls --json --label orch=$HC_TERMINAL_ID`.
- **Init:** `orchestrate-init.sh` reads `--max <N>` from `--mode`, refuses it without `--watch` or `--auto` (or with a non-positive N) before logging, and prints `export ORCH_MAX=<N>` beside `export ORCH_LOG=…`, or `unset ORCH_MAX` without `--max`, since a flag applies only to its invocation. The flags stay in the `mode` row, so `compact-context.sh` already restores them after compaction.
- **Script guard:** when `ORCH_MAX` is set, `start-worker.sh` (new start or reviewer) and `send-followup.sh` (before any side effect, including the reviewer scope it writes into the brief) count slots first; at or above N they print the working agents and exit 4. A follow-up to a target that is already `working` takes no new slot. One small shared script, `scripts/slot-free.sh`, holds the count for both callers.
- **Turn confirmation:** `send-followup.sh` waits up to 60 seconds until the target's turn advances or its status is `working` (as `start-worker.sh` does), so the next guard check counts it; otherwise it exits 2.
- **Orchestrator rule (SKILL.md Workflow step 2, single source):** before every `start-worker.sh` or `send-followup.sh` call, with no free slot, log the task `queued` with evidence `needs=slot brief=<path>` (combined with prerequisites as `needs=<task>,slot`). When a watcher reports a slot-holder idle or done, run the oldest slot wait first. Exit 4 from a script means the same: queue it, do not retry blindly. A mid-session limit change re-runs `orchestrate-init.sh` with the new flags.
- **`--handoff`:** unchanged; `--max` goes to the peer with the other flags.
- **Finish banner:** the Report table's "Every task is settled" row starts with:

  ```text
  ALL WORK FINISHED
  <n> tasks in <elapsed> (since <start ts>): <s> succeeded, <f> failed, <b> blocked · <p> PRs merged · <k> worktrees kept · max <N> working
  ```

  `<start ts>` is the latest `orchestrator mode` row's `ts`; `<elapsed>` is the last row's `ts` minus it, computed with `date`, not by hand. `max <N> working` appears only under `--max`. The existing per-task table, cleanup, kept worktrees, and log path follow unchanged. The banner appears only on that report, never on a dispatch-wave, handoff, question, or blocker report.

## Testing Decisions

- `tests/check.sh` (fake `hc`, existing style) covers: init refuses `--max` without `--watch`/`--auto` and prints `ORCH_MAX` with them; `start-worker.sh` exits 4 at the cap and starts below it; only `orch=`-labelled `w-`/`r-` working terminals count; `send-followup.sh` exits 4 for an idle target at the cap and sends to an already-working target; the new `orch=` label is applied at launch; a refused start or follow-up leaves no call and no brief change; a sent follow-up that starts no turn exits 2.
- `evals/evals.json` gains one scenario: `--watch --max 2` with four ready tasks, one worker going idle for local review; expectations cover two dispatches, two `needs=slot` rows, the oldest released first, and the reviewer counted. One expectation on an existing every-task-settled scenario checks the `ALL WORK FINISHED` banner with elapsed time.
- Good tests observe external behavior: exit codes, labels, log rows, and chosen actions, not wording.

## Out of Scope

- A host-wide cap across orchestrators or other `hc` terminals.
- Throttling a single agent's own test parallelism (jest workers, pytest-xdist, `make -j`); a brief's Scope field can carry that per project.
- Load-average or CPU sampling.
- Any change to `orchestrate-using-t3code`.

## Further Notes

- `hc ls --json` entries carry `name` and a flat `status`, but not `parent`, so the scope uses the `orch=` label rather than parentage.
- Under a restart that gives the orchestrator a new `$HC_TERMINAL_ID`, earlier workers keep the old label and stop counting toward the cap; a revival through `send-followup.sh` relabels a finished worker.
