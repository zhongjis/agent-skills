#!/usr/bin/env bash
# Usage: send-followup.sh <agent> <worktree> <brief-file> [--last-reviewed <commit>]
# Reviewer follow-ups require an ancestor base; prepend its resolved scope to
# the durable brief before either live delivery or same-session revival. Exit 3:
# missing/invalid review base. The brief file must be writable for reviewers.
# Deliver a follow-up brief to an existing worker. A live worker gets it
# through hc send, and the script returns once its turn starts. A finished
# worker with a resume label (hibernated, or
# stopped_by_restart) is removed and restarted with start-worker.sh
# --resume, keeping its name, worktree, kind, and session; the brief is its
# first message. Exit 2: the worker waits on a dialog, finished without a
# resume label, or did not start a turn within 60 seconds; read its screen
# before acting. Exit 4: ORCH_MAX agents already work (slot-free.sh); nothing
# sent. When ORCH_EPIC is set, a confirmed
# delivery or revival records a best-effort `re-instructed` event on the task bead.
set -euo pipefail

log_followup() {
	[ -n "${ORCH_EPIC:-}" ] || return 0
	local bead
	local event_fields=("agent=$name" "brief=$brief" result=working)
	[ -z "$base" ] || event_fields+=("last-reviewed=$base")
	bead=$(bd list --parent "$ORCH_EPIC" --all --limit 0 --json | jq -r --arg name "${name:2}" '[.[] | select(.metadata.key as $key | $key != null and ($name == $key or ($name | startswith($key + "-"))))] | sort_by(.metadata.key | length) | last | .id // empty') || return 0
	[ -n "$bead" ] || { printf 'warning: no task bead for %s under %s; event not recorded\n' "$name" "$ORCH_EPIC" >&2; return 0; }
	"$(dirname -- "${BASH_SOURCE[0]}")/event.sh" "$bead" re-instructed \
		"${event_fields[@]}" >/dev/null 2>&1 || true
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
# Before any side effect, including the reviewer scope written into the brief.
"$(dirname -- "${BASH_SOURCE[0]}")/slot-free.sh" "$name"
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
fields=$(jq -er '[.state, (.status.state // "none"), (.turn // 0), (.labels.resume // "")] | @tsv' <<<"$snapshot")
# resume last: tab is IFS whitespace, so an empty middle field would collapse.
IFS=$'\t' read -r state status turn resume <<<"$fields"

case "$state" in
	live)
		if [ "$status" = blocked ]; then
			printf 'agent %s: blocked; answer its dialog first\n' "$name" >&2
			exit 2
		fi
		hc send "$name" "$(cat "$brief")" >/dev/null
		printf 'agent %s: sent\n' "$name"
		# Confirm the turn started, so the next slot check counts it.
		for _ in $(seq 30); do
			fields=$(hc get "$name" --json | jq -er '[(.status.state // "none"), (.turn // 0)] | @tsv')
			IFS=$'\t' read -r now_status now_turn <<<"$fields"
			if [ "$now_status" = working ] || [ "$now_turn" -gt "$turn" ]; then
				log_followup
				exit 0
			fi
			sleep 2
		done
		printf 'agent %s: no turn started after 60 s\n' "$name" >&2
		exit 2
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
		# Blank ORCH_EPIC so revival does not record a new dispatch.
		rc=0
		ORCH_EPIC='' "$(dirname -- "${BASH_SOURCE[0]}")/start-worker.sh" "$name" "$worktree" "$brief" --kind "$kind" --resume "$session" || rc=$?
		if [ "$rc" -eq 0 ]; then log_followup; fi
		exit "$rc"
		;;
	*)
		printf 'agent %s: unexpected state %s\n' "$name" "$state" >&2
		exit 1
		;;
esac
