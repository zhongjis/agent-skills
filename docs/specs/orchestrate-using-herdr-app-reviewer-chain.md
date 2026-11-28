# Spec: orchestrate-using-herdr-app reviewer chain

## Problem Statement

The orchestrator picks a reviewer with a fixed swap: Pi and Codex workers get a Claude reviewer, and Claude workers get a Pi reviewer. The swap names specific agent kinds, so it fails on a host that does not have them. The personal host has Claude, Codex, Pi and agy. The work host has only Pi and GitHub Copilot, and its Pi worker runs either an Anthropic or an OpenAI model through the Copilot provider. The skill cannot start an agy or Copilot reviewer, cannot prefer a Gemini reviewer for frontend work, and cannot revive a finished agy or Copilot reviewer.

## Solution

- The reviewer is always a model from a different family than the worker's current model.
- The orchestrator walks one ordered chain and takes the first kind that is installed on the host and runs a different family:
  - Task with a visual target: agy, claude, codex, pi, copilot.
  - Any other task: claude, codex, pi, agy, copilot.
- A script finds the installed kinds and caches the answer. The skill does not know which agents a host has.
- Every kind starts on its CLI's default model. Claude, Codex and agy each run one family. Pi and Copilot can run either family; when the default matches the worker's family, the orchestrator switches the model in the session.
- `start-worker.sh` starts and resumes agy and Copilot. `send-reinstruction.sh` revives them from their `resume` label.
- herdr-app's panda-focus integrations label agy and Copilot terminals with their resume line, as they already do for Claude, Pi and Codex.

## User Stories

1. As an orchestrator, I want a reviewer chain rule that names no host, so that the same skill works on every host.
2. As an orchestrator, I want to compare model families, not kinds, so that a Pi worker on a Claude model never gets a Claude-family reviewer.
3. As an orchestrator, I want a visual-target task to try agy first, so that frontend-heavy changes get a Gemini review.
4. As an orchestrator, I want any other task to try claude, codex, pi, agy, then copilot, so that the user's order holds.
5. As an orchestrator, I want to skip kinds that are not installed, so that I never start an agent that is not on the host.
6. As an orchestrator, I want the installed kinds cached, so that I do not probe the host for each review round.
7. As an orchestrator, I want the cache to refresh when PATH changes, so that a newly installed agent is found.
8. As an orchestrator, I want a `--refresh` flag, so that I can force a new probe.
9. As an orchestrator, I want to skip a kind with a quota or outage recorded this session, so that review moves to the next kind.
10. As an orchestrator, I want a kind or model the user names to win over the chain, so that the user stays in control.
11. As an orchestrator, I want a blocking question when no kind is eligible, so that review never runs on the worker's own family without the user.
12. As an orchestrator on the work host, I want a Pi worker on opus to get a Pi reviewer on gpt, so that review crosses families with the agents the host has.
13. As an orchestrator on the work host, I want Copilot as the last reviewer kind, so that it covers a Pi outage.
14. As an orchestrator, I want each kind to start on its CLI's default model, so that the start script stays free of model choices.
15. As an orchestrator, I want to switch a Pi or Copilot reviewer's model in its session when its default matches the worker's family, so that the family rule holds.
16. As an orchestrator, I want `start-worker.sh --kind agy` to start agy with its first prompt, so that an agy reviewer works its review bead.
17. As an orchestrator, I want `start-worker.sh --kind copilot` to start Copilot with its first prompt, so that a Copilot reviewer works its review bead.
18. As an orchestrator, I want `start-worker.sh --resume` for agy and Copilot, so that a reviewer keeps its session across revival.
19. As an orchestrator, I want `send-reinstruction.sh` to revive a finished agy or Copilot reviewer from its resume label, so that round 2 and the bot-review fallback reach the same session.
20. As an orchestrator, I want agent-quirks sections for agy and Copilot, so that I can answer their startup dialogs and switch models.
21. As a user, I want an agy or Copilot terminal in herdr labelled with its resume line, so that its session can be resumed.
22. As a user, I want the resume hook to do nothing outside herdr, so that agy and Copilot behave the same in a plain shell.
23. As a user, I want the agy hook installed by Home Manager, so that no manual plugin install is needed.
24. As a user, I want the Copilot hook passed per launch by the shim, so that nothing is installed into Copilot.
25. As a maintainer, I want fixture tests for the chain script, the new launch and revival paths, and the hook scripts, so that regressions fail offline.

## Implementation Decisions

- **Chain script (new, skill).** `reviewers.sh [--visual] [--not <family>] [--refresh]` prints one eligible reviewer per line, in chain order, as `<kind> <family>`. The family is `claude`, `gpt` or `gemini` for a fixed-family kind and `any` for Pi and Copilot. `--not` drops fixed-family kinds of that family. The script now lives in the `swarm-mind` skill and owns the two chain orders and the kind-to-family table; it does not know the user's quota state.
- **Families.** The worker's family comes from its current model: `gpt` when the model ID contains `gpt`, `gemini` when it contains `gemini`, otherwise `claude`. This matches pi-config's model-family detection. A Claude, Codex or agy worker has its kind's family; for Pi or Copilot, the orchestrator reads the model from the worker's status line.
- **Cache.** The cache lives under `$XDG_RUNTIME_DIR` (fallback `~/.cache`), never in shared `/tmp`. It holds a checksum of PATH and the installed kinds. A PATH mismatch or `--refresh` re-probes with `command -v`. The write is atomic.
- **Launch.** `start-worker.sh` starts agy and Copilot with `-i <prompt>`, so they stay interactive. The resume flag goes before `-i`: agy `--conversation=<id>`, Copilot `--resume=<id>`. No `--model` flag is added.
- **Revival.** `send-reinstruction.sh` parses `agy … --conversation[= ]<id>` and `copilot … --resume[= ]<id>` from the `resume` label, like the Pi and Claude forms.
- **Resume hooks (nix-config, herdr-app).** Both hooks exit at once without `HC_TERMINAL_ID`, and label only from the terminal's own foreground agent, as the Codex hook does.
  - agy has no per-launch plugin flag. Home Manager links a plugin (`plugin.json` plus root `hooks.json`) into agy's plugins folder when agy is enabled. Its SessionStart hook reads `conversationId` from stdin and labels `resume=agy --conversation=<id>`. Probed: the agy hook schema is `{"<name>":{"SessionStart":[{"type":"command","command":…}]}}`, its input carries `conversationId`, and agy finds symlinked plugin files.
  - Copilot reads Claude-compatible plugin hooks. The `copilot` shim adds `--plugin-dir` for a plugin with a `.claude-plugin/plugin.json` manifest. Its SessionStart hook reads `session_id` and labels `resume=copilot --resume=<id>`. Probed: `--plugin-dir` finds the plugin only with the manifest.
- **Docs.** `swarm-mind` states the pick rules and owns `reviewers.sh`; supervise.md step 2 points to both; the Steering quota rule moves a reviewer to the next kind; the SKILL.md house rule points to the chain; agent-quirks.md gains `## agy` and `## copilot`; preflight.md names the agy and Copilot prompts.

## Testing Decisions

- Tests check behavior through the scripts' command-line contracts only.
- `swarm-mind/tests/check.sh` (moved from this skill): `reviewers.sh` against a fake PATH of dummy agents (chain order, `--visual`, `--not`, cache reuse, PATH-change refresh, `--refresh`); this skill's `tests/check.sh`: `start-worker.sh` argv for agy and Copilot, fresh and resumed; `send-reinstruction.sh` revival from agy and Copilot resume labels. Prior art: the existing kind loop, the Pi and Claude `--resume` checks, and the hibernated revival loop.
- `tests/session-integrations.mjs` (nix-config): agy and Copilot hooks label the resume line with a fake `hc`, and do nothing outside herdr. Prior art: the Claude and Codex cases.

## Out of Scope

- Compaction recovery for agy and Copilot. The hooks only set the resume label; the `orch-context` re-injection stays with Claude and Pi.
- Reboot recovery and hibernation in panda-focus for agy and Copilot. herdr does not detect them as agents (`hc get` shows `agent: null`).
- Codex revival. `codex.sh` sets a resume label that `send-reinstruction.sh` does not parse; that is a separate fix.
- A `--model` flag on `start-worker.sh`.

## Further Notes

- Not yet probed: whether `hc` tracks Copilot's status, whether Copilot's SessionStart fires with Claude field names, and Copilot's in-session model switch. These need a Copilot login on the work host.
