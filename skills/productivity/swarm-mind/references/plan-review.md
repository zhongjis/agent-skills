# Plan review

Applies [SKILL.md](../SKILL.md) to a spec, a ticket breakdown, or any plan before it is published or dispatched.

- **Self-contained plan:** before review, the plan states its agreed decisions, out-of-scope items, constraints and acceptance criteria, since the reviewer sees nothing else.
- **Target:** the plan file at a named version. **Location:** the plan section for every finding.
- **Gaps to look for**, each a blocker (a conflict with the authority); everything else is a note:
  - contradictions, within the plan or with agreed decisions
  - a requirement or user story nothing covers
  - a claim about the codebase the repository contradicts (the reviewer checks the repository)
  - a missing constraint (scale, compatibility, security, migration)
  - scope creep, as defined in [SKILL.md](../SKILL.md) Judge
  - for tickets: a wrong blocking edge, a horizontal slice, or a ticket too large for one context window
- **Acceptance criteria an agent can check** (a criterion that fails this is a gap): each one runnable without a human, free of placeholders, and covering the failure case as well as the happy path.
- **Judged as written:** another approach, style or performance (unless broken) is a note.
- **Verdict:** `approved`, `changes_requested`, or `inconclusive` (the reviewer could not judge; it names what was missing). Approval with only notes left is approval.
- **Version:** an approval covers the version reviewed; any later edit needs a review of that edit before handoff.
- **Cap:** at most **2** rounds. When the plan changes after the last allowed round, tell the user the change is unreviewed and ask whether they want another round.
