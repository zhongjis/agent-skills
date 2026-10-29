#!/usr/bin/env bash
# Usage: watch-ci.sh <repo-dir> <pr>...
# Wait for checks to finish; exit 2 on conflicts, otherwise print heads and failures.
set -euo pipefail

if [ "$#" -lt 2 ]; then
	printf 'usage: watch-ci.sh <repo-dir> <pr>...\n' >&2
	exit 1
fi
pushd -- "$1" >/dev/null
shift

while true; do
	pending=0
	reports=()
	for pr in "$@"; do
		snapshot=$(gh pr view "$pr" --json mergeable,headRefOid,statusCheckRollup)
		jq -e '(.mergeable | type == "string") and
			(.headRefOid | type == "string" and length > 0) and
			(.statusCheckRollup | type == "array")' <<<"$snapshot" >/dev/null
		if [ "$(jq -r '.mergeable' <<<"$snapshot")" = CONFLICTING ]; then
			printf 'PR %s CONFLICTING with base; CI cannot run\n' "$pr" >&2
			exit 2
		fi
		if jq -e 'any(.statusCheckRollup[];
			(.status != null and .status != "COMPLETED") or
			.state == "PENDING" or .state == "EXPECTED")' <<<"$snapshot" >/dev/null; then
			pending=1
		fi
		reports+=("$(jq -r --arg pr "$pr" '
			$pr + " " + .headRefOid + " FAIL: " +
			([.statusCheckRollup[] | select(
				.conclusion == "FAILURE" or .conclusion == "TIMED_OUT" or
				.conclusion == "CANCELLED" or .conclusion == "ACTION_REQUIRED" or
				.conclusion == "STARTUP_FAILURE" or .conclusion == "STALE" or
				.state == "FAILURE" or .state == "ERROR") |
				(.name // .context)] | unique | join(", "))' <<<"$snapshot")")
	done
	if [ "$pending" -eq 0 ]; then
		printf '%s\n' "${reports[@]}"
		exit 0
	fi
	sleep 90
done
