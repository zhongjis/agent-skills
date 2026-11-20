#!/usr/bin/env bash
# Usage: event.sh <bead> <event> [k=v...]
# Record one attributed orchestration milestone as a parseable comment.
set -euo pipefail

if [ "$#" -lt 2 ] || [ -z "$1" ]; then
	printf 'usage: event.sh <bead> <event> [k=v...]\n' >&2
	exit 1
fi
bead="$1"
event="$2"
shift 2
case "$event" in
	mode|ticketed|dispatched|handed-off|queued|re-instructed|reviewed|ready|merged|settled|reaped|blocked|decided|note|adopted) ;;
	*) printf 'invalid event name: %s\n' "$event" >&2; exit 1 ;;
esac
comment="event=$event"
for field in "$@"; do
	if ! [[ $field =~ ^[a-z][a-z0-9_-]*= ]] || [[ $field == event=* || $field == *[$'\n\r\t']* ]]; then
		printf 'invalid event field: expected one-line k=v, got %q\n' "$field" >&2
		exit 1
	fi
	comment+=" $field"
done
[ -n "${HC_TERMINAL_ID:-}" ] || { printf 'event.sh needs HC_TERMINAL_ID\n' >&2; exit 1; }
bd comments add "$bead" "$comment" --actor "o-$HC_TERMINAL_ID"
