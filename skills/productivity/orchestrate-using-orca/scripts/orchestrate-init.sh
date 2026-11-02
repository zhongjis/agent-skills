#!/usr/bin/env bash
# Start an orchestration: verify Orca, mark this terminal "[o] ...", print the log path.
# Usage: orchestrate-init.sh <slug>
set -euo pipefail

if [ "$#" -ne 1 ]; then
	printf 'usage: orchestrate-init.sh <slug>\n' >&2
	exit 1
fi

if ! command -v orca >/dev/null || [ -z "${ORCA_TERMINAL_HANDLE:-}" ]; then
	printf 'not inside Orca\n' >&2
	exit 1
fi

label="$(orca terminal show --terminal "$ORCA_TERMINAL_HANDLE" --json | jq -r '.result.terminal.title // ""')"
case "$label" in
	'[o]'*) ;;
	'') orca terminal set-pane-title --terminal "$ORCA_TERMINAL_HANDLE" --title "[o] $1" >/dev/null ;;
	*) orca terminal set-pane-title --terminal "$ORCA_TERMINAL_HANDLE" --title "[o] $label" >/dev/null ;;
esac

# One log per orchestrator terminal, outside every repo: a later invocation
# from the same terminal appends to the same log. Handles are runtime-scoped,
# so a restarted Orca starts a new log.
dir="${XDG_STATE_HOME:-$HOME/.local/state}/orchestrate-using-orca"
mkdir -p "$dir"
printf 'log=%s/%s.tsv\n' "$dir" "$(printf '%s' "$ORCA_TERMINAL_HANDLE" | tr -c 'A-Za-z0-9_.-' '-')"
