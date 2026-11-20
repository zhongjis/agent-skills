#!/usr/bin/env bash
# Persist a full re-instruction before delivering its bead pointer. Exit 2:
# blocked/unresumable/unconfirmed; 3: invalid review base; 4: no slot.
set -euo pipefail

usage() {
	printf 'usage: send-reinstruction.sh <agent> <worktree> <bead> <text> [--last-reviewed <commit>]\n' >&2
	exit 1
}

[ "$#" -ge 4 ] && [ -n "$1" ] && [ -n "$2" ] && [ -n "$3" ] && [ -n "$4" ] || usage
name="$1"
worktree="$2"
bead="$3"
text="$4"
shift 4
base=
if [ "$#" -gt 0 ]; then
	[ "$#" -eq 2 ] && [ "$1" = --last-reviewed ] && [ -n "$2" ] || usage
	base="$2"
fi
# Before any side effect, including recording a re-instruction.
"$(dirname -- "${BASH_SOURCE[0]}")/slot-free.sh" "$name"
if [[ $name == r-* ]]; then
	[ -n "$base" ] || { printf 'reviewer follow-up requires --last-reviewed <commit>\n' >&2; exit 3; }
	base=$(git -C "$worktree" rev-parse --verify --end-of-options "$base^{commit}" 2>/dev/null) || {
		printf 'last-reviewed is not a commit\n' >&2; exit 3;
	}
	git -C "$worktree" merge-base --is-ancestor "$base" HEAD || {
		printf 'last-reviewed %s is not an ancestor of HEAD\n' "$base" >&2; exit 3;
	}
	printf -v text 'Review scope for this round (supersedes any scope in the following instructions): %s..HEAD\n\n%s' "$base" "$text"
elif [ -n "$base" ]; then
	usage
fi

script_dir=$(dirname -- "${BASH_SOURCE[0]}")
record_instruction() {
	local event_fields=("agent=$name")
	[ -z "$base" ] || event_fields+=("last-reviewed=$base")
	"$script_dir/event.sh" "$bead" re-instructed --body "$text" "${event_fields[@]}" >/dev/null
}
printf -v pointer 'Load the orchestrated-worker skill, run bd prime, run bd show %q, and read the latest event=re-instructed comment with bd comments %q. Follow that re-instruction; write an event=report comment on that bead, then end your turn; never hc send to the orchestrator.' "$bead" "$bead"

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
		# start-worker launches through env; hc preserves that complete argv.
		if jq -e '.argv | index("pi") != null' <<<"$snapshot" >/dev/null; then
			task=$(bd show "$bead" --json)
			pointer+=" \$skill:orchestrated-worker"
			# shellcheck disable=SC2016 # literal Pi skill triggers from design
			while IFS= read -r skill; do pointer+=" $skill"; done < <(jq -r '.[0].design // ""' <<<"$task" | grep -oE '\$skill:[[:alnum:]_-]+' | sort -u)
			pointer+=' ulw'
		fi
		record_instruction
		hc send "$name" "$pointer" >/dev/null
		printf 'agent %s: sent\n' "$name"
		# Confirm the turn started, so the next slot check counts it.
		for _ in $(seq 30); do
			fields=$(hc get "$name" --json | jq -er '[(.status.state // "none"), (.turn // 0)] | @tsv')
			IFS=$'\t' read -r now_status now_turn <<<"$fields"
			if [ "$now_status" = working ] || [ "$now_turn" -gt "$turn" ]; then
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
		record_instruction
		hc rm "$name" >/dev/null
		rc=0
		"$script_dir/start-worker.sh" "$name" "$worktree" "$bead" --kind "$kind" --resume "$session" || rc=$?
		exit "$rc"
		;;
	*)
		printf 'agent %s: unexpected state %s\n' "$name" "$state" >&2
		exit 1
		;;
esac
