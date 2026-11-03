# Worker context

Applies in every mode, including follow-ups after a plain dispatch.

Work related to a dispatched task goes to that task's worker. Before each work instruction, including steering, retries, and follow-ups, choose the session context from its relevance, remaining capacity, and the next task's phase and constraints. Choose without asking unless the user specifies otherwise:

- **Keep** when the follow-up builds directly on the prior work (re-review the same PR).
- **Compact** when the session is long but its context still matters.
- **Handoff** when the task enters a new phase and most of the old context is noise (implementation done, now `address-comments`).
- **New** when the old context would mislead; send a corrected full brief.

Keep active work in its session until a safe transition boundary. When changing context, use [agent-quirks.md](agent-quirks.md) for the worker's kind. Complete the transition before dispatch: for New or Handoff, verify the replacement session is active. Idle alone does not establish that the session changed.

Dispatch is complete when the intended session has received the instruction and started work or reported a blocker. Inspect uncertain delivery before retrying.
