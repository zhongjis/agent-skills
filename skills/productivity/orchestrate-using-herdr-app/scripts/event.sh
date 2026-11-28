#!/usr/bin/env bash
# Usage: event.sh <bead> <event> [k=v...] [--body <text>]
# Record one attributed orchestration milestone as a parseable comment.
# A field value is written bare unless it has a newline, CR or tab, starts with a
# double quote, or has a space followed by `key=`; then it is written key="<escaped>"
# with \\ \" \n \r \t escapes. `decided question=<comment id>` is refused when the id is
# empty or is not the bead's open needs-user question (an `o-` authored comment whose hold,
# recorded as blocked_question, is still set); it releases only that question's hold.
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
bs='\'
# Quote only what a reader could not split correctly as a bare value.
encode() {
	local v=$1
	if [[ $v == *[$'\n\r\t']* || $v == \"* || $v =~ ' '[a-z][a-z0-9_-]*= ]]; then
		v=${v//"$bs"/"$bs$bs"}
		v=${v//\"/"$bs\""}
		v=${v//$'\n'/"${bs}n"}
		v=${v//$'\r'/"${bs}r"}
		v=${v//$'\t'/"${bs}t"}
		printf '"%s"' "$v"
	else
		printf '%s' "$v"
	fi
}
comment="event=$event"
for field in "${fields[@]}"; do
	if ! [[ $field =~ ^[a-z][a-z0-9_-]*= ]] || [[ $field == event=* ]]; then
		printf 'invalid event field: expected k=v, got %q\n' "$field" >&2
		exit 1
	fi
	comment+=" ${field%%=*}=$(encode "${field#*=}")"
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
	merged)
		require 'merged_sha=[0-9a-f]{40}' 'merged_sha=<40-hex sha>'
		require 'pr=https?://[^[:space:]]+' 'pr=<PR URL>' ;;
	settled) require 'result=(succeeded|abandoned|failed|blocked|uncertain)' 'result=succeeded|abandoned|failed|blocked|uncertain' ;;
	ready)
		for field in "${fields[@]}"; do
			case $field in
				pr=*) [[ $field =~ ^pr=https?://[^[:space:]]+$ ]] || { printf 'ready pr= needs an http(s) URL\n' >&2; exit 1; } ;;
				head=*) [[ $field =~ ^head=[0-9a-f]{7,40}$ ]] || { printf 'ready head= needs 7-40 hex characters\n' >&2; exit 1; } ;;
			esac
		done ;;
	reaped) require "stopped=$item(,$item)*" 'stopped=<comma list of browser,compose,processes,worker,reviewer,worktree,branch,remote-branch, or none>' ;;
esac
[ -n "${HC_TERMINAL_ID:-}" ] || { printf 'event.sh needs HC_TERMINAL_ID\n' >&2; exit 1; }
# Only a question the orchestrator wrote (an `o-` author) is a question: a worker cannot pose
# as one by quoting the event.
newest_question() {
	# Strip quoted values so prose cannot pose as a field.
	bd comments "$bead" --json | jq -r '[.[] | select((.author // "") | startswith("o-")) | select(.text | split("\n")[0] | gsub(" [a-z][a-z0-9_-]*=\"(?:[^\"\\\\]|\\\\.)*\"(?= |$)"; "") | test("^event=blocked( .*)? reason=needs-user( |$)"))] | last | .id // "" | tostring'
}
# True while the needs-user hold belongs to question $1: the question recorded with the hold,
# else (a hold written before blocked_question existed) the newest question.
hold_is() {
	local reason owner
	reason=$(bd show "$bead" --json | jq -r '.[0].metadata.blocked_reason // ""')
	[ "$reason" = needs-user ] || return 1
	owner=$(bd show "$bead" --json | jq -r '.[0].metadata.blocked_question // "" | tostring')
	[ -n "$owner" ] || owner=$(newest_question)
	[ "$owner" = "$1" ]
}
question=
have_question=
if [ "$event" = decided ]; then
	for field in "${fields[@]}"; do
		[[ $field != question=* ]] || { question=${field#question=}; have_question=1; }
	done
	if [ -n "$have_question" ]; then
		[ -n "$question" ] || { printf 'decided question= needs a comment id\n' >&2; exit 1; }
		hold_is "$question" || {
			printf 'stale answer: question %s is not the open question on %s\n' "$question" "$bead" >&2
			exit 1
		}
	fi
fi
[ -z "$body" ] || comment+=$'\n\n'"$body"
bd comments add "$bead" "$comment" --actor "o-$HC_TERMINAL_ID"
# Metadata mirrors the event so status.sh shows it after later comments.
case "$event" in
	merged)
		for field in "${fields[@]}"; do [[ $field != merged_sha=* ]] || sha=${field#merged_sha=}; done
		bd update "$bead" --set-metadata "merged_sha=$sha" --actor "o-$HC_TERMINAL_ID" >/dev/null ;;
	ready)
		meta=()
		for field in "${fields[@]}"; do
			case $field in
				pr=*) meta+=(--set-metadata "pr_url=${field#pr=}") ;;
				head=*) meta+=(--set-metadata "head_sha=${field#head=}") ;;
			esac
		done
		[ "${#meta[@]}" -eq 0 ] || bd update "$bead" "${meta[@]}" --actor "o-$HC_TERMINAL_ID" >/dev/null ;;
	blocked)
		for field in "${fields[@]}"; do
			[[ $field != reason=needs-user ]] || {
				# Record which question the hold belongs to, so only its answer releases it.
				first=${comment%%$'\n'*}
				qid=$(bd comments "$bead" --json | jq -r --arg a "o-$HC_TERMINAL_ID" --arg f "$first" '[.[] | select(.author == $a and (.text | split("\n")[0]) == $f)] | last | .id // "" | tostring')
				meta=(--set-metadata blocked_reason=needs-user)
				[ -z "$qid" ] || meta+=(--set-metadata "blocked_question=$qid")
				bd update "$bead" "${meta[@]}" --actor "o-$HC_TERMINAL_ID" >/dev/null
			}
		done ;;
	decided)
		# The answer releases a needs-user hold; other blocked reasons stay. With question=, only
		# the hold of that question, re-checked now: a newer question's hold stays.
		if [ -n "$have_question" ]; then
			if hold_is "$question"; then
				bd update "$bead" --unset-metadata blocked_reason --unset-metadata blocked_question --actor "o-$HC_TERMINAL_ID" >/dev/null
			else
				printf 'decided recorded; the needs-user hold of a newer question on %s stays\n' "$bead" >&2
			fi
		elif [ "$(bd show "$bead" --json | jq -r '.[0].metadata.blocked_reason // ""')" = needs-user ]; then
			bd update "$bead" --unset-metadata blocked_reason --unset-metadata blocked_question --actor "o-$HC_TERMINAL_ID" >/dev/null
		fi ;;
esac
