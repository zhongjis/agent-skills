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
