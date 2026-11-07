#!/usr/bin/env bash
# Usage: start-worker.sh <agent> <worktree> <brief-file> [--kind <kind>] [--resume <session>]
# Start the worker as a background hc terminal in <worktree>, with its own
# AGENT_BROWSER_NAMESPACE and a brief-file prompt as its first message, then confirm
# the agent took the brief. --resume continues that Pi or Claude session
# (a hibernated worker's) instead of starting a new one. The terminal is
# labelled space=<id> with the orchestrator's space, so herdr-app's spaces sidebar
# still lists it there after the orchestrator's pane closes.
# Rejects agent names outside [a-z][a-z0-9_-]{0,31}. A failed launch is
# printed as hc returned it and never retried. Exit 2: the terminal started
# but the brief is not confirmed (blocked, error, finished, or no turn after
# 60 seconds); read the screen before acting.
set -euo pipefail

usage() {
	printf 'usage: start-worker.sh <agent> <worktree> <brief-file> [--kind <kind>] [--resume <session>]\n' >&2
	exit 1
}

[ "$#" -ge 3 ] && [ -n "$1" ] && [ -n "$2" ] && [ -n "$3" ] || usage
name="$1"
worktree="$2"
brief="$3"
shift 3
kind=pi
session=
while [ "$#" -gt 0 ]; do
	case "$1" in
		--kind) [ "$#" -ge 2 ] || usage; kind="$2"; shift 2 ;;
		--resume) [ "$#" -ge 2 ] && [ -n "$2" ] || usage; session="$2"; shift 2 ;;
		*) usage ;;
	esac
done

if ! [[ $name =~ ^[a-z][a-z0-9_-]{0,31}$ ]]; then
	printf 'invalid agent name %s: use [a-z][a-z0-9_-]{0,31}\n' "$name" >&2
	exit 1
fi
[ -d "$worktree" ] || { printf 'no worktree %s\n' "$worktree" >&2; exit 1; }
[ -r "$brief" ] || { printf 'unreadable brief %s\n' "$brief" >&2; exit 1; }
# Reviewers share the worker's checkout; never inspect it mid-edit.
if [[ $name == *-review ]]; then
	worktree=$(realpath -- "$worktree")
	terminals=$(hc ls --json)
	candidates=$(jq -r '.terminals[] | select(.state == "live" and .status == "working") | select(((.name // "") | endswith("-review")) | not) | [.address, .cwd] | @tsv' <<<"$terminals")
	while IFS=$'\t' read -r address cwd; do
		[ -n "$address" ] || continue
		if [ "$(realpath -- "$cwd")" = "$worktree" ]; then
			printf 'refusing reviewer %s: terminal %s working in worktree %s\n' "$name" "$address" "$worktree" >&2
			exit 3
		fi
	done <<<"$candidates"
fi
brief=$(realpath -- "$brief")
printf -v prompt 'Read the brief file at %q and follow it.' "$brief"
if [ "$kind" = pi ]; then
	# shellcheck disable=SC2016 # match literal Pi skill triggers
	while IFS= read -r skill; do prompt+=" $skill"; done < <(grep -oE '\$skill:[[:alnum:]_-]+' "$brief" | sort -u)
	prompt+=' ulw'
fi

case "$kind" in
	codex) cmd=(codex --no-daemon) ;; # hc: Codex runs outside hc without it
	*) cmd=("$kind") ;;
esac
if [ -n "$session" ]; then
	case "$kind" in
		pi) cmd+=(--session "$session") ;;
		claude) cmd+=(--resume "$session") ;;
		*) printf 'cannot resume a %s worker\n' "$kind" >&2; exit 1 ;;
	esac
fi

# hc terminals do not inherit this shell's environment, so pass the
# namespace through env. --no-notify keeps hc's notes about the worker out
# of the orchestrator's input, where they would collide with the user's typing.
# Submit only the file pointer and Pi triggers, not the full brief, via argv.
hc run --bg --json --no-notify --name "$name" --cwd "$worktree" --outlive-parent \
	env "AGENT_BROWSER_NAMESPACE=$name" "${cmd[@]}" "$prompt"
# The orchestrator's space: its own space label, else its pane's herdr.space.
space=
if [ -n "${HC_TERMINAL_ID:-}" ]; then
	space=$(hc get "$HC_TERMINAL_ID" --json 2>/dev/null | jq -r '.labels.space // .labels["herdr.space"] // empty' 2>/dev/null) || space=
fi
if [ -n "$space" ]; then hc label "$name" "space=$space" >/dev/null; fi

# `hc wait` can report idle before the argv prompt is submitted, so confirm
# by turn count or a live status instead.
for _ in $(seq 30); do
	snapshot=$(hc get "$name" --json)
	fields=$(jq -er '[.state, (.status.state // "none"), .turn] | @tsv' <<<"$snapshot")
	IFS=$'\t' read -r state status turn <<<"$fields"
	if [ "$state" != live ]; then
		printf 'agent %s: terminal %s\n' "$name" "$state" >&2
		exit 2
	fi
	case "$status" in
		working) printf 'agent %s: working\n' "$name"; exit 0 ;;
		blocked|error) printf 'agent %s: %s\n' "$name" "$status" >&2; exit 2 ;;
	esac
	if [ "$turn" -ge 1 ]; then
		printf 'agent %s: turn %s, %s\n' "$name" "$turn" "$status"
		exit 0
	fi
	sleep 2
done
printf 'agent %s: brief not confirmed after 60 s\n' "$name" >&2
exit 2
