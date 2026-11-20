# Worker context

Applies in every mode, including re-instructions after a plain dispatch.

The standing contract is `orchestrated-worker`; the task definition and living notepad are the bead's fields. `worker-context.sh` resolves the newest updated `in_progress` bead assigned to `$BEADS_ACTOR`, falling back to `$ORCH_BEAD`. It prints the skill, `bd show` including notes, and the latest `event=re-instructed` comment with `agent=$BEADS_ACTOR` (worker and reviewer share the task bead); unavailable context exits 0 silently. The terminal's `orch-context=<absolute script path>` label lets the existing Pi and Claude integrations invoke it with no arguments after compaction, using the worker environment. Codex has no hook; automatic recovery is tracked separately by `wf-494`.

Work related to a dispatched task goes to that task's worker. Before each work instruction, including steering, retries, and re-instructions, choose the session context from its relevance, remaining capacity, and the next task's phase and constraints. Choose without asking unless the user specifies otherwise:

- **Keep** when the re-instruction builds directly on the prior work (re-review the same PR).
- **Compact** when the session is long but its context still matters.
- **Handoff** when the task enters a new phase and most of the old context is noise (implementation done, now `address-comments`).
- **New** when the old context would mislead; correct the bead's task definition and send its bootstrap pointer.

Keep active work in its session until a safe transition boundary. When changing context, use [agent-quirks.md](agent-quirks.md) for the worker's kind. Complete the transition before dispatch: for New or Handoff, verify the replacement session is active. Idle alone does not establish that the session changed.

Send every work instruction through `scripts/send-reinstruction.sh <name> <worktree> <bead> <text> [--last-reviewed <commit>] [--new-context]`. It stores the full instruction in an `event=re-instructed agent=<name>` comment and sends a pointer to the latest comment with that agent. After `/new`, `--new-context` adds the skill/prime/show bootstrap and, for Pi, the skill triggers; revival gets them from startup. Reviewer range validation and slot limits still apply.

Dispatch is complete when the intended session has received the instruction and started work or reported a blocker. Inspect uncertain delivery before retrying.
