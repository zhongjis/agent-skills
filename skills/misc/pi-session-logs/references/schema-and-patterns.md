# Pi Session Schema and Analysis Patterns

This reference covers Pi 1.4's v3 format. Consult the official [session format][1] and [message types][2] for the complete current schema; bundled scripts intentionally produce audit history rather than replaying the SDK's model context.

## Entries and messages

A session is JSONL. The first record is metadata:

```json
{"type":"session","version":3,"id":"session-uuid","timestamp":"2026-10-24T00:00:00.000Z","cwd":"/path/to/project"}
```

The header's `id` identifies the session; it is not a tree-entry ID. It has no `parentId`. Other entries have an entry `id`, nullable `parentId`, and ISO timestamp. A root has `parentId: null`. Message timestamps inside `.message` are Unix milliseconds, not ISO strings.[1][2]

```json
{"type":"message","id":"entry1","parentId":null,"timestamp":"2026-10-24T00:00:01.000Z","message":{"role":"user","content":"Hello","timestamp":1792800001000}}
```

Current entry types include `message`, `model_change`, `thinking_level_change`, `usage`, `compaction`, `context_edit`, `branch_summary`, `custom`, `custom_message`, `label`, and `session_info`. Consumers should preserve the distinction between a session entry and its nested message.[1]

Important message shapes:[2]

| Role | Content or payload |
|------|--------------------|
| `system` | String or text-block array; optional `sections`, `toolsAdded`, `toolsRemoved` describe prompt/tool changes |
| `user` | String or text/image-block array |
| `assistant` | Text/thinking/tool-call array; model/provider, usage, stop reason, optional diagnostics/error metadata |
| `toolResult` | Text/image-block array; `toolCallId`, `toolName`, `isError`, optional `details`, `usage`, `nestedCalls` |
| `bashExecution` | `command`, `output`, optional `exitCode`, `cancelled`, `truncated`; optional output path/context-exclusion fields |
| `custom` | String or text/image-block array plus extension metadata |
| `branchSummary` / `compactionSummary` | Summary payload; Pi constructs these context messages from summary entries |

`bashExecution` is `.message.role`, not an entry's top-level role. Assistant `arguments` are objects in the current official `toolCall` shape. Some imported logs use JSON-encoded strings, so bundled extractors normalize that representation.[2]

Text, thinking, and tool-call blocks can carry provider metadata such as signatures or a tool namespace. Treat signatures as opaque. Never print image `data` merely to identify a message. Thinking can be redacted; its visible character count is not a token count.[2]

## Usage and errors

Assistant messages always carry usage. Optional usage also appears on tool-result messages, `usage` entries, and compaction/branch-summary entries. All contribute to full-session totals.[1][2]

```json
{"input":10,"output":20,"cacheRead":30,"cacheWrite":40,"totalTokens":100,"cost":{"input":0.1,"output":0.2,"cacheRead":0.3,"cacheWrite":0.4,"total":1}}
```

Use recorded `totalTokens` and `cost.total`. Optional `reasoning` is already part of `output`; `cacheWrite1h` is a subset of `cacheWrite`, so neither should be added again.[2]

Keep whole-file accounting separate from branch-local context. Counting assistant messages does not count user turns. Requested `.model` can differ from optional `.responseModel`; `.model_change.modelId` describes the selected model, which may be virtual.[1][2]

Provider failures can be assistant messages with `stopReason: "error"` or `"aborted"`, `errorMessage`, and `diagnostics`; they are not necessarily failed tool results. A Bash exit-code phrase inside text is not a structured status. Tool results and nested-call records provide separate error evidence.[2]

## Nested tools

Tool results can record bounded metadata:[2]

```json
{"nestedCalls":{"calls":[{"id":"nested1","name":"write","arguments":{"path":"src/example.ts"},"status":"ok","durationMs":12}],"complete":true}}
```

`complete: false` means the call list is incomplete. Individual records can omit arguments and retain `argumentsBytes` instead. A nested record's `status`, `error`, and duration are not a full tool-result body or exact start/end timestamp. Report these limits rather than inferring missing calls from JavaScript or shell text.[2]

Direct tool results associate with assistant tool calls through `toolCallId`; matching by tool name alone can pair the wrong invocation. For files/delegations/tasks, use the bundled scripts so direct and recorded nested calls share one extraction policy.

## History, branches, and model context

Append order is not one conversation path. A new entry can point to an earlier parent, creating a branch. `pi-session-thread.sh --leaf ID` selects a root-to-entry history path; its default output covers the full file.[1]

Compaction does **not** delete earlier records. `firstKeptEntryId` identifies the retained range during context building; the latest compaction on the selected path supplies a summary and optional system checkpoint.[1]

A `context_edit` affects future model context on its branch. `replacement: null` omits the target; non-null replacements change its context content. Original history, UI/export content, and accounting remain unchanged. Multiple edits to a target use the latest edit on the active branch.[1]

The thread script displays context-edit and summary events without applying them to earlier text. For the exact model-visible conversation, use Pi's `SessionManager` context/projection APIs with the selected leaf. A plain concatenation of message records is not equivalent.[1]

`custom` entries persist extension state without entering model context. `custom_message` entries can enter context; their `display` flag only controls terminal rendering. Names such as `agent-mode` or `subagents:record` and their payloads belong to extensions, not Pi's universal schema.[1]

## Safe jq fallbacks

Use these only when no bundled script covers the task. Pass patterns as `--arg` values, not interpolated jq source. Keep parse errors visible.

### User text only

```bash
jq -r 'select(.type == "message" and .message.role == "user") |
  .message.content |
  if type == "string" then .
  elif type == "array" then map(select(.type == "text") | .text) | join("\n")
  else "" end' "$SESSION"
```

### Direct tool calls with entry timestamps

This intentionally excludes nested calls; use `pi-session-toolcalls.sh` for both.

```bash
jq -c 'select(.type == "message" and .message.role == "assistant") |
  .timestamp as $ts |
  .message.content[] | select(.type == "toolCall") |
  {turn_ts: $ts, name, namespace, arguments}' "$SESSION"
```

jq has no implicit `parent` accessor. Bind the outer entry before descending.

### Full recorded usage totals

```bash
jq -s '
  [.[] |
    if .type == "message" and (.message.role == "assistant" or .message.role == "toolResult") then .message.usage
    elif .type == "usage" or .type == "compaction" or .type == "branch_summary" then .usage
    else empty end |
    select(. != null)] |
  {tokens: (map(.totalTokens // 0) | add // 0),
   cost: (map(.cost.total // 0) | add // 0)}' "$SESSION"
```

### Literal text search across user messages

```bash
jq -r --arg needle 'a phrase with "quotes"' '
  select(.type == "message" and .message.role == "user") |
  (.message.content | if type == "string" then . else map(select(.type == "text") | .text) | join("\n") end) |
  select(contains($needle))' "$SESSION"
```

## Session locations and size

Default location: `~/.pi/agent/sessions/--<encoded-cwd>--/<timestamp>_<session-id>.jsonl`. Encoding removes the leading path separator and replaces `/`, `\`, and `:` with `-`. Ordinary hyphens make decoding ambiguous; read `.cwd` from the header instead.[1]

Do not assume a maximum session size. The scripts use jq and some operations load the full file, so memory grows with history. For unusually large logs, select the needed session/extraction and inspect output limits; do not truncate JSONL arbitrarily or mistake an output preview for complete data.

## Sources

[1] [Official Pi session format](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/session-format.md)
[2] [Official Pi message types](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/message-types.md)

[1]: https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/session-format.md
[2]: https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/message-types.md
