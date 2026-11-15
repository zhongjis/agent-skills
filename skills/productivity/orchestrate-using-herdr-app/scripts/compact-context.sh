#!/usr/bin/env bash
# Print the orchestrator state that a context compaction drops: the latest mode
# row (flags, limits) and the per-task table, with an instruction to re-read the
# skill. orchestrate-init.sh labels the orchestrator's terminal `orch-context=<this
# script's absolute path>`; the herdr-app session integrations run it after a
# compaction and inject its output.
# Usage: compact-context.sh [<logfile>]  (default: this terminal's log, as orchestrate-init.sh names it)
# Prints nothing and exits 0 when the log is missing; never fails a session start.
set -uo pipefail

dir="${XDG_STATE_HOME:-$HOME/.local/state}/orchestrate-using-herdr-app"
log="${1:-$dir/$(printf '%s' "${HC_TERMINAL_ID:-}" | tr -c 'A-Za-z0-9_.-' '-').tsv}"
[ -n "$log" ] && [ -s "$log" ] || exit 0
here="$(dirname -- "${BASH_SOURCE[0]}")"
mode=$(awk -F'\t' '$2 == "orchestrator" && $3 == "mode" { row = $4 } END { print row }' "$log")
case "$mode" in *flags=--off*) exit 0 ;; esac
table=$("$here/status.sh" "$log" --live 2>/dev/null || "$here/status.sh" "$log" 2>/dev/null)
printf 'Orchestrator mode ON (orchestrate-using-herdr-app). Latest mode row: %s\n' "${mode:-none}"
printf 'Re-read the orchestrate-using-herdr-app SKILL.md and the references your flags need now, then act from this table, not from the compaction summary. Log: %s\n\n' "$log"
printf '%s\n' "$table"
