#!/usr/bin/env bash
# Print the session epic's latest mode and child task table after compaction.
# orchestrate-init.sh labels the terminal orch-context=<this script's path>;
# herdr-app session integrations inject this output without changing their contract.
# Usage: compact-context.sh [<epic>] (default: ORCH_EPIC or this terminal's epic)
# Silent without an epic or after --off; never fails a session start.
set -uo pipefail

epic="${1:-${ORCH_EPIC:-}}"
if [ -z "$epic" ]; then
	[ -n "${HC_TERMINAL_ID:-}" ] || exit 0
	epics=$(bd list --type epic --metadata-field "session=$HC_TERMINAL_ID" --status open,in_progress,blocked,deferred --limit 0 --json 2>/dev/null) || exit 0
	epic=$(jq -r '.[0].id // empty' <<<"$epics") || exit 0
fi
[ -n "$epic" ] || exit 0
comments=$(bd comments "$epic" --json 2>/dev/null) || exit 0
mode=$(jq -r '[.[] | .text | split("\n")[0] | select(test("^event=mode( |$)"))] | last // empty' <<<"$comments") || exit 0
[ -n "$mode" ] || exit 0
[[ " $mode " != *' flags=--off '* ]] || exit 0
here="$(dirname -- "${BASH_SOURCE[0]}")"
table=$("$here/status.sh" "$epic" --live 2>/dev/null || "$here/status.sh" "$epic" 2>/dev/null) || exit 0
printf 'Orchestrator mode ON (orchestrate-using-herdr-app). Latest mode event: %s\n' "${mode:-none}"
printf 'Re-read the orchestrate-using-herdr-app SKILL.md and the references your flags need now, then act from this table, not from the compaction summary. Epic: %s\n\n' "$epic"
printf '%s\n' "$table"
