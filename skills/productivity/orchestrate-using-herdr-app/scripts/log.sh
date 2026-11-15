#!/usr/bin/env bash
# Append one well-formed row to an orchestration log (TSV).
# Usage: log.sh <logfile> <task> <event> <evidence> <result>
# Adapted from cursor/plugins pstack show-me-your-work scripts/log.sh.
set -euo pipefail

if [ "$#" -ne 5 ]; then
	printf 'usage: log.sh <logfile> <task> <event> <evidence> <result>\n' >&2
	exit 1
fi

logfile="$1"
shift

# One key per task: a ticket key (`a2a-610`) when the name starts with one, else
# the name; `w-`/`r-` agent names fold into it. Mirrors status.sh.
known() {
	[ -s "$logfile" ] && awk -F'\t' -v want="$1" '
		function key(t) { sub(/^[wr]-/, "", t); if (match(t, /^[a-z][a-z0-9]*-[0-9]+/)) t = substr(t, 1, RLENGTH); return t }
		NR > 1 && key($2) == key(want) { found = 1; exit } END { exit !found }' "$logfile"
}
case "$2" in
	queued|ticketed|dispatched|decided|note) ;;
	*)
		if [ "$1" != orchestrator ] && [ "$1" != all ] && ! known "$1"; then
			printf 'unknown task %s: log it as queued, ticketed or dispatched first, under the same key\n' "$1" >&2
			exit 1
		fi ;;
esac

mkdir -p "$(dirname "$logfile")"

# Use `>>` here, never `>`: a failed emptiness test then costs one stray
# header line, not the rows.
if [ ! -s "$logfile" ]; then
	printf 'ts\ttask\tevent\tevidence\tresult\n' >> "$logfile"
fi

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
# Keep each cell on one line, and quote cells a spreadsheet would parse as
# a formula: evidence carries untrusted text (PR titles, worker output).
clean() {
	local v
	v=$(printf '%s' "$1" | tr '\t\n\r' '   ')
	case "$v" in
		=*|+*|-*|@*) printf "'%s" "$v" ;;
		*) printf '%s' "$v" ;;
	esac
}
printf '%s\t%s\t%s\t%s\t%s\n' \
	"$ts" "$(clean "$1")" "$(clean "$2")" "$(clean "$3")" "$(clean "$4")" \
	>> "$logfile"
