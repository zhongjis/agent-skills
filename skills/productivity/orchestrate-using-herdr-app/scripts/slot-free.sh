#!/usr/bin/env bash
# Usage: slot-free.sh [<agent>]
# Under --max, check for a free slot before an agent starts a turn. A slot is
# held by each of this orchestrator's agents (w-/r- terminals labelled
# orch=$HC_TERMINAL_ID) whose hc status is working. <agent>, when already
# working, takes no new slot. Exit 0: a slot is free or ORCH_MAX is unset.
# Exit 4: no free slot; the working agents are printed. Exit 1: bad setup.
set -euo pipefail

[ -n "${ORCH_MAX:-}" ] || exit 0
if ! [[ $ORCH_MAX =~ ^[1-9][0-9]*$ ]]; then
	printf 'invalid ORCH_MAX %s: use a positive integer\n' "$ORCH_MAX" >&2
	exit 1
fi
[ -n "${HC_TERMINAL_ID:-}" ] || { printf 'ORCH_MAX needs HC_TERMINAL_ID\n' >&2; exit 1; }

working=$(hc ls --json --label "orch=$HC_TERMINAL_ID" | jq -r '.terminals[]
	| select(.state == "live" and .status == "working") | .name // empty | select(test("^[wr]-"))')
held=()
while IFS= read -r agent; do
	[ -n "$agent" ] || continue
	[ "$agent" != "${1:-}" ] || exit 0
	held+=("$agent")
done <<<"$working"
if [ "${#held[@]}" -ge "$ORCH_MAX" ]; then
	printf 'no free slot: %s of max %s working: %s\n' "${#held[@]}" "$ORCH_MAX" "${held[*]}" >&2
	exit 4
fi
