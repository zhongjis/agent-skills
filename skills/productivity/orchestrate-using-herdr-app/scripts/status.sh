#!/usr/bin/env bash
# Usage: status.sh [<epic>] [--live]
# Read one row per child task bead. Default to ORCH_EPIC or this terminal's epic.
# --live adds hc state from the latest worker dispatch, not a reviewer dispatch.
# Exit nonzero on bd errors or hc errors other than missing terminals (gone).
set -euo pipefail

epic=
live=
for arg in "$@"; do
	case "$arg" in
		--live) live=--live ;;
		-*) printf 'usage: status.sh [<epic>] [--live]\n' >&2; exit 1 ;;
		*) [ -z "$epic" ] || { printf 'usage: status.sh [<epic>] [--live]\n' >&2; exit 1; }; epic="$arg" ;;
	esac
done
epic="${epic:-${ORCH_EPIC:-}}"
if [ -z "$epic" ]; then
	[ -n "${HC_TERMINAL_ID:-}" ] || { printf 'no session epic: set ORCH_EPIC or HC_TERMINAL_ID\n' >&2; exit 1; }
	epics=$(bd list --type epic --metadata-field "session=$HC_TERMINAL_ID" --status open,in_progress,blocked,deferred --limit 0 --json)
	epic=$(jq -r '.[0].id // empty' <<<"$epics")
fi
[ -n "$epic" ] || { printf 'no session epic\n' >&2; exit 1; }
bd show "$epic" --json >/dev/null
children=$(bd list --parent "$epic" --all --limit 0 --json)
comments=$(bd comments "$epic" --json)
notes=$(jq '[.[] | select(.text | test("^event=note( |$)"))] | length' <<<"$comments")
printf '| Task | Worker | Event | Result | Evidence | Since |'
[ -z "$live" ] || printf ' Live |'
printf '\n| --- | --- | --- | --- | --- | --- |'
[ -z "$live" ] || printf ' --- |'
printf '\n'
while IFS= read -r task; do
	id=$(jq -r '.id' <<<"$task")
	comments=$(bd comments "$id" --json)
	row=$(jq -cn --argjson task "$task" --argjson comments "$comments" '
		def field($key): [scan("(?:^| )" + $key + "=([^ ]+)") | .[0]] | first;
		($comments | map(select(.text | test("^event=[a-z-]+( |$)")))) as $events |
		($events | last // {}) as $latest |
		([$events[] | select(.text | test("^event=dispatched ")) |
			{agent: (.text | field("agent")), terminal: (.text | field("terminal"))} |
			select(.agent // "" | startswith("w-"))] | last // {}) as $worker |
		{task: ($task.metadata.key // $task.id), worker: ($worker.agent // ""), terminal: $worker.terminal,
		 event: ($latest.text // "" | split("\n")[0] // "" | field("event") // ""),
		 result: $task.status, ts: ($latest.created_at // $task.created_at),
		 evidence: ([($latest.text // "" | split("\n")[0] // "" | sub("^event=[^ ]+ ?"; ""))] +
			[["pr_url", "head_sha", "merged_sha", "review_round", "blocked_reason"][] as $key |
			select($task.metadata[$key] != null) | $key + "=" + ($task.metadata[$key] | tostring)] |
			map(select(. != "")) | join(" "))}
	')
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
		"| " + (map(gsub("[\\r\\n\\t]"; " ") | gsub("\\|"; "&#124;")) | join(" | ")) + " |"
	' <<<"$row"
done < <(jq -c '.[]' <<<"$children")
printf '\n%s notes (all).\n' "$notes"
