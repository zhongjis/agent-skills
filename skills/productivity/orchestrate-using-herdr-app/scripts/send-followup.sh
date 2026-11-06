#!/usr/bin/env bash
# Usage: send-followup.sh <agent> <worktree> <brief-file>
# Deliver a follow-up brief to an existing worker. A live worker gets it
# through hc send. A finished worker with a resume label (hibernated, or
# stopped_by_restart) is removed and restarted with start-worker.sh
# --resume, keeping its name, worktree, kind, and session; the brief is its
# first message. Exit 2: the worker waits on a dialog, or finished without a
# resume label; read its screen before acting.
set -euo pipefail

usage() {
	printf 'usage: send-followup.sh <agent> <worktree> <brief-file>\n' >&2
	exit 1
}

[ "$#" -eq 3 ] && [ -n "$1" ] && [ -n "$2" ] && [ -n "$3" ] || usage
name="$1"
worktree="$2"
brief="$3"
[ -r "$brief" ] || { printf 'unreadable brief %s\n' "$brief" >&2; exit 1; }

snapshot=$(hc get "$name" --json)
fields=$(jq -er '[.state, (.status.state // "none"), (.labels.resume // "")] | @tsv' <<<"$snapshot")
IFS=$'\t' read -r state status resume <<<"$fields"

case "$state" in
	live)
		if [ "$status" = blocked ]; then
			printf 'agent %s: blocked; answer its dialog first\n' "$name" >&2
			exit 2
		fi
		hc send "$name" "$(cat "$brief")" >/dev/null
		printf 'agent %s: sent\n' "$name"
		;;
	finished)
		# The resume label holds the agent's own launch line, for example
		# `env AGENT_BROWSER_NAMESPACE=x pi --session <id>`.
		if [[ $resume =~ (^|[[:space:]])pi[[:space:]](.*[[:space:]])?--session[[:space:]]+([^[:space:]]+) ]]; then
			kind=pi
		elif [[ $resume =~ (^|[[:space:]])claude[[:space:]](.*[[:space:]])?--resume[[:space:]]+([^[:space:]]+) ]]; then
			kind=claude
		else
			printf 'agent %s: finished without a resumable session\n' "$name" >&2
			exit 2
		fi
		session="${BASH_REMATCH[3]}"
		hc rm "$name" >/dev/null
		exec "$(dirname -- "${BASH_SOURCE[0]}")/start-worker.sh" "$name" "$worktree" "$brief" --kind "$kind" --resume "$session"
		;;
	*)
		printf 'agent %s: unexpected state %s\n' "$name" "$state" >&2
		exit 1
		;;
esac
