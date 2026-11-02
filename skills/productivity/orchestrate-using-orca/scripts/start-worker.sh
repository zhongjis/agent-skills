#!/usr/bin/env bash
# Usage: start-worker.sh <agent> <branch> <base> <brief-file> [--repo <selector>] [--kind <kind>] [--run]
# Create the worker's worktree, then start its agent with the brief.
#   default: one `orca worktree create --agent --prompt` (handoff, no Run).
#   --run:   create the worktree without an agent, then
#            `orca orchestration worker-start --spec` on the bound Run.
# Rejects agent names outside [a-z][a-z0-9_-]{0,31}. Never passes a path to
# Orca. A failing command is printed as Orca returned it and never retried:
# a failed worker-start can leave resources behind, so the caller inspects
# the receipt. The worktree id and path go to stderr.
set -euo pipefail

usage() {
	printf 'usage: start-worker.sh <agent> <branch> <base> <brief-file> [--repo <selector>] [--kind <kind>] [--run]\n' >&2
	exit 1
}

[ "$#" -ge 4 ] && [ -n "$1" ] && [ -n "$2" ] && [ -n "$3" ] && [ -n "$4" ] || usage
name="$1"
branch="$2"
base="$3"
brief="$4"
shift 4
kind=pi
repo=()
run=0
while [ "$#" -gt 0 ]; do
	case "$1" in
		--kind) [ "$#" -ge 2 ] || usage; kind="$2"; shift 2 ;;
		--repo) [ "$#" -ge 2 ] || usage; repo=(--repo "$2"); shift 2 ;;
		--run) run=1; shift ;;
		*) usage ;;
	esac
done

if ! [[ $name =~ ^[a-z][a-z0-9_-]{0,31}$ ]]; then
	printf 'invalid agent name %s: use [a-z][a-z0-9_-]{0,31}\n' "$name" >&2
	exit 1
fi
[ -r "$brief" ] || { printf 'unreadable brief %s\n' "$brief" >&2; exit 1; }
prompt=$(cat "$brief")

create=(orca worktree create --name "$branch" --branch "$branch" --base-branch "$base"
	--no-parent --comment "$name" ${repo[@]+"${repo[@]}"})

if [ "$run" -eq 0 ]; then
	"${create[@]}" --agent "$kind" --prompt "$prompt" --json
	exit
fi

out=$("${create[@]}" --json) || { status=$?; printf '%s\n' "$out" >&2; exit "$status"; }
id=$(jq -er '.result.worktree.id' <<<"$out")
printf 'worktree id=%s path=%s\n' "$id" "$(jq -r '.result.worktree.path' <<<"$out")" >&2
orca orchestration worker-start --worktree "id:$id" --agent "$kind" --spec "$prompt" --json
