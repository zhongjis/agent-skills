#!/usr/bin/env bash
# Start an orchestration: verify this agent runs inside T3 Code with the t3
# CLI, then print the log path for the orchestrator thread.
# Usage: orchestrate-init.sh <orchestrator-thread-id>
set -euo pipefail

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
	printf 'usage: orchestrate-init.sh <orchestrator-thread-id>\n' >&2
	exit 1
fi

t3="${T3CODE_CLI_PATH:-t3}"
if [ -z "${T3_MCP_URL:-}" ] || ! command -v "$t3" >/dev/null; then
	printf 'not inside T3 Code, or the t3 CLI is missing\n' >&2
	exit 1
fi

# One log per orchestrator thread, outside every repo: a later invocation
# from the same thread appends to the same log.
dir="${XDG_STATE_HOME:-$HOME/.local/state}/orchestrate-using-t3code"
mkdir -p "$dir"
printf 'log=%s/%s.tsv\n' "$dir" "$(printf '%s' "$1" | tr -c 'A-Za-z0-9_.-' '-')"
