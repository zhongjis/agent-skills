# Handoff (`--handoff`)

Transfer work out of this session to one peer, a new top-level conversation that owns it end to end, through one handoff bead. Two cases:

- **A small task the user supervises in person:** `--handoff` alone starts a normal-agent peer that does the work itself, on its own branch, apart from this session's work.
- **A side conversation in its own thread:** `--handoff` with flags starts a peer orchestrator, which may plan again (`--track` files tickets), create its own session epic, and dispatch its own workers.

The flags the user typed on this invocation, minus `--handoff`, belong to the peer's session; act on none of them here, and never carry the session's earlier flags. Under `--track` the peer files the tickets; file none yourself.

## Overlap

- Hand off only work this session will no longer touch.
- Refuse a task with a live worker or reviewer: ask the user to let it settle, stop it, or reap it, and stop. Check both roles, because `scripts/status.sh --live` reads only the worker: in `hc ls --json`, a `w-<key>-…` or `r-<key>-…` terminal that is not `finished` is live unless a `settled` event follows the task bead's latest `dispatched` event. A kept worktree and branch pass to the peer by name in the handoff bead; never reap them afterwards.

## Handoff bead

The peer starts cold and never sees this conversation; the handoff bead is everything it gets. Create exactly one per `--handoff`, with no parent:

```bash
bd create "<side issue>" --type task --actor "o-$HC_TERMINAL_ID" \
  --deps "discovered-from:<source>[,discovered-from:<source>…]" \
  --metadata "$(jq -cn --arg repo "<git root, else pwd>" '{repo: $repo}')" \
  --description "<text>" --silent
bd update <handoff> --claim --actor h-<slug>
```

- **Sources:** each named task bead; for a conversation without one, the session epic. A normal session has neither, so the bead has no link and its pointers carry the trace.
- **Description**, written per [delegation-contract.md](delegation-contract.md) where it applies, plus what only this conversation knows:
  - the side issue: what came up and why it matters
  - decisions already made, in the user's words where they set scope
  - open user questions: every handed-off bead with `blocked_reason=needs-user` and its question, still unanswered
  - what stays out of scope, including work this session keeps
  - pointers: ticket, PR, files, logs, prior findings, and each kept worktree and branch by name
- `bd ping` failing is a shared blocker: report it and keep the tasks.

## First prompt

The peer's first prompt carries no task content; the bead does:

- **Peer orchestrator:** open with the skill invocation for the peer's kind (see Launch) carrying exactly the flags, then: run `bd prime`, then `bd show <handoff>`, which holds the work handed to you; pass `--from <handoff>` to `orchestrate-init.sh`. Its init links the new session epic `discovered-from` the handoff bead, and its `--off` closes the handoff bead when it closes that epic.
- **Plain peer:** no skill invocation and no flags: run `bd prime`, then `bd show <handoff>` and do that work yourself on your own branch; close it with `bd close <handoff> --actor h-<slug>`, its claimant, when it is done. Keep the kind's other launch requirements from Launch.

## Launch

The peer runs your own agent kind unless the user names another. Read your kind from the `agent` field of `hc get $HC_TERMINAL_ID` (`claude-code` maps to the `claude` section), and take the peer's argv and first-prompt shape from that kind's **Peer orchestrator** line in [agent-quirks.md](agent-quirks.md).

Start the peer top-level in a visible tab, never as your child: `herdr-app do tab.new '{"name":…,"space":…,"folder":<source>,"argv":<kind argv>,"task":<first prompt>}'`, with the space ID from `herdr-app ls`. **Done when** `hc get` shows the peer `working` with no parent; on failure, report the exact error and keep the tasks.

## The cut

Once launch is done, the peer owns the work: workers, worktrees, reaping, merge, and the user's questions. It reports to the user in its own tab.

- Close each named task bead in your epic with `bd supersede <task> --with <handoff> --actor "o-$HC_TERMINAL_ID"` and record `scripts/event.sh <task> handed-off handoff=<handoff> tab=<id> terminal=<id>`; without task beads, an active session epic holds the event.
- Report the handoff in a brief and drop the tasks. Have no further contact with the peer: no watcher, `hc read`, `hc send`, or `SendMessage`. If the user later asks about those tasks, point them to the peer's tab.
