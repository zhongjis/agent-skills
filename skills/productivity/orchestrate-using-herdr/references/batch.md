# Batch

One repeatable task over a list of items, one worker per item. Items share one instruction (plus referenced skills and per-item overrides); there is no per-item spec.

## 1. Confirm the plan

Before any task work or dispatch, propose the fan-out plan and ask only about unresolved choices:

- the task, exact items (or a bounded discovery rule), target identity (service, repository, acting account), shared instruction, referenced skills, and user overrides;
- allowed side effects, per-item output, and the evidence that proves completion;
- worker kind, concurrency, isolation (pane, worktree, or workspace only as the task needs), dependencies and ordering, and lifecycle (one pass, reruns, cleanup).

Referenced skills define task behavior, including posting; user overrides win ("use `code-review`, draft only" overrides its posting step). Resolve real ambiguity rather than guessing: "review these tickets" may mean the ticket text or the linked code.

**Done when** the user explicitly confirms the plan. A proposed plan is not permission to dispatch; a material scope change needs a new confirmation.

## 2. Dispatch

Track item → agent → pane → worktree. Give each worker its exact item and target, the shared instruction, skills to read, overrides, allowed side effects, inputs from dependencies, and required evidence. Dispatch with bare non-blocking prompts so independent items run concurrently up to the confirmed count; hold dependents until their prerequisites are verified.

**Done when** every ready item is dispatched and accepted, and dependents are queued.

## 3. Supervise (when the mode asks)

Follow Supervision in `SKILL.md`. Hold dependents whose prerequisite failed. Rerun or clean up only within the confirmed plan; on confirmed cleanup, preserve your pane and unrelated resources and report what was removed.

## Example: PR review batch

Task: `$skill:code-review <pr-url>` per PR, one worktree per PR at its head, agents named `review-<n>`.

- Check out the PR head per [herdr-pitfalls.md](herdr-pitfalls.md); reviewing a stale head is the worst silent failure here.
- `code-review` ends on a verdict and asks before writing to GitHub. A settled agent with no posted review gets one instruction: post one atomic PR review whose event matches its verdict, with inline comments at cited lines. GitHub rejects `APPROVE`/`REQUEST_CHANGES` on a PR authored by the posting account; use `COMMENT` there.
- Verify on GitHub: a review by your `gh api user` login, not the agent's self-report.
- Prune: remove worktrees whose posted verdict is `APPROVED`.
- Re-review: a kept PR whose newest commit `committedDate` is later than your last review's `submittedAt` gets its worktree reset to the new head and the **same** agent re-prompted, so `code-review` can check whether earlier findings were addressed.
