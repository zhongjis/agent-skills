#!/usr/bin/env bash
# Usage: watch-agent.sh <agent>
# Wait for idle/done/blocked, then check again after 30 seconds.
set -euo pipefail

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
	printf 'usage: watch-agent.sh <agent>\n' >&2
	exit 1
fi

name="$1"
while true; do
	wait_status=0
	herdr agent wait "$name" --until idle --until blocked --until 'done' >/dev/null || wait_status=$?
	if [ "$wait_status" -eq 0 ]; then
		sleep 30
	fi
	if snapshot=$(herdr agent get "$name" 2>&1); then
		status=$(jq -er '.result.agent.agent_status | select(type == "string")' <<<"$snapshot")
	else
		if jq -e '.error.code == "agent_not_found"' <<<"$snapshot" >/dev/null 2>&1; then
			printf 'agent %s: gone\n' "$name"
			exit 0
		fi
		printf '%s\n' "$snapshot" >&2
		exit 1
	fi
	if [ "$wait_status" -ne 0 ]; then
		printf 'agent %s: wait failed; status=%s\n' "$name" "$status" >&2
		exit "$wait_status"
	fi
	case "$status" in
		idle|done|blocked) printf 'agent %s settled: %s\n' "$name" "$status"; exit 0 ;;
		working|unknown) continue ;;
		*) printf 'agent %s: unexpected status %s\n' "$name" "$status" >&2; exit 1 ;;
	esac
done
