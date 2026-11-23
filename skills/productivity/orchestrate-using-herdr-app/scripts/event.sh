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
# Shared fields are checked here, not left to prose a long-lived session may hold stale.
require() {
	local field
	for field in "${fields[@]}"; do [[ $field =~ ^$1$ ]] && return 0; done
	printf '%s needs %s\n' "$event" "$2" >&2
	exit 1
}
item='(browser|compose|processes|worker|reviewer|worktree|branch|remote-branch|none)'
case "$event" in
	merged) require 'merged_sha=[0-9a-f]{40}' 'merged_sha=<40-hex sha>' ;;
	settled) require 'result=(succeeded|abandoned|failed|blocked|uncertain)' 'result=succeeded|abandoned|failed|blocked|uncertain' ;;
	reaped) require "stopped=$item(,$item)*" 'stopped=<comma list of browser,compose,processes,worker,reviewer,worktree,branch,remote-branch, or none>' ;;
esac
[ -n "${HC_TERMINAL_ID:-}" ] || { printf 'event.sh needs HC_TERMINAL_ID\n' >&2; exit 1; }
[ -z "$body" ] || comment+=$'\n\n'"$body"
bd comments add "$bead" "$comment" --actor "o-$HC_TERMINAL_ID"
# Metadata mirrors the event so status.sh shows it after later comments.
case "$event" in
	merged)
		for field in "${fields[@]}"; do [[ $field != merged_sha=* ]] || sha=${field#merged_sha=}; done
		bd update "$bead" --set-metadata "merged_sha=$sha" --actor "o-$HC_TERMINAL_ID" >/dev/null ;;
	blocked)
		for field in "${fields[@]}"; do
			[[ $field != reason=needs-user ]] || bd update "$bead" --set-metadata blocked_reason=needs-user --actor "o-$HC_TERMINAL_ID" >/dev/null
		done ;;
	decided)
		# The answer releases a needs-user hold; other blocked reasons stay.
		if [ "$(bd show "$bead" --json | jq -r '.[0].metadata.blocked_reason // ""')" = needs-user ]; then
			bd update "$bead" --unset-metadata blocked_reason --actor "o-$HC_TERMINAL_ID" >/dev/null
		fi ;;
esac
