# Claude Code session schema and jq patterns

Observed on Claude Code 2.1.x session files. Anthropic publishes no session-format contract; check the `version` field and re-verify shapes when a report looks wrong.

## Layout

```
~/.claude/projects/<encoded-cwd>/<sessionId>.jsonl
~/.claude/projects/<encoded-cwd>/<sessionId>/subagents/agent-<agentId>.jsonl
~/.claude/projects/<encoded-cwd>/<sessionId>/subagents/agent-<agentId>.meta.json
~/.claude/projects/<encoded-cwd>/<sessionId>/tool-results/…   # large tool outputs persisted to disk
```

`CLAUDE_CONFIG_DIR` replaces `~/.claude`. `<encoded-cwd>` replaces each non-alphanumeric character with `-`.

## Entries

One JSON object per line, discriminated by `type`. Conversation entries carry `uuid`, `parentUuid`, `timestamp`, `sessionId`, `cwd`, `gitBranch`, `version`, and `isSidechain`; subagent entries also carry `agentId`.

| `type` | Meaning |
| --- | --- |
| `user` | Human prompt, command, injected text, skill body, compaction summary, or tool results |
| `assistant` | One content block of one API response |
| `system` | `subtype`: `compact_boundary`, `turn_duration`, `stop_hook_summary`, `away_summary`, `local_command`, `informational`, … |
| `ai-title` | Generated session title in `.aiTitle`; repeated, latest wins |
| `cost-state` | Running totals: `totalCostUSD`, `totalDuration`, `modelUsage.<model>` |
| `attachment`, `api-request*`, `mode`, `permission-mode`, `last-prompt`, `file-history-*`, `queue-operation`, `pr-link`, … | Harness bookkeeping |

### Assistant lines

Claude Code writes one line per content block (`thinking`, `text`, `tool_use`). Lines of one response share `message.id` and `requestId` and repeat the same `message.usage`. Sum usage once per `message.id`.

API failures are assistant lines with `isApiErrorMessage: true`, `error` (`rate_limit`, `server_error`, …), and `message.model == "<synthetic>"`; their usage is not real.

### User lines

`message.content` is a string or an array. Classify in this order:

1. `isCompactSummary: true`: summary written after compaction.
2. `isMeta: true`: injected skill body or context (`Base directory for this skill: …`).
3. Text starting `[Request interrupted by user`: interrupt marker.
4. Array containing `tool_result` blocks: tool results.
5. String starting `<command-message>`, `<command-name>`, or `<bash-input>`: slash or `!` command typed by the human. Arguments sit in `<command-args>`.
6. String starting with another tag (`<task-notification>`, `<local-command-caveat>`, `<local-command-stdout>`, `<system-reminder>`, …): harness-injected.
7. Anything else: human prompt. Pasted images appear as `image` blocks.

### Tool results

The `tool_result` block (`tool_use_id`, `is_error`, `content` as string or `text`/`image` blocks) is what the model saw. The entry-level `toolUseResult` is structured tool metadata and varies by tool:

- Bash: `{stdout, stderr, interrupted, isImage, noOutputExpected}`; a failed command may be a plain string `"Error: Exit code N…"`.
- Agent: `{agentId, status, isAsync, description, prompt, outputFile, resolvedModel, …}`.
- Skill: `{commandName, success}`.

Large outputs appear as `<persisted-output>` with a path under `<sessionId>/tool-results/`.

### Subagent meta

`agent-<id>.meta.json`: `{agentType, description, toolUseId, spawnDepth, requestShape, finished, …}`. `toolUseId` joins to the parent's Agent `tool_use.id`.

### Compaction

`system` line with `subtype: "compact_boundary"`, `parentUuid: null`, `logicalParentUuid` pointing at the pre-compaction tail, and `compactMetadata: {trigger, preTokens, postTokens, durationMs, …}`. The following user line with `isCompactSummary` holds the summary. Earlier entries stay in the file.

## jq patterns

```bash
# Last N human prompts without the scripts
jq -r 'select(.type=="user" and (.message.content|type)=="string" and (.isMeta|not)
  and (.isCompactSummary|not) and (.message.content|test("^\\s*<")|not)) | "\(.timestamp) \(.message.content[:200])"' "$SESSION" | tail -n 10

# Usage per model, once per message
jq -s '[.[] | select(.type=="assistant" and .message.model != "<synthetic>")]
  | group_by(.message.id) | map(last) | group_by(.message.model)
  | map({model: .[0].message.model, output: (map(.message.usage.output_tokens // 0) | add)})' "$SESSION"

# Tool result for one tool_use id
jq -c --arg id toolu_X 'select(.type=="user") | .message.content | arrays | .[]
  | select(.type=="tool_result" and .tool_use_id==$id)' "$SESSION"
```
