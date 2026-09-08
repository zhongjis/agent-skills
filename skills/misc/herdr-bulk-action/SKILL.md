---
name: herdr-bulk-action
description: "Plan and run a confirmed batch of repeatable tasks with one Herdr worker per item."
disable-model-invocation: true
---

# Herdr bulk action

Orchestrate a task over an item list using shared instructions, optional referenced skills, and explicit user overrides. Referenced skills define the task's behavior, including posting; user overrides take precedence over that behavior. This skill owns coordination, not a review-only or draft-only policy.

## 1. Confirm intention and plan

Before doing the task or creating workers, establish what the user intends and propose a fan-out plan. Ask only about unresolved choices; preliminary inspection is not a required phase. If discovery is needed to resolve a filter or ambiguous targets, agree its scope first.

The plan covers:
- The repeatable task, exact items (or bounded discovery rule), target identity such as service/project/repository and acting account, and shared instructions or referenced skills with overrides.
- Task boundaries, allowed side effects, expected per-item outputs, and evidence that will prove completion.
- Worker kind, proposed concurrency, isolated panes, and any required working directories, workspaces or worktrees. Propose extra topology only when the task needs it.
- Dependencies or overlapping writes and their ordering; lifecycle limits, including any requested watching, reruns or cleanup.

For example, “review these Jira issues” might mean review issue text or review linked code. Resolve that distinction rather than silently choosing PR reviews. For a resolved task: “Summarize DOC-12 and DOC-13 using the supplied rubric; return one summary per issue, make no remote edits; two pi workers in sibling panes, no worktrees; one pass, retain panes. Confirm?”

**Done when:** the user explicitly confirms the plan. Supplied details need not be asked again, but a proposed plan is not permission to dispatch. Material scope changes require an updated confirmation.

## 2. Prepare Herdr and worker packets

After confirmation, read `herdr --skill` and verify `test "${HERDR_ENV:-}" = 1` before Herdr control. If the check fails, report the environment blocker and stop. The installed `herdr --help` and relevant command groups own CLI syntax and runtime approval handling; avoid probing mutating subcommands for help.

Keep the orchestrator pane (`$HERDR_PANE_ID`) and the user's focus intact. Give each item its own worker in an isolated pane; use workspaces/worktrees only as needed and covered by the confirmed plan. Use unique names matching `[a-z][a-z0-9_-]{0,31}` (for example `bulk-a7-01`), and use actual returned IDs rather than guessed identifiers. Track item → worker → pane and any workspace/path.

Give each worker its exact item and target, shared task instructions, referenced skills to read, explicit overrides, allowed side effects, dependencies/inputs, and required result and completion evidence. For example, “Use code-review and follow its posting workflow” preserves that workflow; “Use code-review, draft only; do not post” overrides it. The confirmed plan governs posting without a second blanket posting approval from this skill. If Herdr reports an approval/question UI, inspect it and ask the user before answering, as its control instructions require.

**Done when:** every ready item has a bounded worker packet and the agreed isolation is available; dependent items remain queued until their prerequisites are verified.

## 3. Dispatch and collect

Use nonblocking agent prompts (omit `--wait`) so independent items run concurrently, up to the confirmed count. Dispatch one worker per item, release dependent items in the agreed order, and monitor this run until each item has a result or a recorded failure/blocker.

- Continue independent items after an isolated item failure; hold dependents whose prerequisite failed.
- For a shared blocker such as expired authentication, pause new dispatch and affected work, report the blocker, and obtain the needed resolution before resuming. Unaffected active items may finish.
- Inspect uncertain write outcomes at the destination before any retry, including a timed-out post or stalled prompt that may already have triggered work. If the outcome cannot be established, record it as uncertain and hold affected work rather than risk duplicate writes. Retry only within the confirmed plan.
- Treat Herdr `idle`/`done` as lifecycle signals, not proof of success. Read the worker output and check the agreed artifact or destination evidence; classify missing proof explicitly rather than declaring completion.

**Done when:** every item is accounted for as succeeded, failed, blocked or uncertain, with result/failure details and available completion evidence. A shared blocker may end this run with pending items recorded as blocked rather than left silently queued.

## 4. Report and stop

Return a compact per-item list: target, status, result or failure, evidence (such as artifact path, test result or verified remote URL), and any unresolved dependency or write uncertainty. Include worker/pane handles for work left available and the decision needed for blocked items.

End after this bounded run. Watch for future changes, rerun items or clean up only when included in the confirmed plan and within its limits; otherwise leave the workers and workspaces available. For confirmed cleanup, preserve the orchestrator and unrelated resources, and report what was removed or retained.

**Done when:** the report accounts for the full item list and any agreed lifecycle actions are complete or explicitly blocked.
