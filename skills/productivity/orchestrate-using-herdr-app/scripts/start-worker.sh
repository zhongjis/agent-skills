#!/usr/bin/env bash
# Launch a bead-backed worker and record `dispatched result=working|blocked|unconfirmed`
# (nothing when the terminal is not live). Exit 2: unconfirmed; 3: bead not assigned to
# the agent, or busy reviewer worktree; 4: no slot. --resume keeps the existing agent session.
# --check runs every launch guard (name, worktree, assignment, reviewer worktree, resumable
# kind, agent program on PATH, slot) and exits 0 before launching or recording anything.
# After launch it addresses the new terminal by its address, since a finished terminal of the
# same name may still exist (hc names are unique only among live terminals).
set -euo pipefail

usage() {
	printf 'usage: start-worker.sh <agent> <worktree> <bead> [--kind <kind>] [--resume <session>] [--check]\n' >&2
	exit 1
}

[ "$#" -ge 3 ] && [ -n "$1" ] && [ -n "$2" ] && [ -n "$3" ] || usage
name="$1"
worktree="$2"
bead="$3"
shift 3
kind=pi
session=
check=
while [ "$#" -gt 0 ]; do
	case "$1" in
		--kind) [ "$#" -ge 2 ] || usage; kind="$2"; shift 2 ;;
		--resume) [ "$#" -ge 2 ] && [ -n "$2" ] || usage; session="$2"; shift 2 ;;
		--check) check=1; shift ;;
		*) usage ;;
	esac
done

if ! [[ $name =~ ^[wr]-[a-z0-9][a-z0-9_-]{0,29}$ ]]; then
	printf 'invalid agent name %s: use w-<stem> (worker) or r-<stem> (reviewer), [a-z0-9_-], at most 32 characters\n' "$name" >&2
	exit 1
fi
[ -d "$worktree" ] || { printf 'no worktree %s\n' "$worktree" >&2; exit 1; }
# Also validates the bead: a missing one exits non-zero before launch.
task=$(bd show "$bead" --json)
# The claim actor must be this name: it is the agent's BEADS_ACTOR, which finds its bead.
# Workers skip the status check so a bead reopened for re-review can still revive its worker.
[[ $name == r-* ]] || jq -e --arg name "$name" '.[0].assignee == $name' <<<"$task" >/dev/null || {
	printf 'bead %s is not assigned to %s; claim it as the full agent name\n' "$bead" "$name" >&2; exit 3;
}
# Reviewers share the worker's checkout; never inspect it mid-edit.
if [[ $name == r-* ]]; then
	jq -e --arg name "$name" '.[0] | .status == "in_progress" and .assignee == $name' <<<"$task" >/dev/null || {
		printf 'review bead %s is not assigned in progress to %s\n' "$bead" "$name" >&2; exit 3;
	}
	worktree=$(realpath -- "$worktree")
	terminals=$(hc ls --json)
	candidates=$(jq -r '.terminals[] | select(.state == "live" and .status == "working") | select(((.name // "") | startswith("r-")) | not) | [.address, .cwd] | @tsv' <<<"$terminals")
	while IFS=$'\t' read -r address cwd; do
		[ -n "$address" ] || continue
		if [ "$(realpath -- "$cwd")" = "$worktree" ]; then
			printf 'refusing reviewer %s: terminal %s working in worktree %s\n' "$name" "$address" "$worktree" >&2
			exit 3
		fi
	done <<<"$candidates"
fi
printf -v prompt 'Load the orchestrated-worker skill, run bd prime, run bd show %q, and work that bead. Read its latest event=re-instructed comment with agent=%s in bd comments %q for any later instructions.' "$bead" "$name" "$bead"
if [ "$kind" = pi ]; then
	source_text=$(jq -r '.[0].design // ""' <<<"$task")
	prompt+=" \$skill:orchestrated-worker"
	# shellcheck disable=SC2016 # match literal Pi skill triggers
	while IFS= read -r skill; do prompt+=" $skill"; done < <(grep -oE '\$skill:[[:alnum:]_-]+' <<<"$source_text" | sort -u)
	prompt+=' ulw'
fi
# Pi reviewers get $skill tokens from the bead design; the other kinds need the skill named.
if [[ $name == r-* && $kind != pi ]]; then
	case "$kind" in claude | codex | agy | copilot) prompt+=' Load the axis-review skill and use it for this review.' ;; esac
fi

case "$kind" in
	codex) cmd=(codex --no-daemon) ;; # hc: Codex runs outside hc without it
	*) cmd=("$kind") ;;
esac
if [ -n "$session" ]; then
	case "$kind" in
		pi) cmd+=(--session "$session") ;;
		claude) cmd+=(--resume "$session") ;;
		agy) cmd+=("--conversation=$session") ;;
		copilot) cmd+=("--resume=$session") ;;
		*) printf 'cannot resume a %s worker\n' "$kind" >&2; exit 1 ;;
	esac
fi
# agy asks to trust an unknown workspace; --settings trusts this worktree up front, fresh or resumed.
if [ "$kind" = agy ]; then
	cmd+=(--settings "$(jq -cn --arg w "$(realpath -- "$worktree")" '{trustedWorkspaces: [$w]}')")
fi
# agy and Copilot run a positional prompt only through -i, which must come right before it.
case "$kind" in agy | copilot) cmd+=(-i) ;; esac

# hc terminals do not inherit this shell's environment, so pass the
# namespace and PATH (Herdr's per-launch agent hook shims) through env.
# --no-notify keeps hc's notes about the worker out
# of the orchestrator's input, where they would collide with the user's typing.
# Submit only bootstrap pointers and Pi triggers via argv.
"$(dirname -- "${BASH_SOURCE[0]}")/slot-free.sh"
if [ -n "$check" ]; then
	command -v "${cmd[0]}" >/dev/null || { printf 'agent program %s not found on PATH\n' "${cmd[0]}" >&2; exit 1; }
	exit 0
fi
script_dir=$(dirname -- "${BASH_SOURCE[0]}")
script_dir=$(realpath -s -- "$script_dir")
labels=(--label "orch-context=$script_dir/worker-context.sh")
[ -z "${HC_TERMINAL_ID:-}" ] || labels+=(--label "orch=$HC_TERMINAL_ID")
run_status=0
run_out=$(hc run --bg --json --no-notify --name "$name" --cwd "$worktree" --outlive-parent ${labels[@]+"${labels[@]}"} \
	env "PATH=$PATH" "AGENT_BROWSER_NAMESPACE=$name" "BEADS_ACTOR=$name" "ORCH_BEAD=$bead" \
	"BEADS_DIR=${BEADS_DIR:-}" "BEADS_DOLT_SHARED_SERVER=${BEADS_DOLT_SHARED_SERVER:-}" "${cmd[@]}" "$prompt") || run_status=$?
printf '%s\n' "$run_out"
[ "$run_status" -eq 0 ] || exit "$run_status"
address=$(jq -r '.address // empty' <<<"$run_out" 2>/dev/null) || address=
target=${address:-$name}
# Records the launch result: working, blocked (dialog or error after launch) or
# unconfirmed (60 s timeout). A working launch also stamps the terminal for the panel.
log_dispatch() {
	[ -n "${HC_TERMINAL_ID:-}" ] || return 0
	local result=$1
	"$script_dir/event.sh" "$bead" dispatched \
		"agent=$name" "terminal=$address" "worktree=$worktree" "kind=$kind" "result=$result" >/dev/null 2>&1 || true
	[ "$result" != working ] || hc label "$target" "orch.in=$(( $(date +%s) * 1000 )):dispatched" >/dev/null 2>&1 || true
}
# The orchestrator's space: its own space label, else its pane's herdr.space.
space=
if [ -n "${HC_TERMINAL_ID:-}" ]; then
	space=$(hc get "$HC_TERMINAL_ID" --json 2>/dev/null | jq -r '.labels.space // .labels["herdr.space"] // empty' 2>/dev/null) || space=
fi
if [ -n "$space" ]; then hc label "$target" "space=$space" >/dev/null; fi

# `hc wait` can report idle before the argv prompt is submitted, so confirm
# by turn count or a live status instead.
for _ in $(seq 30); do
	snapshot=$(hc get "$target" --json)
	fields=$(jq -er '[.state, (.status.state // "none"), .turn] | @tsv' <<<"$snapshot")
	IFS=$'\t' read -r state status turn <<<"$fields"
	if [ "$state" != live ]; then
		printf 'agent %s: terminal %s\n' "$name" "$state" >&2
		exit 2
	fi
	case "$status" in
		working) printf 'agent %s: working\n' "$name"; log_dispatch working; exit 0 ;;
		blocked|error) printf 'agent %s: %s\n' "$name" "$status" >&2; log_dispatch blocked; exit 2 ;;
	esac
	if [ "$turn" -ge 1 ]; then
		printf 'agent %s: turn %s, %s\n' "$name" "$turn" "$status"
		log_dispatch working
		exit 0
	fi
	sleep 2
done
printf 'agent %s: task not confirmed after 60 s\n' "$name" >&2
log_dispatch unconfirmed
exit 2
