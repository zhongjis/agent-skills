#!/usr/bin/env bash
# Usage: send-followup.sh <agent> <worktree> <brief-file> [--last-reviewed <commit>]
# Reviewer follow-ups require an ancestor base; prepend its resolved scope to
# the durable brief before either live delivery or same-session revival. Exit 3:
# missing/invalid review base. The brief file must be writable for reviewers.
# Deliver a follow-up brief to an existing worker. A live worker gets it
# through hc send. A finished worker with a resume label (hibernated, or
# stopped_by_restart) is removed and restarted with start-worker.sh
# --resume, keeping its name, worktree, kind, and session; the brief is its
# first message. Exit 2: the worker waits on a dialog, or finished without a
# resume label; read its screen before acting. When ORCH_LOG is set, a confirmed
# delivery or revival appends a best-effort `re-instructed` row to that log.
set -euo pipefail

log_followup() {
	[ -n "${ORCH_LOG:-}" ] || return 0
	local evidence="brief=$brief"
	[ -z "$base" ] || evidence+=" last-reviewed=$base"
	"$(dirname -- "${BASH_SOURCE[0]}")/log.sh" "$ORCH_LOG" "$name" re-instructed \
		"$evidence" working >/dev/null 2>&1 || true
}

usage() {
	printf 'usage: send-followup.sh <agent> <worktree> <brief-file> [--last-reviewed <commit>]\n' >&2
	exit 1
}

[ "$#" -ge 3 ] && [ -n "$1" ] && [ -n "$2" ] && [ -n "$3" ] || usage
name="$1"
worktree="$2"
brief="$3"
[ -r "$brief" ] || { printf 'unreadable brief %s\n' "$brief" >&2; exit 1; }
shift 3
base=
if [ "$#" -gt 0 ]; then
	[ "$#" -eq 2 ] && [ "$1" = --last-reviewed ] && [ -n "$2" ] || usage
	base="$2"
fi
if [[ $name == r-* ]]; then
	[ -n "$base" ] || { printf 'reviewer follow-up requires --last-reviewed <commit>\n' >&2; exit 3; }
	base=$(git -C "$worktree" rev-parse --verify --end-of-options "$base^{commit}" 2>/dev/null) || {
		printf 'last-reviewed is not a commit\n' >&2; exit 3;
	}
	git -C "$worktree" merge-base --is-ancestor "$base" HEAD || {
		printf 'last-reviewed %s is not an ancestor of HEAD\n' "$base" >&2; exit 3;
	}
	scoped_brief=$(mktemp)
	trap 'rm -f -- "$scoped_brief"' EXIT
	{
		printf 'Review scope for this round (supersedes any scope in the following brief): %s..HEAD\n\n' "$base"
		cat -- "$brief"
	} > "$scoped_brief"
	cat -- "$scoped_brief" > "$brief"
	rm -f -- "$scoped_brief"
	trap - EXIT
elif [ -n "$base" ]; then
	usage
fi

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
		log_followup
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
		# Blank ORCH_LOG so start-worker.sh does not log a `dispatched` row.
		rc=0
		ORCH_LOG='' "$(dirname -- "${BASH_SOURCE[0]}")/start-worker.sh" "$name" "$worktree" "$brief" --kind "$kind" --resume "$session" || rc=$?
		if [ "$rc" -eq 0 ]; then log_followup; fi
		exit "$rc"
		;;
	*)
		printf 'agent %s: unexpected state %s\n' "$name" "$state" >&2
		exit 1
		;;
esac
