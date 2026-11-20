#!/usr/bin/env bash
# Usage: type-command.sh <agent> </command ...>
# Type a slash command into an agent terminal as keys, then press enter.
# `hc send` wraps text in <hc from=...>, so the agent reads it as chat and
# never runs the command. hc keys accepts one character per key: space is
# `space`, an uppercase letter is `shift+<lower>`. Letters, digits, and
# ' , - . / ; = [ \ ] ` are typeable; any other character exits 1 before
# anything is typed (hc rejects a whole call on one unknown key). hc errors
# pass through with their exit code.
set -euo pipefail

usage() {
	printf 'usage: type-command.sh <agent> </command ...>\n' >&2
	exit 1
}

[ "$#" -eq 2 ] && [ -n "$1" ] && [[ $2 == /?* ]] || usage
name="$1"
text="$2"

keys=()
for ((i = 0; i < ${#text}; i++)); do
	c="${text:i:1}"
	case "$c" in
		' ') keys+=(space) ;;
		[A-Z]) keys+=("shift+${c,,}") ;;
		[a-z0-9\'\,./\;=\[\\\]\`-]) keys+=("$c") ;;
		*) printf 'cannot type %q as a key; type it by hand with hc keys\n' "$c" >&2; exit 1 ;;
	esac
done
hc keys "$name" "${keys[@]}" enter
