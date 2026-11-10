# Handoff (`--handoff`)

Hand the tasks to one peer, an orchestrator or a normal agent (see Brief): a new top-level conversation that owns them end to end. Use it when a side issue comes up mid-conversation and needs its own context, apart from this one.

## Brief

The peer starts cold and never sees this conversation. Write the brief per [delegation-contract.md](delegation-contract.md), plus what only this conversation knows:

- the side issue: what came up and why it matters
- decisions already made, with the user's words where they set scope
- what stays out of scope, including work this session keeps
- pointers: ticket, PR, files, logs, prior findings

The flags the user typed on this invocation, minus `--handoff`, belong to the peer's session; act on none of them here, and never carry the session's earlier flags.

- With flags: open the brief with the skill invocation for the peer's kind (see Launch), carrying exactly those flags. Under `--track` the peer files the tickets; file none yourself.
- With `--handoff` alone: the peer is a normal agent, not an orchestrator. Invoke no skill in the brief; keep the kind's other launch requirements from Launch. The peer does the tasks itself, on its own branch, apart from this session's work.

## Overlap

Hand off only work this session will no longer touch. Before launch, check your log for a live worker, worktree, or branch on each task:

- None: hand the task off.
- Some: the brief transfers each one to the peer by name (terminal, worktree, branch), you stop your own watcher on it, and you log it as handed off. Never read, send to, or reap it again.

## Launch

The peer runs your own agent kind unless the user names another. Read your kind from the `agent` field of `hc get $HC_TERMINAL_ID` (`claude-code` maps to the `claude` section), and take the peer's argv and skill invocation from that kind's **Peer orchestrator** line in [agent-quirks.md](agent-quirks.md).

Start the peer top-level in a visible tab, never as your child: `herdr-app do tab.new '{"name":…,"space":…,"folder":<source>,"argv":<kind argv>,"task":<brief>}'`, with the space ID from `herdr-app ls`. **Done when** `hc get` shows the peer `working` with no parent; on failure, report the exact error and keep the tasks.

## The cut

Once launch is done, the peer owns the tasks: workers, worktrees, reaping, merge, and the user's questions. It reports to the user in its own tab. Log `handed-off` with the tab and terminal IDs, report the handoff, and drop the tasks. Have no further contact with the peer: no watcher, `hc read`, `hc send`, or `SendMessage`. If the user later asks about those tasks, point them to the peer's tab.
