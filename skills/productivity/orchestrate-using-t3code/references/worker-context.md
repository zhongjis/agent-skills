# Worker context

Applies in every mode, including follow-ups after a plain dispatch.

Work related to a dispatched task goes to that task's worker. Before each work instruction, including steering, retries, and follow-ups, choose the session context from its relevance, remaining capacity, and the next task's phase and constraints. Choose without asking unless the user specifies otherwise:

- **Keep** when the follow-up builds directly on the prior work (re-review the same PR): `t3_thread_send` to the worker's thread.
- **Compact** when the session is long but its context still matters: per the worker kind in [agent-quirks.md](agent-quirks.md); a kind without a compact command uses Handoff.
- **Handoff** when the task enters a new phase and most of the old context is noise (implementation done, now `address-comments`):
  1. Ask the worker to write a handoff document for the follow-up focus to `$TMPDIR` and print its path.
  2. Take only the path from the worker's output; do not read the document yourself.
  3. Stop the worker's thread with `t3_thread_interrupt {threadId, stop: true}`.
  4. Launch the replacement with `t3_thread_launch`, `workspaceStrategy: {type: "existing_worktree", worktreePath}` on the same worktree, the same title and kind, and a message telling it to read that path and continue with the follow-up request.
- **New** when the old context would mislead: stop the thread and launch the replacement as in Handoff, with a corrected full brief as its message.

Keep active work in its session until a safe transition boundary. Complete the transition before dispatch: for New or Handoff, verify the replacement thread's run is in progress, then log its thread ID and link as the task's worker. An ended run alone does not establish that the session changed.

Dispatch is complete when the intended thread has received the instruction and started work or reported a blocker. Inspect uncertain delivery before retrying.
