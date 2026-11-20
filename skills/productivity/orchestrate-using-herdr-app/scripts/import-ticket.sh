#!/usr/bin/env bash
# Usage: import-ticket.sh <linear|jira|github> <ticket-url>
#        [--key <key>] [--dispatch w-<key>] [--adopt <old-epic>] [--blocker]
# Initial import or pre-dispatch re-pull; never use for re-instruction.
# Requires ORCH_EPIC and HC_TERMINAL_ID; stdout is bead=<id>.
set -euo pipefail
fail() { printf '%s\n' "$*" >&2; exit 1; }
usage() { printf 'usage: import-ticket.sh <linear|jira|github> <ticket-url> [--key key] [--dispatch w-key] [--adopt old-epic] [--blocker]\n'; }
[[ ${1:-} != --help ]] || { usage; exit 0; }
[[ $# -ge 2 ]] || { usage >&2; exit 1; }
tracker=$1 ref=$2
shift 2
worker='' key='' adopt='' blocker=false
while [[ $# -gt 0 ]]; do
	case "$1" in
		--key|--dispatch|--adopt)
			[[ $# -ge 2 && -n $2 ]] || fail "missing value for $1"
			case "$1" in --key) key=$2 ;; --dispatch) worker=$2 ;; --adopt) adopt=$2 ;; esac
			shift 2 ;;
		--blocker) blocker=true; shift ;;
		*) fail "unknown option: $1" ;;
	esac
done
case "$tracker" in
	linear)
		[[ $ref =~ ^https://linear\.app/[^/]+/issue/([A-Za-z0-9]+-[0-9]+)(/[^/?#]+)?$ ]] || fail 'expected Linear ticket URL'
		identifier=${BASH_REMATCH[1]^^}
		# Native Linear imports canonicalize away the title slug.
		ref=${ref%%/issue/*}/issue/$identifier ;;
	jira)
		[[ $ref =~ ^https://[^/]+/browse/([A-Za-z0-9]+-[0-9]+)$ ]] || fail 'expected Jira ticket URL'
		identifier=${BASH_REMATCH[1]^^}
		ref=${ref%/*}/$identifier ;;
	github)
		[[ $ref =~ ^https://github\.com/([^/]+)/([^/]+)/issues/([0-9]+)$ ]] || fail 'expected GitHub issue URL'
		export GITHUB_OWNER=${BASH_REMATCH[1]} GITHUB_REPO=${BASH_REMATCH[2]}
		identifier=${BASH_REMATCH[3]} ;;
	*) fail "unsupported tracker: $tracker" ;;
esac
key=${key:-${identifier,,}}
[[ $key =~ ^[a-z0-9][a-z0-9_-]*$ ]] || fail 'invalid key'
[[ -z $worker || $worker == "w-$key" ]] || fail 'dispatch worker must be w-<key>'
[[ $blocker == false || -z $worker ]] || fail '--blocker cannot dispatch'
[[ -n ${ORCH_EPIC:-} && -n ${HC_TERMINAL_ID:-} ]] || fail 'needs ORCH_EPIC and HC_TERMINAL_ID'
scripts=$(dirname -- "${BASH_SOURCE[0]}")
bd show "$ORCH_EPIC" --json | jq -e '.[0] | select(.issue_type == "epic" and .status == "open")' >/dev/null || fail 'ORCH_EPIC must be an open epic'
lookup() {
	bd list --all --limit 0 --external-ref "$ref" --json | jq -r 'if length > 1 then error("duplicate external_ref") else .[0].id // "" end'
}
bead=$(lookup)
local_bead=$(bd list --parent "$ORCH_EPIC" --all --limit 0 --json | jq -r --arg key "$key" '[.[] | select(.metadata.key == $key and ((.external_ref // "") == ""))] | if length > 1 then error("ambiguous local key") else .[0].id // "" end')
[[ -z $bead || -z $local_bead || $bead == "$local_bead" ]] || fail "reconciliation conflict: $local_bead and $bead; resolve duplicate identity before pulling"
bead=${bead:-$local_bead}
old_epic=
before=
if [[ -n $bead ]]; then
	before=$(bd show "$bead" --json | jq '.[0]')
	# A tracker map may yield in_progress; only a w-/r- assignee is a local claim.
	jq -e '(.assignee // "") | test("^[wr]-") | not' <<<"$before" >/dev/null || fail "claimed bead: $bead; no pull"
	while IFS= read -r parent; do
		[[ -n $parent && $parent != "$ORCH_EPIC" ]] || continue
		parent_body=$(bd show "$parent" --json | jq '.[0]')
		[[ $(jq -r '.issue_type' <<<"$parent_body") == epic ]] || continue
		session=$(jq -r '.metadata.session // ""' <<<"$parent_body")
		[[ -n $session ]] || continue
		old_epic=$parent
		if [[ $(jq -r '.status' <<<"$parent_body") == open ]]; then
			terminal_status=0
			terminal=$(hc get "$session" --json 2>&1) || terminal_status=$?
			if [[ $terminal_status == 0 ]]; then
				[[ $(jq -r '.state' <<<"$terminal") != live ]] || fail "conflict: $bead belongs to live session $parent ($session)"
			elif [[ $terminal_status != 3 ]]; then
				fail "cannot inspect session $session: $terminal"
			fi
			[[ $adopt == "$parent" ]] || fail "orphan: $bead under $parent; ask user, then --adopt $parent"
		fi
	done < <(jq -r '.dependencies[]? | select(.dependency_type == "parent-child") | .id' <<<"$before")
	if [[ -n $local_bead ]]; then
		# Attach identity before the very first pull, never create a second bead.
		bd update "$bead" --external-ref "$ref" >/dev/null
	fi
fi
if [[ $tracker == github ]]; then
	GITHUB_TOKEN=$(gh auth token)
	export GITHUB_TOKEN
fi
pull_args=("$tracker" pull "$identifier" --json)
[[ $tracker != linear ]] || pull_args+=(--relations)
# A pull skips a bead whose content is equal, or whose updated_at is after the
# tracker's pre-pull last_sync (a remote change may be hidden). bd 1.3.4 shows
# that watermark only in a pull's JSON (`bd sql` is unavailable in embedded
# mode), so a first skip always pulls once more. A second skip means unchanged
# when updated_at <= the first pull's last_sync (it only advances); otherwise
# hold. Status writes bump updated_at, so pulled statuses are never normalized.
watermark=
for attempt in 1 2; do
	result=$(bd "${pull_args[@]}")
	jq -e '.stats | (.errors // 0) == 0 and (.skipped | type == "number")' <<<"$result" >/dev/null || fail "pull failed: $result"
	[[ $(jq '.stats.skipped' <<<"$result") -gt 0 ]] || break
	if [[ $attempt == 2 ]]; then
		current=$(lookup)
		if [[ -n $current && -n $watermark ]] && bd show "$current" --json | jq -e --arg w "$watermark" '
			def t: capture("^(?<s>[^.Z]+)(?<f>[.][0-9]+)?Z$") | (.s + "Z" | fromdateiso8601) + ("0" + (.f // "") | tonumber);
			(.[0].updated_at | t) <= ($w | t)' >/dev/null; then
			break
		fi
		[[ -z $current ]] || "$scripts/event.sh" "$current" blocked reason=pull-skipped >/dev/null
		fail "held: second pull skipped $ref after local changes; no dispatch"
	fi
	watermark=$(jq -r '.last_sync // ""' <<<"$result")
done
bead=$(lookup)
[[ -n $bead ]] || fail "pull did not produce external_ref=$ref"
after=$(bd show "$bead" --json | jq '.[0]')
if [[ -n $worker && -n $before && $(jq -c '[.title,.description // ""]' <<<"$before") != "$(jq -c '[.title,.description // ""]' <<<"$after")" ]]; then
	bd comments add "$bead" "event=note detail=remote body changed before dispatch
Before: $(jq -c '{title,description}' <<<"$before")
After: $(jq -c '{title,description}' <<<"$after")" --actor "o-$HC_TERMINAL_ID" >/dev/null
fi
if [[ $blocker == false ]]; then
	while IFS= read -r parent; do
		[[ -n $parent && $parent != "$ORCH_EPIC" ]] || continue
		if [[ $parent != "$old_epic" ]]; then
			planning_ref=$(bd show "$parent" --json | jq -r '.[0].external_ref // .[0].id')
			bd update "$ORCH_EPIC" --set-metadata "source=$planning_ref" >/dev/null
		fi
		bd dep remove "$bead" "$parent" >/dev/null
	done < <(jq -r '.dependencies[]? | select(.dependency_type == "parent-child") | .id' <<<"$after")
	bd dep add "$bead" "$ORCH_EPIC" --type parent-child >/dev/null
	if [[ -n $old_epic && $adopt == "$old_epic" ]]; then
		"$scripts/event.sh" "$bead" adopted "from=$old_epic" >/dev/null
	fi
	if [[ -n $worker ]]; then
		status=$(jq -r '.status' <<<"$after")
		if [[ $status == closed ]]; then
			bd update "$bead" --status blocked >/dev/null
			"$scripts/event.sh" "$bead" blocked reason=remote-closed >/dev/null
			fail "remote closed: $bead blocked; ask user before dispatch"
		fi
		# Any non-closed pulled status is not done. bd ready excludes
		# in_progress/blocked beads, so check blocks-prerequisites directly.
		bd show "$bead" --json | jq -e '.[0] | all(.dependencies[]?; .dependency_type != "blocks" or .status == "closed")' >/dev/null || fail "not ready: $bead; no claim"
		assignee=$(jq -r '.assignee // ""' <<<"$after")
		[[ $assignee != w-* && $assignee != r-* ]] || fail "claimed bead: $bead"
		# Native --claim refuses in_progress/blocked/deferred and other
		# assignees: reset only the observed remote state (exit 13 = race).
		# This bumps updated_at; safe because no pull follows a claim.
		# Prerequisites can still change between the check above and claim.
		if [[ $status != open || -n $assignee ]]; then
			bd update "$bead" --status open --assignee '' --if-status "$status" --if-assignee "$assignee" >/dev/null || fail "race: $bead changed before claim; nothing claimed"
		fi
		bd update "$bead" --claim --actor "$worker" >/dev/null || fail "race: claim failed for $bead"
		bd update "$bead" --set-metadata "key=$key" --actor "$worker" >/dev/null
	fi
fi
printf 'bead=%s\n' "$bead"
