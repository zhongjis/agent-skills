#!/usr/bin/env bash
# Usage: bot-active.sh <pr> --repo <owner/name> [--since <iso8601>]
# Print unique bot logins with PR comments, reviews, review comments, reactions,
# or head check runs. --since limits activity to timestamps after that instant.
# Exit 0: bot activity; 1: none; 2: usage, gh/API, or response parsing error.
set -euo pipefail

usage() {
	printf 'usage: bot-active.sh <pr> --repo <owner/name> [--since <iso8601>]\n' >&2
	exit 2
}
[ "$#" -ge 3 ] && [[ $1 =~ ^[0-9]+$ ]] || usage
pr="$1"
shift
repo="" since=""
while [ "$#" -gt 0 ]; do
	case "$1" in
		--repo) [ "$#" -ge 2 ] && [[ $2 == */* ]] || usage; repo="$2"; shift 2 ;;
		--since) [ "$#" -ge 2 ] && [ -n "$2" ] || usage; since="$2"; shift 2 ;;
		*) usage ;;
	esac
done
[ -n "$repo" ] || usage
head=$(gh api "repos/$repo/pulls/$pr" --jq '.head.sha') || exit 2
activity='[]'
for endpoint in "issues/$pr/comments" "issues/$pr/reactions" "pulls/$pr/reviews" "pulls/$pr/comments" "commits/$head/check-runs"; do
	pages=$(gh api --paginate --slurp "repos/$repo/$endpoint") || exit 2
	rows=$(jq '[.[] | if type == "array" then .[] else .check_runs[] end |
		if .app then
			{login: (.app.slug + "[bot]"), bot: true, ts: (.started_at // .created_at // .completed_at)}
		else
			{login: .user.login, bot: (.user.type == "Bot"), ts: (.submitted_at // .created_at)}
		end]' <<<"$pages") || exit 2
	activity=$(jq -n --argjson old "$activity" --argjson rows "$rows" '$old + $rows') || exit 2
done
logins=$(jq -r --arg since "$since" '
	# Normalize ISO8601 offsets and fractional seconds before comparing instants.
	def epoch:
		(capture("^(?<date>[0-9T:-]+)(?<fraction>\\.[0-9]+)?(?<zone>Z|[+-][0-9]{2}:[0-9]{2})$") // error("invalid ISO8601 timestamp")) |
		(.date + "Z" | fromdateiso8601) + ((.fraction // "0") | tonumber) -
		(if .zone == "Z" then 0 else
			((.zone[1:3] | tonumber) * 3600 + (.zone[4:6] | tonumber) * 60) *
			(if .zone[0:1] == "+" then 1 else -1 end) end);
	(if $since == "" then null else ($since | epoch) end) as $cutoff |
	[.[] | select(.bot or (.login | test("(\\[bot\\]|bot)$"; "i"))) |
		select($cutoff == null or (.ts != null and (.ts | epoch) > $cutoff)) | .login] |
	unique[]
' <<<"$activity") || exit 2
[ -n "$logins" ] || exit 1
printf '%s\n' "$logins"
