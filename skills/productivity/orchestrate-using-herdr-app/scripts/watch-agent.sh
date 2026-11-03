#!/usr/bin/env bash
# Usage: watch-agent.sh <agent>
# Wait until the agent stops working, then check again after 30 seconds.
set -euo pipefail

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
	printf 'usage: watch-agent.sh <agent>\n' >&2
	exit 1
fi

name="$1"
while true; do
	wait_status=0
	out=$(hc wait "$name" --json --timeout 600 2>&1) || wait_status=$?
	if [ "$wait_status" -eq 0 ] && [ "$(jq -r '.reason' <<<"$out")" != timeout ]; then
		sleep 30
	fi
	get_status=0
	snapshot=$(hc get "$name" --json 2>&1) || get_status=$?
	if [ "$get_status" -eq 3 ]; then
		printf 'agent %s: gone\n' "$name"
		exit 0
	fi
	if [ "$get_status" -ne 0 ]; then
		printf '%s\n' "$snapshot" >&2
		exit "$get_status"
	fi
	fields=$(jq -er '[.state, (.status.state // "none")] | @tsv' <<<"$snapshot")
	IFS=$'\t' read -r state status <<<"$fields"
	if [ "$state" != live ]; then
		printf 'agent %s: terminal %s\n' "$name" "$state"
		exit 0
	fi
	if [ "$wait_status" -ne 0 ]; then
		printf 'agent %s: wait failed; status=%s\n%s\n' "$name" "$status" "$out" >&2
		exit "$wait_status"
	fi
	case "$status" in
		idle|done|blocked|error) printf 'agent %s settled: %s\n' "$name" "$status"; exit 0 ;;
		working|none) continue ;;
		*) printf 'agent %s: unexpected status %s\n' "$name" "$status" >&2; exit 1 ;;
	esac
done
