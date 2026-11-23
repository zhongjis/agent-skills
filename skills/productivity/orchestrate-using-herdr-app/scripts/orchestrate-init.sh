#!/usr/bin/env bash
# Start an orchestration: verify hc and bd, print the session epic,
# record the invocation's mode, and mark the orchestrator's pane `[o] <title>`:
# at most four slug words with hyphens as spaces; --off clears the mark.
# Usage: orchestrate-init.sh <slug> [--mode <flags>] [--from <handoff bead>]
# A peer orchestrator passes --from: its epic is linked discovered-from that
# handoff bead, and --off closes the handoff bead when it closes the epic (a
# later --off retries a failed close).
# With `--max <N>` in the flags (which then need --watch or --auto), it also
# prints `export ORCH_MAX=<N>`; otherwise `unset ORCH_MAX`.
set -euo pipefail

usage() {
	printf 'usage: orchestrate-init.sh <slug> [--mode <flags>] [--from <handoff bead>]\n' >&2
	exit 1
}

[ "$#" -ge 1 ] && [ -n "$1" ] || usage
slug="$1"
shift
mode=none
from=
while [ "$#" -gt 0 ]; do
	case "$1" in
		--mode) [ "$#" -ge 2 ] || usage; mode="${2:-none}"; shift 2 ;;
		--from) [ "$#" -ge 2 ] && [ -n "$2" ] || usage; from="$2"; shift 2 ;;
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

# Best effort: without an open window the orchestration still runs.
mark_pane() {
	local pane pane_name title payload
	local -a words
	command -v herdr-app >/dev/null || return 0
	pane=$(herdr-app ls 2>/dev/null | jq -r --arg t "$HC_TERMINAL_ID" \
		'.spaces[].tabs[].terminals[] | select(.terminal == $t) | .pane' 2>/dev/null) || return 0
	[ -n "$pane" ] || return 0
	# ponytail: herdr-app ls omits pane names; switch to it when it exposes them.
	pane_name=$(printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"doc.get","params":{"name":"herdr-app"}}' |
		hc connect 2>/dev/null | jq -r --arg p "$pane" \
		'first(.result.value | .. | objects | select(.id? == $p) | .title // "")' 2>/dev/null) || return 0
	if "$off"; then
		[[ $pane_name == '[o] '* ]] || return 0
		title=
	else
		[[ $pane_name != '[o] '* ]] || return 0
		read -ra words <<<"${slug//[-_]/ }"
		title="[o] ${words[*]:0:4}"
	fi
	payload=$(jq -cn --arg pane "$pane" --arg name "$title" '{pane:$pane,name:$name}') || return 0
	herdr-app "do" pane.rename "$payload" >/dev/null 2>&1 || true
}

off=false
if [[ " $mode " == *' --off '* ]]; then
	off=true
	# Ending local mode must not depend on database availability.
	hc label "$HC_TERMINAL_ID" orch-context= >/dev/null 2>&1 || true
	mark_pane
fi
if ! command -v bd >/dev/null || ! bd ping >/dev/null 2>&1; then
	printf 'shared blocker: bd ping failed; restore the beads service before dispatch\n' >&2
	exit 1
fi
here="$(dirname -- "${BASH_SOURCE[0]}")"
# A peer orchestrator's handoff beads end with its epic, closed as their h-<slug> claimant.
close_handoffs() {
	[ "$#" -gt 0 ] || return 0
	bd dep list "$@" --type discovered-from --json |
		jq -r --arg me "o-$HC_TERMINAL_ID" '.[] | select(.status != "closed") | [.id, (.assignee // $me)] | @tsv' |
		while IFS=$'\t' read -r handoff claimant; do bd close "$handoff" --actor "$claimant" >/dev/null; done
}
# Check the handoff bead before creating an epic that would link to nothing.
[ -z "$from" ] || bd show --json -- "$from" >/dev/null
epics=$(bd list --type epic --metadata-field "session=$HC_TERMINAL_ID" --status open,in_progress,blocked,deferred --limit 0 --json)
epic=$(jq -r '.[0].id // empty' <<<"$epics")
if [ -z "$epic" ]; then
	if "$off"; then
		# Retry closures a failed earlier --off left behind on this terminal's closed epics.
		closed=$(bd list --type epic --metadata-field "session=$HC_TERMINAL_ID" --status closed --limit 0 --json | jq -j '.[].id + " "')
		read -ra closed <<<"$closed"
		close_handoffs "${closed[@]}"
		printf 'unset ORCH_EPIC\nunset ORCH_MAX\n'
		exit 0
	fi
	repo=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
	metadata=$(jq -cn --arg repo "$repo" --arg session "$HC_TERMINAL_ID" --arg source "${ORCH_SOURCE:-}" '{repo: $repo, session: $session, source: $source}')
	epic=$(bd create "$slug" --type epic --metadata "$metadata" --actor "o-$HC_TERMINAL_ID" --silent)
fi
# Idempotent: a reused epic keeps one link.
[ -z "$from" ] || bd dep add --type discovered-from --actor "o-$HC_TERMINAL_ID" -- "$epic" "$from" >/dev/null
# The latest mode event is invocation authority; recalled memory never replaces it.
"$here/event.sh" "$epic" mode "flags=$mode" "max=${max:-none}" >/dev/null
if "$off"; then
	children=$(bd list --parent "$epic" --all --limit 0 --json)
	if jq -e 'all(.[]; .status == "closed")' <<<"$children" >/dev/null; then
		bd close "$epic" --actor "o-$HC_TERMINAL_ID" >/dev/null
		close_handoffs "$epic"
	fi
	printf 'epic=%s\nexport ORCH_EPIC=%q\nunset ORCH_MAX\n' "$epic" "$epic"
	exit 0
fi
# The herdr-app session integrations run the labelled script after a compaction and
# inject its output. Keep the logical path: a resolved Nix store path goes stale on the
# next switch. Best effort: a missing label only loses that reminder.
hc label "$HC_TERMINAL_ID" "orch-context=$(pushd -- "$here" >/dev/null && pwd)/compact-context.sh" >/dev/null 2>&1 || true
printf 'epic=%s\n' "$epic"
# Exporting it lets startup and re-instruction find their task beads.
printf 'export ORCH_EPIC=%q\n' "$epic"
# A flag applies only to its invocation, so a later one without --max lifts the cap.
if [ -n "$max" ]; then printf 'export ORCH_MAX=%s\n' "$max"; else printf 'unset ORCH_MAX\n'; fi

mark_pane
