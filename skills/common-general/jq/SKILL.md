---
name: jq
description: Extract specific fields from JSON files efficiently using jq instead of reading entire files, saving 80-95% context.
upstream: https://github.com/benchflow-ai/skillsbench/tree/47e9ce24f24dfe2c53bd8437d4f2eb54d715490b/registry/terminal_bench_2.0/full_batch_reviewed/terminal_bench_2_0_build-pmars/environment/skills/jq
---

# jq: JSON Data Extraction Tool

Use jq to extract specific fields from JSON files without loading entire file contents into context. For JSONL/pi logs, use the copy-safe templates below; the main skill has enough guidance, so do not load the detailed reference unless needed.

## When to Use jq vs Read

**Use jq when:**

- Need specific field(s) from structured data file
- File is large (>50 lines) and only need subset
- Querying nested structures
- Filtering/transforming data
- **Saves 80-95% context** vs reading entire file

**Just use Read when:**

- File is small (<50 lines)
- Need to understand overall structure
- Making edits (need full context anyway)

## Common File Types

JSON/JSONL files where jq excels:

- package.json, tsconfig.json
- Lock files (package-lock.json, yarn.lock in JSON format)
- API responses
- Configuration files
- JSONL logs, including pi session logs (`*.jsonl`)

## JSONL / Pi Session Logs
For newline-delimited JSON, jq runs the filter once per line. Do **not** use top-level `.[]` unless each line is an array.

Fast path: start with 1-3 jq commands, not repeated trial-and-error. Batch related fields in one jq command. For logs, truncate big text inside jq before printing (user text ~1200 chars, errors ~500).

Syntax tripwire: optional/default operators need spaces or parentheses. Write `.role? // null`, **never** `.role?//null` (`?//` is a jq syntax error).

Copy-safe templates:
```bash
# Record type counts
jq -r '.type' session.jsonl | sort | uniq -c

# First 5 records / structure; safe under pipefail
jq -c 'limit(5; {type: (.type // null), timestamp: (.timestamp // null), id: (.id // null), role: (.message.role? // null), content_type: (.message.content? | type), keys})' session.jsonl

# User prompts; content may be null/string/array
jq -r 'def text: (.message.content // []) | if type == "array" then map(.text? // empty) | join(" ") else tostring end; select(.message.role == "user") | [.timestamp, .id, (text[0:1200])] | @tsv' session.jsonl

# Failed tool results
jq -r 'def text: (.message.content // []) | if type == "array" then map(.text? // empty) | join(" ") else tostring end; select(.message.role == "toolResult" and .message.isError == true) | [.timestamp, .message.toolName, (text[0:500])] | @tsv' session.jsonl

# User prompts + failures in one chronological stream; enough for most task-list summaries
jq -r 'def text: (.message.content // []) | if type == "array" then map(.text? // empty) | join(" ") else tostring end; if .message.role == "user" then ["USER", .timestamp, .id, (text[0:1200])] elif (.message.role == "toolResult" and .message.isError == true) then ["FAIL", .timestamp, .message.toolName, (text[0:500])] else empty end | @tsv' session.jsonl
```

Pitfalls:
- Heterogeneous logs: use `(.field // [])[]?`; keep arrays as arrays until final `join`.
- Under `set -o pipefail`, avoid `jq ... | head`; use `limit(n; expr)` inside jq.
- Optional defaults need spaces/parentheses: `(.message.role? // null)` or `(.message | keys? // [])`, never `role?//null` or `keys?//[]`.
- jq `def clean: ...` defines a filter. Call it as `(.message.content | clean)`, not `clean(.message.content)`.
- Prefer normal `jq 'filter' file.jsonl`; avoid `jq -n inputs` unless you truly need cross-line state. If using `jq -n 'inputs as $x | ...'`, run helpers on `$x` (`$x | text`), not on the loop counter or current state.
- Avoid `gsub` cleanup unless output is unreadable; truncation is usually enough and keeps filters simpler.
## Quick Examples

```bash
# Get version from package.json
jq -r .version package.json

# Get nested dependency version
jq -r '.dependencies.react' package.json

# List all dependencies
jq -r '.dependencies | keys[]' package.json
```

## Core Principle

Extract exactly what is needed in one command - massive context savings compared to reading entire files.

## Detailed Reference

For comprehensive jq patterns, syntax, and examples, load [jq guide](./reference/jq-guide.md):

- Core patterns (80% of use cases)
- Real-world workflows
- Advanced patterns
- Pipe composition
- Error handling
- Integration with other tools
