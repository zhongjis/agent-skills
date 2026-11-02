#!/usr/bin/env bash
# Usage: watch-thread.sh <thread-id>
# Wait until the thread's latest run settles, then check again after 30 seconds.
set -euo pipefail

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
	printf 'usage: watch-thread.sh <thread-id>\n' >&2
	exit 1
fi

t3="${T3CODE_CLI_PATH:-t3}"
id="$1"
settled_once=0
while true; do
	if ! snapshot=$("$t3" thread show --json --messages 0 "$id" 2>&1); then
		if [[ $snapshot == *'is no longer available'* ]]; then
			printf 'thread %s: gone\n' "$id"
			exit 0
		fi
		printf '%s\n' "$snapshot" >&2
		exit 1
	fi
	status=$(jq -er '.thread.status | select(type == "string")' <<<"$snapshot")
	pending=$(jq -r '.thread.pendingRequestCount // 0' <<<"$snapshot")
	case "$status" in
		preparing|queued|starting|running)
			settled_once=0
			sleep 15
			;;
		idle|waiting|completed|failed|cancelled|interrupted|rolled_back)
			if [ "$settled_once" -eq 1 ]; then
				printf 'thread %s settled: %s (pending requests: %s)\n' "$id" "$status" "$pending"
				exit 0
			fi
			settled_once=1
			sleep 30
			;;
		*)
			printf 'thread %s: unexpected status %s\n' "$id" "$status" >&2
			exit 1
			;;
	esac
done
