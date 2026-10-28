#!/usr/bin/env bash
# Start an orchestration: verify Herdr, mark this pane "[o] ...", print the log path.
# Usage: orchestrate-init.sh <slug>
set -euo pipefail

if [ "$#" -ne 1 ]; then
	printf 'usage: orchestrate-init.sh <slug>\n' >&2
	exit 1
fi

if ! command -v herdr >/dev/null || [ "${HERDR_ENV:-}" != 1 ] || [ -z "${HERDR_PANE_ID:-}" ]; then
	printf 'not inside Herdr\n' >&2
	exit 1
fi

label="$(herdr pane get "$HERDR_PANE_ID" | jq -r '.result.pane.label // ""')"
case "$label" in
	'[o]'*) ;;
	'') herdr pane rename "$HERDR_PANE_ID" "[o] $1" >/dev/null ;;
	*) herdr pane rename "$HERDR_PANE_ID" "[o] $label" >/dev/null ;;
esac

# One log per orchestrator pane, outside every repo: a later invocation
# from the same pane appends to the same log.
dir="${XDG_STATE_HOME:-$HOME/.local/state}/orchestrate-using-herdr"
mkdir -p "$dir"
printf 'log=%s/%s.tsv\n' "$dir" "$(printf '%s' "$HERDR_PANE_ID" | tr -c 'A-Za-z0-9_.-' '-')"
