#!/usr/bin/env bash
# Usage: status.sh <logfile> [--live]
# One Markdown row per task stem, combining w-/r- agent and task log rows.
# Worker names/terminals come from the latest w- dispatch; all/note rows are counted.
# --live adds hc state using the worker's dispatched terminal.
# Exit nonzero on unreadable logs or hc errors other than missing terminals (gone).
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ] || { [ "$#" -eq 2 ] && [ "$2" != --live ]; }; then
	printf 'usage: status.sh <logfile> [--live]\n' >&2
	exit 1
fi
live="${2:-}"
summary=$(jq -Rn '
	def terminal: [.evidence | scan("(?:^|[[:space:]])terminal=([^[:space:]]+)") | .[0]] | first;
	reduce (inputs | split("\t") | select(.[0] != "ts") |
		{ts: .[0], task: .[1], event: .[2], evidence: .[3], result: .[4]}) as $row
		({order: [], tasks: {}, workers: {}, notes: 0};
		if $row.task == "all" and $row.event == "note" then .notes += 1
		elif $row.task == "orchestrator" and $row.event == "mode" then .
		else
			($row.task | sub("^[wr]-"; "")) as $task |
			if .tasks[$task] == null then .order += [$task] else . end |
			.tasks[$task] = ($row + {task: $task}) |
			if $row.event == "dispatched" and ($row.task | startswith("w-"))
			then .workers[$task] = {name: $row.task, terminal: ($row | terminal)} else . end
		end) |
	. as $summary |
	{notes, rows: [.order[] as $task | .tasks[$task] |
		. + {worker: ($summary.workers[$task].name // ""), terminal: $summary.workers[$task].terminal}]}
' < "$1")
printf '| Task | Worker | Event | Result | Evidence | Since |'
[ -z "$live" ] || printf ' Live |'
printf '\n| --- | --- | --- | --- | --- | --- |'
[ -z "$live" ] || printf ' --- |'
printf '\n'
while IFS= read -r row; do
	state=
	if [ -n "$live" ]; then
		terminal=$(jq -r '.terminal // empty' <<<"$row")
		if [ -n "$terminal" ]; then
			code=0
			snapshot=$(hc get "$terminal" --json 2>&1) || code=$?
			if [ "$code" -eq 3 ]; then
				state=gone
			elif [ "$code" -ne 0 ]; then
				printf '%s\n' "$snapshot" >&2
				exit "$code"
			else
				state=$(jq -r '.status.state // .state' <<<"$snapshot")
			fi
		fi
	fi
	jq -r --arg live "$live" --arg state "$state" '
		[.task, (.worker + (if .terminal == null then "" else " (" + .terminal + ")" end)),
			.event, .result, .evidence, .ts] + (if $live == "" then [] else [$state] end) |
		"| " + (map(gsub("\\|"; "&#124;")) | join(" | ")) + " |"
	' <<<"$row"
done < <(jq -c '.rows[]' <<<"$summary")
printf '\n%s notes (all).\n' "$(jq -r '.notes' <<<"$summary")"
