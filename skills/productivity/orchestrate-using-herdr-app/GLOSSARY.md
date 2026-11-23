# Beads-backed orchestration

Local orchestration connects agreed planning work to workers, reviews, and delivery. This vocabulary distinguishes the work record, its owners, and its history.

## Language

**Ticket**:
A planning item in an external planning source (remote tracker, Lark document, or spec) that is authoritative for the work it describes.
_Avoid_: Bead when referring to the planning source.

**Bead**:
A local work record with its own identity, definition, ownership, state, and history.
_Avoid_: Ticket when referring to the local record.

**Task bead**:
The bead defining one agreed unit of delivery, whether imported from a ticket or defined locally.
_Avoid_: Bare task, brief.

**Batch target bead**:
A local child of a batch ticket's task bead, defining the work for one target in that batch.
_Avoid_: Duplicate ticket, batch task.

**Session epic**:
The root bead grouping the task beads belonging to one orchestrator session.
_Avoid_: Run, remote planning parent.

**Orchestrator session**:
One orchestrator's period of ownership from entering orchestration mode to turning it off.
_Avoid_: Run, invocation when referring to the whole period.

**Invocation**:
One request to the orchestration skill, with its agreed work and flags, within or starting an orchestrator session.
_Avoid_: Run, session when referring to a single request.

**Review bead**:
A child of a task bead defining one local review round and holding its findings and report.
_Avoid_: Finding bead, review file.

**Follow-up bead**:
A deferred local record of discovered out-of-scope work, distinct from repairs needed for the current outcome.
_Avoid_: Repair bead, re-instruction.

**Handoff bead**:
A record transferring a side issue, its decisions, and its context to a peer session.
_Avoid_: Handoff file, task bead when referring to the transfer record.

**Worker**:
An agent dispatched to deliver the outcome of an assigned bead.
_Avoid_: Orchestrator when referring to a delivery agent.

**Reviewer**:
A worker assigned a review bead to assess a defined change range.
_Avoid_: Repair worker when referring to the reviewing role.

**Actor**:
The identity attributed to an agent's bead operations and ownership.
_Avoid_: User when referring to an agent identity.

**Claim**:
The exclusive assignment of an available bead to an actor for work in progress.
_Avoid_: Adoption when referring to ordinary assignment.

**Notepad**:
The single living Plan, Now, and Findings document of an owned bead.
_Avoid_: Diary, event log, private scratchpad.

**Event**:
An attributed milestone in a bead's append-only comment history.
_Avoid_: Notepad entry, current state.

**Report**:
A worker's handoff event containing its result or blocker and supporting evidence.
_Avoid_: Screen scrape, notification.

**Brief**:
The orchestrator's message to the user at a yield, led by what needs the user.
_Avoid_: Report, status table.

**Import**:
The initial incorporation of agreed planning work into its local bead, reusing that bead when it already exists.
_Avoid_: Push, bidirectional sync.

**Re-pull**:
The refresh of an imported ticket's bead from its planning source immediately before first dispatch.
_Avoid_: Sync, re-instruction.

**Re-instruction**:
A later direction to an existing worker, including repairs, review findings, and context after a restart.
_Avoid_: Follow-up, new task.

**Settled**:
The final delivery outcome confirmed by the orchestrator, including any required release result.
_Avoid_: Idle, committed, merged when used alone as proof of settlement.

**Task definition**:
The bead's agreed outcome, acceptance criteria, decisions, context, boundaries, prerequisites, and deliverables.
_Avoid_: Brief, standing contract.

**Standing contract**:
The fixed rules shared by all dispatched workers and reviewers, independent of their assigned outcomes.
_Avoid_: Task definition, per-task brief.
