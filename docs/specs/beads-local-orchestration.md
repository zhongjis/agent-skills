# Spec: beads-backed local orchestration

Source: wayfinder map "Beads-backed local orchestration setup" (local beads, `wf-bel`), 13 resolved decision tickets. Diagrams: `docs/diagrams/beads-*.html` (current flow, proposal, orchestration sequence, demo run, vocabulary).

## Problem Statement

The user plans work with wayfinder or grill-me, to-spec and to-tickets, then runs `orchestrate-using-herdr-app` to deliver it through herdr-core workers. Orchestration state is scattered across five stores that do not talk to each other: the remote tracker, the orchestrator's TSV log, brief and handoff files under the briefs folder, Pi's private ulw notepad, and Pi's Task tool. The orchestrator cannot read a worker's notes, so it scrapes the worker's screen. The task graph lives twice, as tracker blocking links and as hand-written `queued needs=` log rows. Every brief re-types the same standing rules by hand, and they drift: real briefs miss whole sections or carry outdated contract text. A handoff is a one-shot file that nothing tracks afterwards. Ticket close-out comments push agent output to the remote, which the user wants only for human viewing.

## Solution

One local beads database on each machine holds all orchestration state and agent notes, and is never pushed anywhere. Planning skills keep publishing tickets and specs to the remote tracker unchanged. When orchestration starts, the orchestrator imports the agreed tickets pull-only, one bead per ticket, under one epic per orchestrator session. A task bead is the worker's task definition; a new `orchestrated-worker` skill is the one fixed standing contract; `bd prime` teaches any agent how to use beads. Workers keep a living notepad in their bead and report milestones as comments, so the orchestrator, a reviewer, a peer and the user all read the same record. Review rounds, discovered out-of-scope work and handoffs are beads too. The PR description is the only result written to the remote; anything else reaches the remote only on the user's explicit yes.

## User Stories

1. As a user, I want my planning skills to keep publishing to the remote tracker or spec docs unchanged, so that people read plans where they always have.
2. As a user, I want all orchestration state on my machine only, so that agent notes and evidence never reach a remote.
3. As a user, I want one beads database per machine shared by every project and agent, so that I never set up beads per repository.
4. As a user, I want the beads server installed and started by home-manager at login, so that every agent finds it without manual steps.
5. As a user, I want a fresh machine to create the global database by itself, so that setup needs no one-off command.
6. As a user, I want the server on both my Linux and macOS hosts, each with its own database, so that work stays on the machine where it started.
7. As a user, I want orchestration to stop with a clear blocker when the server is down, so that state never splits across a fallback database.
8. As a user, I want the orchestrator to pull my agreed tickets once at start, so that the work starts from what I planned.
9. As a user, I want the orchestrator to re-pull a ticket right before dispatching its worker, so that my last-minute edits are honoured.
10. As a user, I want a changed ticket recorded as a comment on its bead, so that I can see what changed before work began.
11. As a user, I want a ticket that was closed or cancelled on the remote to stop its dispatch and ask me, so that no worker starts on dropped work.
12. As a user, I want `--track` to create a missing ticket on the remote first and then pull it, so that beads never push.
13. As a user, I want Linear, Jira and GitHub tickets imported with bd's own pull, so that imports use one well-tested path.
14. As a user, I want Lark docs and `docs/specs` files imported by hand into beads, so that every planning destination works.
15. As a user, I want Jira tickets read in full through the Jira MCP when the task definition is written, so that nested acceptance criteria are not lost.
16. As a user, I want blocking links imported (Linear relations, Jira links added by hand), so that `bd ready` releases tasks in the planned order.
17. As a user, I want one bead per remote ticket forever, so that a ticket's history stays in one place across sessions.
18. As a user, I want one epic per orchestrator session holding every task of that session, so that status, recovery and handoff deal with one root.
19. As a user, I want the remote planning parent recorded on the epic, so that I can see which planned set a session worked.
20. As a user, I want two orchestrators running at once to never take each other's beads, so that parallel sessions are safe.
21. As a user, I want an orphaned bead from a dead session reported to me and adopted only on my yes, so that no work is silently taken over.
22. As an orchestrator, I want `bd ready` scoped to my epic, so that I dispatch only my own work.
23. As an orchestrator, I want to claim a bead for a named worker atomically, so that a race is settled without double dispatch.
24. As an orchestrator, I want every event as a comment with a fixed first line, so that history is append-only, attributed and parseable.
25. As an orchestrator, I want PR URL, head SHA, merge SHA, review round and blocked reason as bead metadata after the claim, so that current facts are one lookup away.
26. As an orchestrator, I want a task bead to close only after its merge SHA is verified on the target branch, so that dependents launch on real merges.
27. As an orchestrator, I want a task bead reopened for re-review when its PR head changes after local review, so that unreviewed code never merges.
28. As an orchestrator, I want my status table and post-compaction context built from beads, so that recovery needs no separate log.
29. As an orchestrator, I want my session epic reused in the same terminal and closed on `--off` when empty, so that unfinished work stays visible.
30. As an orchestrator, I want to write the task definition into the bead, so that no brief file exists.
31. As a worker, I want my first prompt to load the standing contract, run `bd prime`, and show my bead, so that I start with everything I need.
32. As a worker, I want my bead id and actor name in my environment, so that I can find my work after any compaction.
33. As a worker, I want the standing contract, my bead and my latest re-instruction injected after every compaction, so that I never forget the rules.
34. As a worker, I want a living notepad in my bead's notes field, so that my plan and findings stay current instead of piling up.
35. As a worker, I want to report each handoff point as one report comment, so that the orchestrator reads my result instead of my screen.
36. As a worker, I want to capture out-of-scope gaps as deferred follow-up beads, so that nothing I notice is lost.
37. As a worker, I want my allowed bd commands spelled out, so that I never change state I do not own.
38. As a reviewer, I want my own review bead per round, so that I work under the same contract as any worker.
39. As a reviewer, I want my findings in my review bead's notepad, so that the orchestrator relays them from one place.
40. As a user, I want follow-up beads kept out of `bd ready`, so that discovered work is never dispatched by accident.
41. As a user, I want the orchestrator to ask about syncing follow-ups when a task settles and again in the final report, so that I decide what reaches the remote.
42. As a user, I want an approved follow-up created on the remote and pulled into the same bead, so that it becomes a normal ticket without duplicates.
43. As a user, I want declined follow-ups kept as a local backlog, so that a later session can pick them up.
44. As a user, I want `--handoff` to give the peer one handoff bead with the side issue, decisions and pointers, so that the peer starts from one id.
45. As a user, I want a handed-off task bead superseded in the orchestrator's epic, so that the work is clearly no longer the orchestrator's.
46. As a user, I want handoff refused while a worker or reviewer is live on the task, so that no running work changes hands.
47. As a user, I want a kept worktree and branch passed to the peer by name, so that the peer can continue on existing work.
48. As a peer, I want to trace the source bead and its comments from my handoff bead, so that I understand what came before.
49. As a user, I want Pi's ulw notepad to live in the bead when a bead is assigned and stay local otherwise, so that ad-hoc sessions keep working.
50. As any agent, I want `bd prime` to explain beads, ownership, notepad versus comments, and what is forbidden, so that I use the database correctly whatever my role.
51. As a user, I want durable lessons to go to ICM and never to bd memories, so that I keep one memory system.
52. As a user, I want a glossary of these terms with the orchestrator skill, so that every doc uses the same words.

## Implementation Decisions

### Global beads server (nix-config)

- A new home-manager option module `programs.beads` (modeled on the icm option module) exposes `enable`, `package` and `server.enable`. The ai-tools feature enables it and replaces its bare beads package line. Port and data directory stay at bd's defaults.
- With the server enabled, every session gets `BEADS_DOLT_SHARED_SERVER=1` and `BEADS_DIR` pointing at the anchor workspace under `$XDG_DATA_HOME/beads/global` (bd refuses to initialise under `~/.beads`).
- A login service runs `bd dolt start` and stops with `bd dolt stop`, so bd owns the dolt process; a systemd user service on Linux and a launchd agent on macOS. After each start it runs `bd init --shared-server --init-if-missing` in the anchor. No automatic restart on crash.
- The anchor's own database on the shared server is the one global database. No script or skill passes `--global`; the environment alone selects the database.
- Auto-commit stays at bd's default (one Dolt commit per write). No Dolt remote is configured and nothing is pushed. No backup, pruning or compaction.
- When `bd ping` fails, orchestrator init stops with a shared blocker and workers report a blocker; there is no fallback database.
- The module installs the anchor's `PRIME.md` (below).

### Scoping and identity

- One **session epic** per orchestrator session (one herdr-core terminal, from mode on to `--off`). The epic carries metadata `repo`, `session=<terminal id>` and `source=<remote planning parent>` (several when several planned sets are worked). Init reuses this terminal's open epic or creates one. `--off` closes the epic when every child is closed; otherwise it stays open with an `event=mode flags=--off` comment.
- **Task beads** are scoped only by their parent epic, because an applied pull wipes a task bead's labels and metadata. Exactly one task bead per remote ticket across all sessions, found by `external_ref` before any create. A later session reopens and re-parents it.
- A task without a ticket is a local task bead with metadata `key=<slug>`. A batch ticket's bead is the parent of one local **batch target bead** per target (`key=<slug>-<target>`); the ticket bead closes when all its targets close.
- Bead ids stay bd-generated; agent names keep the ticket key (`w-<key>-<slug>`, `r-<key>-<slug>`).
- Conflict rule: if an import finds the bead claimed or under another open epic whose session terminal is alive, the orchestrator stops on that task and reports. If that terminal is gone, it reports the bead and old epic and waits; only on the user's yes does it re-parent with an `event=adopted from=<old epic>` comment. Epics are never adopted.
- Actors: orchestrator `o-<terminal>`, worker `w-…`, reviewer `r-…`, handoff peer `h-<slug>`. The orchestrator claims for workers with `--actor w-<key> --if-status open`; a lost race exits 13 and writes nothing.

### Import and re-pull

- Engine: bd's native pull for Linear (personal profile), Jira (work profile) and GitHub, with tokens from nix-config and nix-config-private. bd's tracker push and bidirectional sync are never used. Lark and `docs/specs` sources are imported by hand: look up `external_ref`, then create or update.
- Imported: only the tickets agreed for the invocation, plus their blocking links; an outside blocker is imported too, carrying remote state only. Under `--track`, a missing ticket is created on the remote through the tracker MCP or `gh`, then pulled.
- Rules: one ticket per pull (`bd <tracker> pull <id> --json`), never a bulk sync, never pull a claimed bead. Write order: pull, add the epic as parent (a dependency edit does not bump the bead), re-pull right before first dispatch, claim, dispatch. Nothing that bumps a task bead (metadata, claim) is written before its re-pull.
- Skip guard: bd silently skips a bead changed after the tracker's last sync. On `stats.skipped`, pull once more; on a second skip, hold the bead and report. One import script owns this logic.
- Re-pull happens once per task bead, before its first dispatch (including a queued bead whose blockers just closed); never before re-instructions to a running worker. Title and description are snapshotted first; a change is recorded as a comment and dispatch proceeds with the new body. A remote done or cancelled ticket skips dispatch, marks the bead blocked and asks the user.
- Field mapping: title, description, priority, status, type and assignee come from the pull; the ticket URL is `external_ref`. Each tracker's state map sends done and cancelled to `closed` and every other state to `open`; local `in_progress` comes only from the claim. Remote labels and comments are not relied on.
- Jira: the bead description is an index only (bd keeps only top-level text); the orchestrator reads the full ticket through the Jira MCP when writing the task definition, and adds blocking edges by hand. Linear pulls with `--relations`; a Linear parent never displaces the session epic.

### Orchestration state

- Every task event is a comment on its task bead with first line `event=<name> k=v…`, written as `o-<terminal>`. Session events, including `event=mode flags=… max=<N>` (latest wins), go on the epic. Event names stay as today (ticketed, dispatched, queued, re-instructed, ready, merged, settled, reaped, blocked, decided, note, handed-off, adopted).
- Current facts are task-bead metadata written only after the claim: `pr_url`, `head_sha`, `merged_sha`, `review_round`, `blocked_reason`. A repair's second PR replaces `pr_url`; the comments keep the history.
- Coarse state is bead status: queued `open`, working `in_progress`, `blocked`, done `closed`. `set-state`, provenance, bd events and bd audit are not used.
- A task bead closes only after its merge SHA is verified on the target branch; work that does not merge closes at `settled succeeded`. Closing releases dependents through `bd ready`. A dependent's PR still merges only after each prerequisite's `settled succeeded` event.
- The log script becomes an event script that validates the event name and first-line format and writes the comment; the TSV file is deleted. The status and compact-context scripts keep their names and the `orch-context` label contract, and read the epic (found by `session=`) and its children. The herdr-app session integrations do not change.

### Task definition and standing contract

- The brief is retired. The task bead holds the **task definition**: `description` is the ticket body (or the orchestrator's "what to build" for a local bead); `acceptance` holds the acceptance criteria including verification and the `Broad run:` line; `design` holds decisions and unchanged behaviour, context, transitional code, out of scope and the mode's deliverables; native dependencies hold "blocked by"; metadata after the claim holds `worktree`, `branch`, `base`.
- A new skill **`orchestrated-worker`** (productivity category, both profiles, model-invocable with a description restricting it to dispatched `w-`/`r-` agents) is the one fixed **standing contract**: worktree-only rule, resources and browser cleanup, no other agents, waits, report by ending the turn (never `hc send`), tripwires, one-command-at-a-time verification, the PR worker contract when deliverables ask for a PR, the allowed bd commands, the notepad and report conventions.
- First prompt from the start script: load `orchestrated-worker`, run `bd prime`, run `bd show <bead>`, work that bead. Pi gets `$skill:orchestrated-worker` plus any `$skill:` tokens in the bead's `design`, then `ulw`; Claude and Codex are told to load the skill. The start script also sets `BEADS_ACTOR` and `ORCH_BEAD` and labels the worker terminal `orch-context=<worker-context script>`.
- A worker-context script prints the standing contract, `bd show $ORCH_BEAD`, and the latest `event=re-instructed` comment; the existing herdr-app integrations inject it after any compaction. No bd hooks are installed.
- A later message to a worker is a **re-instruction**: an `event=re-instructed` comment holding the full text. The follow-up script is renamed `send-reinstruction.sh` and sends a pointer to that comment, repeating the first-prompt pointer after `/new` or a revive.
- Screenshots and evidence stay as files outside the worktree, with paths in a comment; a full reap stops deleting briefs.

### Worker bd contract

- Workers and reviewers may read (`bd prime`, `bd show`, `bd comments`, `bd list`, `bd ready`) and, on their own bead only, comment and replace the `notes` field. They may also run exactly one create form for follow-up beads (below). Never: claim, unclaim, status or other field or metadata changes, close, dependency edits, delete, `bd dolt push`, tracker sync or pull.
- **Notepad**: the notes field of a bead one owns is one living document (plan, now, findings), replaced whole by its single writer, about one page.
- **Report**: at each handoff point a worker posts `event=report kind=<ready-local|pushed|pr-opened|blocked|done> head=<sha> [pr=<url>]` with the full result in the body, then ends its turn with a one-line summary. The orchestrator reads the report comment, not the screen.
- Durable lessons go to ICM; bd memories are never used.

### PRIME.md

- A full replacement of bd's default prime text, about 40 to 60 lines, with nothing about herdr or orchestration: what the database is (one local machine-wide database, never pushed); bead anatomy and `bd show --json`; status and readiness (always scoped `bd ready --parent <epic> --json`, never unscoped, never `--claim`); epics, parents and `blocks`; notepad versus comments (notepad in the notes field of a bead you own; comments for milestones with first line `event=<name>`); finding your work (`ORCH_BEAD`, else your own session epic); ownership (assignee is your `BEADS_ACTOR`, or you created it in a plain session; otherwise only show and comment); plain-session tracking (create under your own epic, claim with `--if-status open`, close your own); memory goes to ICM; forbidden: `bd dolt push`, tracker sync or push, `bd edit`, `bd delete`, and tracker pull for anyone but the orchestrator.

### Review beads and follow-up beads

- Each local review round is a **review bead**, a child of the task bead, created and claimed in one step for `r-<key>`; the reviewer is an ordinary orchestrated worker on it, with the range in `design`, findings in its notepad and a closing report. The orchestrator relays in-scope findings and closes the review bead. Raw review files and `reviewed` comments are dropped; no bead per finding.
- A **follow-up bead** is only discovered out-of-scope work; repairs of the same outcome stay in the task bead. Workers and reviewers create one with the single allowed form: create with title, `discovered-from` their own bead, label `follow-up`, a description of gap, size and area, then defer it. It has no parent, so it is never dispatched and never blocks the epic. The orchestrator adds `repo` and `session` metadata, merges duplicates, and lists them.
- The user is asked about syncing in each task's settled report line and again in the final report; a repo without a remote tracker only keeps them locally. On yes, the orchestrator creates the remote ticket, sets the bead's `external_ref`, and pulls it into the same bead. Declined ones stay deferred as a local backlog; a later session undefers and re-parents one to work it.

### Handoff

- Every `--handoff` creates one **handoff bead**: no parent, description holding the side issue, decisions in the user's words, out of scope and pointers, `discovered-from` each source (the task bead, or the session epic for a conversation), metadata `repo`, claimed for the peer `h-<slug>`. The peer's first prompt is `bd prime`, `bd show <handoff bead>`, plus the skill invocation and flags when flags were given. A peer orchestrator's own init creates its epic and links it `discovered-from` the handoff bead.
- A named task bead is closed in the orchestrator's epic with `bd supersede` by the handoff bead and an `event=handed-off` comment. Handoff refuses a task with a live worker or reviewer and asks the user to let it settle, stop it or reap it. A kept worktree and branch pass to the peer by name, and the old orchestrator never reaps them.
- A plain peer closes the handoff bead itself; a peer orchestrator closes it when its epic closes. The old orchestrator never reads or sends to the peer.

### Pi ulw (pi-config)

- The ulw extension chooses its injected prompt like the mode prompts do: with `ORCH_BEAD` set it injects a bead variant whose notepad is that bead's notes field; without it, the original local notepad. Pi's Task tool is unchanged.

### Vocabulary

- A glossary inside the orchestrator skill's folder defines: ticket, bead, task bead, batch target bead, session epic, orchestrator session, invocation, review bead, follow-up bead, handoff bead, worker, reviewer, actor, claim, notepad, event, report, import and re-pull, re-instruction, settled, task definition, standing contract. Retired: run, brief, bare task, and "follow-up" for messages. `orchestrated-worker` and `PRIME.md` use the same words.

## Testing Decisions

- A good test drives a script or module through its public interface (command line, nix option evaluation, extension hook) and asserts observable results: bead fields, comments, metadata, exit codes, printed output. It never asserts internal steps.
- Every check runs the real bd against a throwaway embedded database created per run (`BEADS_DIR` in a temporary folder, shared-server mode unset, an actor set). No check starts a Dolt server, contacts a tracker, or touches the global database; the orchestrator's check script refuses to run when `BEADS_DIR` resolves to the anchor.
- Orchestrator scripts, through the existing skill check script and its fake herdr-core fixtures: the event script (validation, actor), status and compact-context (epic by `session=`), init (epic reuse, `--off` closing), the start script (environment, terminal label, first prompt with Pi skill tokens), `send-reinstruction.sh`, the worker-context script, claim races (exit 13), and the import script, using a PATH shim that fakes only bd's tracker pull output (skip then apply, double skip) and passes every other bd call to the real binary. Prior art: the same check script's isolated fixtures.
- nix beads module: an evaluation test in the style of the icm module test (environment, systemd and launchd definitions, `PRIME.md` installed), plus a text check that `PRIME.md` mentions neither herdr nor orchestration and forbids `bd dolt push`. The herdr-app session-integrations test is unchanged.
- Pi ulw: the extension's existing test file gains the `ORCH_BEAD` set and unset cases.
- Not automated: the prose of `PRIME.md` and `orchestrated-worker`. Acceptance includes one manual end-to-end orchestrator session on a trivial local task after landing.

## Out of Scope

- Changes to the planning skills (wayfinder, grill-me, to-spec, to-tickets).
- `orchestrate-using-t3code`; it may adopt this contract later.
- Replacing Pi's Task tool with beads; a later effort.
- Pushing beads data, Dolt remotes, or two-way tracker sync.
- Retention, pruning, compaction and backup of beads; revisited only if problems show up.
- A cutover period: the TSV log is replaced when this lands, with no side-by-side run.
- Adopting Gas City (it supports herdr TUI, not herdr-app and herdr-core).

## Further Notes

- Facts behind the decisions come from bd 1.3.4 source and help: the silent pull skip rule, metadata wiped by pull, comments and dependency edits not bumping a bead, Jira description flattening, and shared-server bootstrap. The wayfinder ticket comments hold the line-level references.
- If `bd ready --parent` also returns grandchildren, the orchestrator must claim a review bead in the same step that creates it, so it never appears as ready work.
- Gas City informed two choices: PR facts as work-bead metadata with closing only on a verified merge, and the worker's readable story in the notes field.
