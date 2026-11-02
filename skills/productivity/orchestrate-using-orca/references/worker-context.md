# Worker context

Applies in every mode, including follow-ups after a plain dispatch.

Work related to a dispatched task goes to that task's worker. Before each work instruction, including steering, retries, and follow-ups, choose the session context from its relevance, remaining capacity, and the next task's phase and constraints. Choose without asking unless the user specifies otherwise:

- **Keep** when the follow-up builds directly on the prior work (re-review the same PR).
- **Compact** when the session is long but its context still matters.
- **Carry-over** when the task enters a new phase and most of the old context is noise (implementation done, now `address-comments`). This is Pi's `/handoff` command, which summarizes into a new session; it is unrelated to Orca's handoff (ownership transfer).
- **New** when the old context would mislead; send a corrected full brief.

Keep active work in its session until a safe transition boundary. When changing context, use [agent-quirks.md](agent-quirks.md) for the worker's kind. Complete the transition before dispatch: for New or Carry-over, verify the replacement session is active. Idle alone does not establish that the session changed.

**Delivery.** Without a Run (plain dispatch), deliver the instruction to the worker's terminal: `orca terminal send --terminal <handle> --text "<text>" --enter`. Under `--watch`/`--auto`, a settled worker holds no live Dispatch, so a follow-up is a new Task started in the same terminal, which injects the worker preamble Orca needs for `worker_done`: `orca orchestration worker-show --dispatch <id> --json` for the handle, then `orca orchestration worker-start --task <task_id> --terminal <handle> --worktree <selector> --json` (create the Task with `task-create --spec`). Decide this before acknowledging the settled worker's `worker_done`. Apply Compact or New to the session first. A carry-over preloads text in the editor that a new Dispatch cannot adopt, so under supervision use New and put the needed summary in the brief. While a Dispatch is active, steer it with `orca orchestration send --to dispatch:<id> --subject <subject> --body <body>`.

Dispatch is complete when the intended session has received the instruction and started work or reported a blocker. Inspect uncertain delivery before retrying.
