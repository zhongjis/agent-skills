#!/usr/bin/env bash
# Start an orchestration: verify this runs in an hc terminal, print the log path.
# Usage: orchestrate-init.sh <slug>
set -euo pipefail

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
	printf 'usage: orchestrate-init.sh <slug>\n' >&2
	exit 1
fi

if ! command -v hc >/dev/null || [ -z "${HC_TERMINAL_ID:-}" ]; then
	printf 'not inside a herdr-core terminal (hc missing or HC_TERMINAL_ID unset)\n' >&2
	exit 1
fi

# One log per orchestrator terminal, outside every repo: a later invocation
# from the same terminal appends to the same log.
dir="${XDG_STATE_HOME:-$HOME/.local/state}/orchestrate-using-herdr-app"
mkdir -p "$dir"
log="$dir/$(printf '%s' "$HC_TERMINAL_ID" | tr -c 'A-Za-z0-9_.-' '-').tsv"
printf 'log=%s\n' "$log"
# Exporting it lets start-worker.sh and send-followup.sh log their own rows.
printf 'export ORCH_LOG=%q\n' "$log"
