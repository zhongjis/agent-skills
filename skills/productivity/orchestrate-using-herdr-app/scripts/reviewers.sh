#!/usr/bin/env bash
# Print eligible reviewer kinds in chain order, one `<kind> <family>` per line.
# Family is claude, gpt or gemini for a fixed-family kind, or `any` for a kind
# that can run either (Pi, Copilot). The installed kinds are cached per PATH.
set -euo pipefail

usage() {
	printf 'usage: reviewers.sh [--visual] [--not <family>] [--refresh]\n' >&2
	exit 1
}

visual=
not=
refresh=
while [ "$#" -gt 0 ]; do
	case "$1" in
		--visual) visual=1; shift ;;
		--not) [ "$#" -ge 2 ] && [ -n "$2" ] || usage; not="$2"; shift 2 ;;
		--refresh) refresh=1; shift ;;
		*) usage ;;
	esac
done

if [ -n "$visual" ]; then chain=(agy claude codex pi copilot); else chain=(claude codex pi agy copilot); fi
declare -A family=([claude]=claude [codex]=gpt [agy]=gemini [pi]=any [copilot]=any)

cache_dir="${XDG_RUNTIME_DIR:-$HOME/.cache}/orchestrate-using-herdr-app"
cache="$cache_dir/reviewers"
key=$(printf '%s' "$PATH" | cksum)
installed=()
if [ -z "$refresh" ] && [ -f "$cache" ] && [ "$(head -n 1 "$cache")" = "$key" ]; then
	mapfile -t installed < <(tail -n +2 "$cache")
else
	for kind in claude codex pi agy copilot; do
		command -v "$kind" >/dev/null 2>&1 && installed+=("$kind")
	done
	mkdir -p "$cache_dir"
	tmp=$(mktemp "$cache_dir/reviewers.XXXXXX")
	{ printf '%s\n' "$key"; [ "${#installed[@]}" -eq 0 ] || printf '%s\n' "${installed[@]}"; } > "$tmp"
	mv -f "$tmp" "$cache"
fi

for kind in "${chain[@]}"; do
	[ "${family[$kind]}" != "$not" ] || continue
	for have in ${installed[@]+"${installed[@]}"}; do
		if [ "$have" = "$kind" ]; then printf '%s %s\n' "$kind" "${family[$kind]}"; break; fi
	done
done
