#!/usr/bin/env bash
# Start an orchestration: verify hc and bd, print the session epic,
# record the invocation's mode, and mark the orchestrator's tab `[o] <title>`: the
# smart-sessions tab standard, at most four slug words with hyphens as spaces.
# Usage: orchestrate-init.sh <slug> [--mode <flags>]
# With `--max <N>` in the flags (which then need --watch or --auto), it also
# prints `export ORCH_MAX=<N>`; otherwise `unset ORCH_MAX`.
set -euo pipefail

usage() {
	printf 'usage: orchestrate-init.sh <slug> [--mode <flags>]\n' >&2
	exit 1
}

[ "$#" -ge 1 ] && [ -n "$1" ] || usage
slug="$1"
shift
mode=none
while [ "$#" -gt 0 ]; do
	case "$1" in
		--mode) [ "$#" -ge 2 ] || usage; mode="${2:-none}"; shift 2 ;;
		*) usage ;;
	esac
done

# --max <N> caps working agents (slot-free.sh); it needs a supervisor to free slots.
max=
read -ra flags <<<"$mode"
for i in "${!flags[@]}"; do
	[ "${flags[i]}" = --max ] || continue
	max="${flags[i + 1]:-}"
	if ! [[ $max =~ ^[1-9][0-9]*$ ]]; then
		printf -- '--max needs a positive integer, got %s\n' "${max:-nothing}" >&2
		exit 1
	fi
	if ! [[ " $mode " =~ \ --(watch|auto)\  ]]; then
		printf -- '--max needs --watch or --auto: without supervision nothing frees a slot\n' >&2
		exit 1
	fi
done

if ! command -v hc >/dev/null || [ -z "${HC_TERMINAL_ID:-}" ]; then
	printf 'not inside a herdr-core terminal (hc missing or HC_TERMINAL_ID unset)\n' >&2
	exit 1
fi

if ! command -v bd >/dev/null || ! bd ping >/dev/null 2>&1; then
	printf 'shared blocker: bd ping failed; restore the beads service before dispatch\n' >&2
	exit 1
fi
here="$(dirname -- "${BASH_SOURCE[0]}")"
epics=$(bd list --type epic --metadata-field "session=$HC_TERMINAL_ID" --status open,in_progress,blocked,deferred --limit 0 --json)
epic=$(jq -r '.[0].id // empty' <<<"$epics")
if [ -z "$epic" ]; then
	repo=$(git rev-parse --show-toplevel)
	metadata=$(jq -cn --arg repo "$repo" --arg session "$HC_TERMINAL_ID" --arg source "${ORCH_SOURCE:-}" '{repo: $repo, session: $session, source: $source}')
	epic=$(bd create "$slug" --type epic --metadata "$metadata" --actor "o-$HC_TERMINAL_ID" --silent)
fi
# The latest mode event is invocation authority; recalled memory never replaces it.
"$here/event.sh" "$epic" mode "flags=$mode" "max=${max:-none}" >/dev/null
if [[ " $mode " == *' --off '* ]]; then
	children=$(bd list --parent "$epic" --all --limit 0 --json)
	if jq -e 'all(.[]; .status == "closed")' <<<"$children" >/dev/null; then
		bd close "$epic" --actor "o-$HC_TERMINAL_ID" >/dev/null
	fi
	hc label "$HC_TERMINAL_ID" orch-context= >/dev/null 2>&1 || true
	printf 'epic=%s\nexport ORCH_EPIC=%q\nunset ORCH_MAX\n' "$epic" "$epic"
	exit 0
fi
# The herdr-app session integrations run the labelled script after a compaction and
# inject its output. Keep the logical path: a resolved Nix store path goes stale on the
# next switch. Best effort: a missing label only loses that reminder.
hc label "$HC_TERMINAL_ID" "orch-context=$(realpath -s -- "$here")/compact-context.sh" >/dev/null 2>&1 || true
printf 'epic=%s\n' "$epic"
# Exporting it lets startup and re-instruction find their task beads.
printf 'export ORCH_EPIC=%q\n' "$epic"
# A flag applies only to its invocation, so a later one without --max lifts the cap.
if [ -n "$max" ]; then printf 'export ORCH_MAX=%s\n' "$max"; else printf 'unset ORCH_MAX\n'; fi

# Best effort: without an open window the orchestration still runs.
if command -v herdr-app >/dev/null; then
	tab=$(herdr-app ls 2>/dev/null | jq -r --arg t "$HC_TERMINAL_ID" \
		'[.spaces[].tabs[] | select(any(.terminals[]; .terminal == $t)) | {id, name}][0] // empty | [.id, .name] | @tsv' 2>/dev/null) || tab=
	if [ -n "$tab" ]; then
		IFS=$'\t' read -r tab_id tab_name <<<"$tab"
		read -ra words <<<"${slug//[-_]/ }"
		title="${words[*]:0:4}"
		[[ $tab_name == '[o] '* ]] || herdr-app "do" tab.rename --id "$tab_id" --name "[o] $title" >/dev/null 2>&1 || true
	fi
fi
