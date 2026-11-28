#!/usr/bin/env bash
# Print the model family (claude, gpt or gemini) of the agent in an hc terminal.
# Claude, Codex and agy have their kind's family. Pi and Copilot run any model: their
# `model=<provider>/<id>` label (set by the herdr-app session integrations) decides, and
# Pi falls back to its session file's latest model_change. Exit 2 when no source names
# the model: read the status line instead of guessing.
set -euo pipefail

[ "$#" -eq 1 ] && [ -n "$1" ] || { printf 'usage: model-family.sh <terminal>\n' >&2; exit 1; }
agent="$1"

json=$(hc get "$agent" --json 2>/dev/null) || { printf 'agent %s: no such terminal\n' "$agent" >&2; exit 2; }
# The program is `.status.app`, else the executable token of argv after a leading `env` and its K=V assignments.
kind=$(jq -er '
	def known: select(IN("pi", "claude", "agy", "copilot", "codex"));
	def exe: (.argv // []) | (if ((.[0] // "") | split("/") | last) == "env" then .[1:] else . end) |
		(map(test("^[A-Za-z_][A-Za-z0-9_]*=")) | index(false)) as $i | if $i == null then empty else .[$i] | split("/") | last end;
	[(.status.app // empty | if . == "claude-code" then "claude" else . end | known), (exe | known)] | first // empty' <<<"$json" 2>/dev/null) || kind=

# Same rule as swarm-mind's Pick reviewers and pi-config's model-family detection.
family_of() {
	local provider="${1%%/*}" id="${1#*/}"
	id="${id,,}"
	if [[ $id == *gpt* ]]; then echo gpt
	elif [[ $id == *gemini* || ${provider,,} == google* ]]; then echo gemini
	else echo claude
	fi
}

case "$kind" in
	claude) echo claude; exit 0 ;;
	codex) echo gpt; exit 0 ;;
	agy) echo gemini; exit 0 ;;
	pi | copilot) ;;
	*) printf 'agent %s: unknown agent kind; read the status line\n' "$agent" >&2; exit 2 ;;
esac

model=$(jq -r '.labels.model // empty' <<<"$json")
if [ -z "$model" ] && [ "$kind" = pi ]; then
	session=$(jq -r '.labels.resume // empty' <<<"$json" | sed -n 's/.*--session[= ]\([^ ]*\).*/\1/p')
	if [ -n "$session" ]; then
		for file in "$HOME"/.pi/agent/sessions/*/*_"$session".jsonl; do
			[ -f "$file" ] || continue
			model=$(jq -r 'select(.type == "model_change") | "\(.provider)/\(.modelId)"' "$file" 2>/dev/null | tail -n 1)
			break
		done
	fi
fi
[ -n "$model" ] || { printf 'agent %s: no model label or session record; read the status line\n' "$agent" >&2; exit 2; }
family_of "$model"
