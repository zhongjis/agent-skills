#!/usr/bin/env bash
# Usage: start-worker.sh <agent> <pane> [--kind <kind>]
# Export the worker's agent-browser namespace into <pane>, then start the
# agent, retrying while the fresh pane's shell is still initializing.
# Rejects agent names outside [a-z][a-z0-9_-]{0,31}; any error other than
# agent_pane_busy (for example Claude's agent_not_ready trust dialog) is
# printed as Herdr returned it.
set -euo pipefail

usage() {
	printf 'usage: start-worker.sh <agent> <pane> [--kind <kind>]\n' >&2
	exit 1
}

[ "$#" -ge 2 ] && [ -n "$1" ] && [ -n "$2" ] || usage
name="$1"
pane="$2"
shift 2
kind=pi
while [ "$#" -gt 0 ]; do
	case "$1" in
		--kind) [ "$#" -ge 2 ] || usage; kind="$2"; shift 2 ;;
		*) usage ;;
	esac
done

if ! [[ $name =~ ^[a-z][a-z0-9_-]{0,31}$ ]]; then
	printf 'invalid agent name %s: use [a-z][a-z0-9_-]{0,31}\n' "$name" >&2
	exit 1
fi

herdr pane run "$pane" "export AGENT_BROWSER_NAMESPACE=$name" >/dev/null

for i in 1 2 3 4 5 6; do
	status=0
	out=$(herdr agent start "$name" --kind "$kind" --pane "$pane" 2>&1) || status=$?
	if [ "$status" -eq 0 ]; then
		printf '%s\n' "$out"
		exit 0
	fi
	if [[ $out == *'"code":"agent_pane_busy"'* ]]; then
		[ "$i" -lt 6 ] && sleep 4
		continue
	fi
	printf '%s\n' "$out" >&2
	exit "$status"
done
printf 'agent %s: pane %s still busy after 6 tries\n' "$name" "$pane" >&2
exit 2
