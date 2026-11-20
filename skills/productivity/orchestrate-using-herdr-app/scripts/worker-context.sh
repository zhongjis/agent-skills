#!/usr/bin/env bash
# No arguments: compaction integrations run this with the worker's environment.
# Unavailable context must not interfere with the agent's next turn.
set -euo pipefail
exec 2>/dev/null
script_dir=$(dirname -- "${BASH_SOURCE[0]}")
skill="$script_dir/../../orchestrated-worker/SKILL.md"
[ -r "$skill" ] || exit 0
bead=
if [ -n "${BEADS_ACTOR:-}" ]; then
	bead=$(bd list --assignee "$BEADS_ACTOR" --status in_progress --sort updated --brief --limit 1 --json | jq -r '.[0].id // empty') || exit 0
fi
bead=${bead:-${ORCH_BEAD:-}}
[ -n "$bead" ] || exit 0
task=$(bd show "$bead") || exit 0
comments=$(bd comments "$bead" --json) || exit 0
latest=$(jq -r '[.[] | select(.text | test("^event=re-instructed( |$)"))] | sort_by(.created_at, .id) | last | .text // empty' <<<"$comments") || exit 0
cat -- "$skill"
printf '\n\n%s\n' "$task"
[ -z "$latest" ] || printf '\n%s\n' "$latest"
exit 0
