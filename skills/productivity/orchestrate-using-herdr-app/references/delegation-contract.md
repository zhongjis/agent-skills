# Task definition

Write the task definition into its bead, not a brief file. The worker reads it with `bd show <bead>`. The fixed [orchestrated-worker standing contract](../../orchestrated-worker/SKILL.md) supplies scope, authority, resources, waits, bead permissions, notepad, reporting and the PR worker contract. Put task-specific decisions and every applicable user rule in the bead; the worker shares none of the conversation.

## Fields

Fill each section from the agreed conversation and the ticket, if any. Write "None" for an empty section. State the outcome and agreed decisions; the worker owns the approach.

- **description — What to build:** the end-to-end behavior from the user's perspective, not a layer-by-layer implementation list. Preserve the ticket body and identifier/URL when present; the ticket is authoritative for scope.
- **acceptance — Acceptance criteria:** observable criteria the worker can prove, named focused test files plus lint/type checks for touched packages, and `Broad run: <command>` or `Broad run: none: single service`. Include named changed screens and any visual target as acceptance criteria.
- **design — Decisions:** agreed contracts, interfaces, schema and testing seams, plus a `Migrations:` line, `additive` by default: the worker may add new migrations, named after the base's newest. Name every migration that drops, renames or rewrites data, or edits an existing migration; anything unnamed of that kind stays a tripwire. Include required skills using the harness convention; Pi startup copies literal `$skill:<name>` tokens from this field.
- **design — Unchanged behavior:** behavior left as on the base, named per area. State each item relative to the base ("as on main at each call site"), never as a fixed behavior carried over from another site or task. Write "None" only when the task may change any existing behavior it touches.
- **design — Context and inputs:** why this exists, rejected approaches and why, user preferences, conversation terms, current environment/known failures, linked spec/docs and prerequisite outputs. Inline anything the worker cannot open elsewhere.
- **design — Transitional code:** code this task rewires that a later task deletes, with agreed seams.
- **design — Out of scope:** explicit exclusions and protected work, each stated as work not to do, not as behavior to preserve.
- **design — Deliverables:** external results the mode/task grants. Under `--watch` or `--auto`, state whether a PR is required and that the standing contract's PR worker contract applies: local review before publication, publication only on release, no merge. For a ticket split into several PRs, every PR body except the last links the ticket with a non-closing reference (`Part of <KEY>` for Linear) and the last uses the tracker's closing reference (`Closes <KEY>`, or `Closes #N` for GitHub), so the tracker does not close the ticket at the first merge. `--track` creates and imports tickets, never ticket close-out comments; reports stay local. Write "None" for a plain local task. Narrow any standing authority to match user restrictions such as read-only, no commit or no push.
- **native dependencies — Blocked by:** prerequisite task beads; put artifact paths and outputs in design as inputs.
- **metadata after claim — worktree, branch, base:** assigned worktree path, branch and agreed base as `<ref>@<sha>`. Write these only after the pre-dispatch re-pull and claim ([import.md](import.md)).

Use `bd update <bead> --description "<body>" --acceptance "<criteria>" --design "<design>"` to store the fields. After claim, use `bd update <bead> --metadata '{"worktree":"<path>","branch":"<branch>","base":"<base>"}'`. Keep dependency edits native to bd rather than encoding dependencies only in prose.

## Batch targets

A batch ticket's bead holds the shared task definition. Create one child **batch target bead** per target with `key=<slug>-<target>` metadata; copy the filled fields with the target, its inputs and per-target overrides. Dispatch and claim target beads, never the batch parent. Close the batch ticket bead only when every target closes. Each target gets its own worktree and worker.

## Rules

- **Scope:** use file boundaries only for agreed scope or concurrent work. Workers own the approach. Coordinate discovered overlap; ask the user only for decisions beyond existing authority.
- **Verification scope:** first name the checks the repo requires for the touched paths (their `AGENTS.md` Verification sections, then its contributor guide); otherwise name focused tests and touched packages' lint/type checks. CI is the broad gate. Require a broad local run only for cross-service changes, a shared contract, or an explicit user request; name the command and require it once before publication, run as a background task read to its own exit so no tool time limit cancels it. Never hand that choice to a generic contributor guide. If a repo requires a broader local gate, state that focused verification replaces it for local handoff while CI retains it. The standing contract requires one command at a time and no concurrent rebuild.
- **QA:** name changed screens. The worker's mode chooses QA depth. For a visual target, require real-browser before/after screenshots, with the after shots taken at the reported head after the last production change, an index mapping targets to screenshots that names that head, and PR attachments through `before-and-after` when a PR is required. Evidence files stay outside the worktree; paths go in report comments.
- **Wave audit:** before dispatch, read every task definition side by side against the spec: no item belongs to two tasks, criteria match the spec, and every "none remains" criterion names its search command and exceptions. Correct mismatches first.
- **Re-instructions:** send every later work message through `send-reinstruction.sh`. Its `event=re-instructed agent=<name>` comment holds the full instruction, including review-bead or PR-thread references, blocking labels, user decisions, or updated rules. The script sends a pointer to that agent's latest comment; `--new-context` after `/new` and revival repeat the standing-contract/bead bootstrap. End the instruction: "Report in an event=report comment, then end your turn; never `hc send` to the orchestrator."
- **Session rules:** add a new worker-facing user rule to Context in every later task definition and send it as a re-instruction to every running worker.
- **Link or inline:** link openable sources; inline conversation-only decisions or a snippet that conveys a schema/state machine more precisely than prose.
- **Redact:** keep secrets and sensitive data out of every field and comment.
