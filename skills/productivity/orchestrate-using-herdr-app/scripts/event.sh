#!/usr/bin/env bash
# Usage: event.sh <bead> <event> [k=v...] [--body <text>]
# Record one attributed orchestration milestone as a parseable comment.
set -euo pipefail

if [ "$#" -lt 2 ] || [ -z "$1" ]; then
	printf 'usage: event.sh <bead> <event> [k=v...] [--body <text>]\n' >&2
	exit 1
fi
bead="$1"
event="$2"
shift 2
case "$event" in
	mode|ticketed|dispatched|handed-off|queued|re-instructed|ready|merged|settled|reaped|blocked|decided|note|adopted) ;;
	*) printf 'invalid event name: %s\n' "$event" >&2; exit 1 ;;
esac
body=
fields=()
while [ "$#" -gt 0 ]; do
	if [ "$1" = --body ]; then
		[ "$#" -ge 2 ] || { printf '%s\n' '--body requires text' >&2; exit 1; }
		body="$2"
		shift 2
	else
		fields+=("$1")
		shift
	fi
done
comment="event=$event"
for field in "${fields[@]}"; do
	if ! [[ $field =~ ^[a-z][a-z0-9_-]*= ]] || [[ $field == event=* || $field == *[$'\n\r\t']* ]]; then
		printf 'invalid event field: expected one-line k=v, got %q\n' "$field" >&2
		exit 1
	fi
	comment+=" $field"
done
[ -n "${HC_TERMINAL_ID:-}" ] || { printf 'event.sh needs HC_TERMINAL_ID\n' >&2; exit 1; }
[ -z "$body" ] || comment+=$'\n\n'"$body"
bd comments add "$bead" "$comment" --actor "o-$HC_TERMINAL_ID"
