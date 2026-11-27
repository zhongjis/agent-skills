# Spec: orchestrate-using-herdr-app UI contract and script fixes

Status: implemented

Source: the 2026-11-26 audit of the herdr-panda agents UI and this skill. The UI side is specified in nix-config `docs/specs/herdr-panda-agents-ui.md`.

## Problem Statement

The herdr-app Agents panel cannot see the orchestrator talk to its workers: `send-reinstruction.sh` writes a bead comment the panel polls every 10 s, and `type-command.sh` and hand-run `hc keys` leave no trace at all. The user can answer a task's blocking question only in the orchestrator's chat; an answer typed elsewhere is never recorded, so the `blocked_reason=needs-user` hold stays and holds `--auto` merges.

Several scripts disagree with their docs or fail unsafely:

- `send-reinstruction.sh` exits 3 when the worker terminal is missing, a code its header reserves for an invalid review base.
- Reviving a finished worker runs `hc rm` before `start-worker.sh --resume`; a failed start loses the only `resume` label, and the session ID survives nowhere.
- `reap-worker.sh --keep-agent` labels Codex workers `hibernate=ok`, so the herdr-app sidebar hibernates them, although `references/reap.md` says Codex cannot hibernate and `send-reinstruction.sh` cannot revive a Codex session.
- `reap-worker.sh --full` deletes the worktree, the local branch (`-D`) and the remote branch (`--no-verify`) with no check that the work merged, and a guard on one bead would not bind to the worktree and branch actually deleted.
- Event field values cannot hold line breaks or text that looks like a field (`q=should we set by=default?`), so readers split them wrongly.
- `pr_url` and `head_sha` are written by hand; nothing mirrors them, so the panel's PR stop lags.
- An unconfirmed launch exits 2 without a `dispatched` event, so the task reads queued while its worker may run.

## Solution

- Every confirmed delivery stamps the worker terminal with `orch.in=<epoch ms>:<kind>`: `dispatched` (`start-worker.sh`), `re-instructed` (`send-reinstruction.sh`), `command` (`type-command.sh`). The label is best-effort and never fails a script.
- A panel answer is `Answer from the herdr-app panel for <key> (bead <bead-id>, question <comment-id>). Question: <question>. Answer: <answer>`, accepted only as unwrapped input. The orchestrator records `decided by=user question=<comment-id>` with the question and the answer, then acts on it; a stale question is refused.
- `send-reinstruction.sh` maps a missing worker, including one that vanishes between the lookup and `hc send`, to exit 2, and its restart records the session ID on the `re-instructed` comment before launching; a failed restart prints the resume line.
- `reap-worker.sh --keep-agent` never labels a Codex worker `hibernate=ok`. `--full` without `--keep-remote` requires `--bead` and refuses unless the bead's `merged_sha` is on its base ref or the bead has `settled result=abandoned`.
- `event.sh ready` mirrors `pr=` to `pr_url` and `head=` to `head_sha`.
- `start-worker.sh` records `dispatched result=unconfirmed` (or `result=blocked`) when it exits 2 after a launch.

## User Stories

1. As the user, I want the Agents panel to pulse the moment the orchestrator sends to a worker, so that I see delegation happen.
2. As the user, I want to answer a task's blocking question from the panel and have it recorded, so that the hold clears and the merge gate opens.
3. As an orchestrator, I want an answer from the panel recognized as the user's, so that I record it with the question I asked.
4. As an orchestrator, I want a missing worker to exit 2, so that I never read it as an invalid review base.
5. As an orchestrator, I want a failed restart to keep the session ID, so that hours of worker context are never lost.
6. As the user, I want Codex workers never hibernated, so that a follow-up never hits a session the skill cannot revive.
7. As the user, I want full cleanup to refuse unmerged work, so that one wrong argument never deletes my branch.
8. As an orchestrator, I want PR facts mirrored when gates close, so that metadata stays current without a hand write.
9. As the user, I want an unconfirmed launch recorded, so that the panel shows the task dispatched.

## Implementation Decisions

- **Label stamp.** One helper per script (no shared library), run after the delivery is confirmed: `hc label "$name" "orch.in=$(( $(date +%s) * 1000 )):<kind>" >/dev/null 2>&1 || true`. Seconds times 1000 keep macOS `date` portable. `start-worker.sh` stamps inside `log_dispatch`; `send-reinstruction.sh` after `hc send` returns; `type-command.sh` after the final `enter`.
- **Panel answers.** `SKILL.md` Report section owns the rule; `references/supervise.md` Steering gets one line pointing to it. The message is `Answer from the herdr-app panel for <key> (bead <bead-id>, question <comment-id>). Question: <question>. Answer: <answer>`; `<comment-id>` is the `id` in `bd comments <bead> --json` of the `blocked reason=needs-user` comment answered. Provenance: the herdr-app process has no `HC_TERMINAL_ID` and `hc` tags a send from a terminal with `<hc from="…">`, so a genuine answer arrives unwrapped; the same text inside `<hc from=…>` is a child's message. The orchestrator records `decided by=user question=<comment-id> q=<question> a=<answer>`, where the question is the blocked event's `q=` field, else its whole body. With `question=`, `event.sh` refuses an empty id, then verifies that `metadata.blocked_reason` is `needs-user` and that the hold belongs to that question: `event.sh blocked reason=needs-user` records the new comment's id as `blocked_question`, and a hold from before that field existed falls back to the newest question. Only comments authored by an `o-` actor are questions, here and wherever a question comment is looked up (the herdr-app panel applies the same rule). Otherwise it prints `stale answer: question <id> is not the open question on <bead>`, exits 1 and writes nothing, and the orchestrator tells the user the question changed. The release re-checks the hold's question just before unsetting `blocked_reason` and `blocked_question`; a newer question that landed in between keeps its hold, and `event.sh` says so. `decided` without `question=` still clears any needs-user hold. One hold per bead still applies. The panel sends only while the orchestrator is not blocked in its own dialog.
- **Field encoding.** `event.sh` writes `key=value` bare unless the value contains a newline, CR or tab, starts with `"`, or contains a space followed by `[a-z][a-z0-9_-]*=`; then `key="<escaped>"` with `\\`, `\"`, `\n`, `\r`, `\t`. Reader rule: a value that starts with `"` and has a closing unescaped `"` followed by a space or the end of the line is decoded with those escapes and the next field starts at the next `key=` token; any other value parses as before, so existing comments are unchanged. Known keys include `question`, `reviewer` and `model`.
- **Exit codes.** `send-reinstruction.sh` runs `hc get` before any slot, review-base or other input check: a missing terminal prints `agent <name>: no such terminal` and exits 2, also when it disappears while the turn is confirmed; the header lists it under 2.
- **Restart record.** `record_instruction` takes optional extra fields; the finished branch passes `session=<id> kind=<kind> worktree=<path>` so the `re-instructed` comment carries them before the launch. Before either, `start-worker.sh ... --check` runs every stable launch guard (assignment, reviewer busy worktree, slot, resumable kind, the agent program found by `command -v`) and launches nothing, so a refusal keeps the old terminal and its `resume` label. `hc run --name` is unique only among live terminals, so the replacement launches while the finished terminal still exists; `start-worker.sh` then addresses it by the address `hc run` returned, and `send-reinstruction.sh` removes the old terminal by its address only after the start succeeded. When the start fails, the finished terminal and its label stay, and the script prints `restart failed; resume line: <label>` only when `hc ls` shows no live terminal with that name; otherwise it says a replacement terminal exists (or cannot be inspected) and prints no resume line.
- **Codex hibernation.** `reap-worker.sh --keep-agent` reads `.status.app` (`claude-code` is Claude), else only the executable token of the argv (after a leading `env` and its `K=V` words, never the prompt), from `hc get <agent> --json` and labels `hibernate=ok` only for a positively identified non-Codex agent. For `codex` it prints `codex workers are not hibernated` and removes any existing `hibernate=ok` (`hc label <agent> hibernate=`); when inspection fails or no known program is found it prints a line and labels nothing. `references/reap.md` and `references/agent-quirks.md` keep saying Codex cannot hibernate.
- **Full-cleanup guard.** Without `--keep-remote`, `--full` requires `--bead`. It refuses (`refusing: ...`, exit 1, nothing removed) unless the bead binds to every target (its `worktree` metadata, when set, resolves to the worktree; its `branch`, when set, equals the branch; at least one of those set; its `repo`, when set, has the worktree's git common dir; the worktree's HEAD is on the branch; the agent is the bead's assignee or its newest `o-` `dispatched` agent, and each live `w-`/`r-` terminal of the stem has its cwd inside the worktree) and either the bead is still closed and the newest `settled` by an `o-` author is `result=abandoned` with no later `dispatched`, `re-instructed`, `handed-off`, `adopted` or `report` event, or the merge is verified: `merged_sha` is 40 hex and an ancestor of the fetched base ref (`<ref>@<sha>` in `base`), the worktree has no uncommitted or untracked changes, the local tip is the `head=` of the newest `o-` `ready` event before the `merged` event (not the mutable `head_sha`; without one, it is an ancestor of the base ref) and a remote branch is at the local tip. The remote branch is deleted first with `--force-with-lease` on that verified tip. `references/reap.md` states the guard.
- **Ready mirror.** `event.sh ready` validates `pr=` as an `http(s)` URL and `head=` as 7 to 40 hex, then sets `pr_url` and `head_sha` metadata after the comment, like the `merged` mirror.
- **Dispatch results.** `log_dispatch` takes a result: `working` when confirmed, `blocked` when the worker is blocked at a dialog after launch, `unconfirmed` at the 60 s timeout; a terminal that is not live writes nothing.
- `skills/AGENTS.md` records each contract (DOX pass); `GLOSSARY.md` is unchanged.

## Testing Decisions

- `tests/check.sh` with its `hc` fixture and throwaway beads database: `orch.in` labels after dispatch, re-instruction and a typed command (fixture records `hc label` calls); missing worker exits 2; the finished-worker restart writes `session=` and `kind=` before `hc rm`, and a failed restart prints the resume line; `--keep-agent` skips Codex and labels Pi; `--full` refuses without `--bead`, refuses an unverified merge, passes with a verified `merged_sha`, passes with `settled result=abandoned`; `--full` also refuses a repo mismatch, a worktree on another branch, a foreign agent, a merged head moved by a later `ready` event and a reopened bead, and its remote delete is lease-guarded; `decided` refuses an empty or non-`o-` question and keeps a newer question's hold; `start-worker.sh --check` fails for a missing program; `send-reinstruction.sh` exits 2 when the terminal vanishes before the send; `--keep-agent` accepts `claude-code` and ignores `/codex` in a prompt; `event.sh ready` sets `pr_url` and `head_sha`; unconfirmed and blocked launches record their results.
- `evals/evals.json` gains one scenario: a panel answer arrives while other tasks run, and the orchestrator records `decided by=user` with the recorded question.

## Out of Scope

- Codex worker revival (deferred in wf-494).
- Labels on `watch-agent.sh` reads or waits: they are polling, not delivery.
- Changing how workers report; `event=report` comments stay the only worker-to-orchestrator channel.

## Plan

1. Label stamps in the three scripts, with fixture checks.
2. Exit code guard and restart record in `send-reinstruction.sh`, with checks.
3. Codex skip and the full-cleanup guard in `reap-worker.sh`, `references/reap.md`, with checks.
4. `ready` mirror in `event.sh` and dispatch results in `start-worker.sh`, with checks.
5. Panel answers in `SKILL.md`, `references/supervise.md` and one eval.
6. DOX pass on `skills/AGENTS.md`; run `tests/check.sh`; leave the diff uncommitted on `main` for the user.

## Further Notes

- The panel treats `orch.in` as fresh for 5 s; the stamp needs no cleanup.
- Resume labels written by the herdr-app sidebar may start with `env K=V…`; the restart's kind and session parsing already accepts a prefix.
