#!/usr/bin/env bash
# Usage: wait-until.sh <check command> [args...]
# Wait for a release or deploy: run the check every 30 s until it exits 0, then exit 0.
# A wait on an outside system must never be a bare `until ...; do sleep; done` loop: a check
# that never succeeds would hang the session forever. This wait always ends. The 3600 s
# deadline is fixed and has no flag; on expiry print `timeout after 60m: <command>` and
# exit 3. The check's own output is discarded; only its exit status counts.
# WAIT_UNTIL_POLL changes the interval only (tests). WAIT_UNTIL_DEADLINE shortens the deadline
# only when WAIT_UNTIL_TEST=1.
set -euo pipefail

[ "$#" -ge 1 ] && [ -n "$1" ] || {
	printf 'usage: wait-until.sh <check command> [args...]\n' >&2
	exit 1
}
poll="${WAIT_UNTIL_POLL:-30}"
deadline=3600
[ "${WAIT_UNTIL_TEST:-}" != 1 ] || deadline="${WAIT_UNTIL_DEADLINE:-$deadline}"

SECONDS=0
while true; do
	if "$@" >/dev/null 2>&1; then exit 0; fi
	if [ "$SECONDS" -ge "$deadline" ]; then
		printf 'timeout after 60m: %s\n' "$*"
		exit 3
	fi
	sleep "$poll"
done
