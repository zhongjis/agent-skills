#!/usr/bin/env bash
# Start an orchestration: verify this runs in an hc terminal, print the log path,
# log the invocation's mode, and mark the orchestrator's tab `[o] <slug>`.
# Usage: orchestrate-init.sh <slug> [--mode <flags>]
set -euo pipefail

usage() {
	printf 'usage: orchestrate-init.sh <slug> [--mode <flags>]\n' >&2
	exit 1
}

[ "$#" -ge 1 ] && [ -n "$1" ] || usage
slug="$1"
shift
mode=none
while [ "$#" -gt 0 ]; do
	case "$1" in
		--mode) [ "$#" -ge 2 ] || usage; mode="${2:-none}"; shift 2 ;;
		*) usage ;;
	esac
done

if ! command -v hc >/dev/null || [ -z "${HC_TERMINAL_ID:-}" ]; then
	printf 'not inside a herdr-core terminal (hc missing or HC_TERMINAL_ID unset)\n' >&2
	exit 1
fi

# One log per orchestrator terminal, outside every repo: a later invocation
# from the same terminal appends to the same log.
dir="${XDG_STATE_HOME:-$HOME/.local/state}/orchestrate-using-herdr-app"
mkdir -p "$dir"
log="$dir/$(printf '%s' "$HC_TERMINAL_ID" | tr -c 'A-Za-z0-9_.-' '-').tsv"
# The latest `mode` row is the invocation's authority (for example --auto);
# recalled memory never replaces it.
"$(dirname -- "${BASH_SOURCE[0]}")/log.sh" "$log" orchestrator mode "flags=$mode slug=$slug" ok
printf 'log=%s\n' "$log"
# Exporting it lets start-worker.sh and send-followup.sh log their own rows.
printf 'export ORCH_LOG=%q\n' "$log"

# Best effort: without an open window the orchestration still runs.
if command -v herdr-app >/dev/null; then
	tab=$(herdr-app ls 2>/dev/null | jq -r --arg t "$HC_TERMINAL_ID" \
		'[.spaces[].tabs[] | select(any(.terminals[]; .terminal == $t)) | {id, name}][0] // empty | [.id, .name] | @tsv' 2>/dev/null) || tab=
	if [ -n "$tab" ]; then
		IFS=$'\t' read -r tab_id tab_name <<<"$tab"
		[[ $tab_name == '[o] '* ]] || herdr-app do tab.rename --id "$tab_id" --name "[o] $slug" >/dev/null 2>&1 || true
	fi
fi
