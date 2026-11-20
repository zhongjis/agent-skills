#!/usr/bin/env bash
# Sourced by check.sh after DB isolation; only tracker pulls are replaced.
# shellcheck disable=SC2154 # check.sh owns tmp, scripts, checks and check().
export REAL_BD
REAL_BD=$(command -v bd)
cat > "$tmp/bin/bd" <<'SHIM'
#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ge 2 && $1 =~ ^(linear|jira|github)$ && $2 == pull ]]; then
	[[ $# -ge 4 && $4 == --json ]] || exit 99
	[[ $1 != linear || ${5:-} == --relations ]] || exit 99
	if [[ $1 == github ]]; then
		[[ $GITHUB_TOKEN == fixture-token && $GITHUB_OWNER == owner && $GITHUB_REPO == repo ]] || exit 99
	fi
	case "$1" in
		linear)
			[[ $3 =~ ^[A-Z0-9]+-[0-9]+$ ]] || exit 99
			ref="https://linear.app/team/issue/$3" ;;
		jira)
			[[ $3 =~ ^[A-Z0-9]+-[0-9]+$ ]] || exit 99
			ref="https://jira.example.invalid/browse/$3" ;;
		github)
			[[ $3 =~ ^[0-9]+$ ]] || exit 99
			ref="https://github.com/$GITHUB_OWNER/$GITHUB_REPO/issues/$3" ;;
	esac
	printf '%s\n' "$*" >> "$FIXTURE/pulls"
	n=$(wc -l < "$FIXTURE/pulls")
	# Like bd 1.3.4, every pull reports the advanced watermark.
	last_sync=${IMPORT_LAST_SYNC:-$(date -u -d '+2 seconds' +%Y-%m-%dT%H:%M:%SZ)}
	if [[ ${IMPORT_MODE:-} == double-skip || ( ${IMPORT_MODE:-} == skip-apply && $n == 1 ) ]]; then
		printf '{"stats":{"skipped":1},"last_sync":"%s"}\n' "$last_sync"; exit
	fi
	id=$("$REAL_BD" list --all --limit 0 --external-ref "$ref" --json | jq -r '.[0].id // ""')
	if [[ -z $id ]]; then
		id=$("$REAL_BD" create 'Remote title' --external-ref "$ref" --silent)
	fi
	"$REAL_BD" update "$id" --title "${IMPORT_TITLE:-Remote title}" --description "${IMPORT_BODY:-Remote body}" --status "${IMPORT_STATUS:-open}" --metadata '{}' >/dev/null
	[[ -z ${IMPORT_ASSIGNEE:-} ]] || "$REAL_BD" update "$id" --assignee "$IMPORT_ASSIGNEE" >/dev/null
	[[ -z ${IMPORT_PARENT:-} ]] || "$REAL_BD" dep add "$id" "$IMPORT_PARENT" --type parent-child >/dev/null
	printf '{"stats":{"skipped":0,"updated":1},"last_sync":"%s"}\n' "$last_sync"
	exit
fi
# Race fixtures: a competing writer lands just before the guarded prep or claim.
if [[ ${1:-} == update && -n ${IMPORT_RACE:-} ]]; then
	case "$IMPORT_RACE $*" in
		"prep "*--if-status*) "$REAL_BD" update "$2" --assignee racer >/dev/null ;;
		"claim "*--claim*) "$REAL_BD" update "$2" --claim --actor w-racer >/dev/null ;;
	esac
fi
exec "$REAL_BD" "$@"
SHIM
cat > "$tmp/bin/gh" <<'SHIM'
#!/usr/bin/env bash
[[ $* == 'auth token' ]] || exit 99
printf 'fixture-token\n'
SHIM
chmod +x "$tmp/bin/bd" "$tmp/bin/gh"
export ORCH_EPIC HC_TERMINAL_ID=import-orch
ORCH_EPIC=$(bd create 'Import session' --type epic --metadata '{"session":"import-orch"}' --silent)
importer="$scripts/import-ticket.sh"
ref=https://linear.app/team/issue/TEST-1
: > "$tmp/pulls"
check 0 usage "$importer" --help
check 1 'expected Linear' "$importer" linear TEST-1
check 0 'bead=' "$importer" linear "$ref"
imported=$(bd list --all --external-ref "$ref" --json | jq -r '.[0].id')
bd show "$imported" --json | jq -e --arg epic "$ORCH_EPIC" '.[0].parent == $epic and .[0].status == "open" and .[0].metadata.key == null' >/dev/null
check 0 "bead=$imported" "$importer" linear "$ref"
[[ $(bd list --all --external-ref "$ref" --json | jq length) == 1 ]]
: > "$tmp/pulls"
check 0 "bead=$imported" env IMPORT_MODE=skip-apply "$importer" linear "$ref"
[[ $(wc -l < "$tmp/pulls") == 2 ]]
: > "$tmp/pulls"
# Two skips with updated_at <= last_sync are an unchanged ticket.
check 0 "bead=$imported" env IMPORT_MODE=double-skip "$importer" linear "$ref"
[[ $(wc -l < "$tmp/pulls") == 2 ]]
: > "$tmp/pulls"
# A local bump after last_sync may hide a remote change: hold, never claim.
fields='.[0] | {status, assignee, updated_at, metadata}'
before_skip=$(bd show "$imported" --json | jq -c "$fields")
check 1 'second pull skipped' env IMPORT_MODE=double-skip IMPORT_LAST_SYNC=2000-01-01T00:00:00Z "$importer" linear "$ref" --dispatch w-test-1
[[ $(wc -l < "$tmp/pulls") == 2 && $(bd show "$imported" --json | jq -c "$fields") == "$before_skip" ]]
bd comments "$imported" --json | jq -e 'any(.[]; .text == "event=blocked reason=pull-skipped")' >/dev/null
: > "$tmp/pulls"
check 0 "bead=$imported" env IMPORT_TITLE='Edited remote title' IMPORT_BODY='Edited remote body' IMPORT_ASSIGNEE=remote-user "$importer" linear "$ref" --dispatch w-test-1
bd show "$imported" --json | jq -e '.[0] | .status == "in_progress" and .assignee == "w-test-1" and .metadata.key == "test-1" and .description == "Edited remote body"' >/dev/null
bd comments "$imported" --json | jq -e 'any(.[]; .text | startswith("event=note detail=remote body changed before dispatch"))' >/dev/null
check 0 '| in_progress |' "$scripts/status.sh" "$ORCH_EPIC"
claimed=$(bd show "$imported" --json)
check 1 'issue already claimed by w-test-1' bd update "$imported" --claim --actor w-racer
[[ $(bd show "$imported" --json) == "$claimed" ]]
: > "$tmp/pulls"
check 1 'claimed bead' "$importer" linear "$ref" --dispatch w-test-1
[[ ! -s $tmp/pulls ]]
# Native claim itself rejects these states without changing any fields.
for state in closed blocked deferred; do
	guarded=$(bd create "Claim guard $state" --silent)
	bd update "$guarded" --status "$state" >/dev/null
	guard_before=$(bd show "$guarded" --json)
	check 1 "status $state" bd update "$guarded" --claim --actor w-guard
	[[ $(bd show "$guarded" --json) == "$guard_before" ]]
done
# Pulled states are never normalized; any non-closed state can dispatch.
for state in in_progress blocked deferred; do
	ref="https://linear.app/team/issue/STATE-${#state}"
	check 0 'bead=' env IMPORT_STATUS="$state" IMPORT_ASSIGNEE=remote-user "$importer" linear "$ref"
	bd list --all --external-ref "$ref" --json | jq -e --arg s "$state" '.[0].status == $s and .[0].assignee == "remote-user"' >/dev/null
	check 0 'bead=' env IMPORT_STATUS="$state" IMPORT_ASSIGNEE=remote-user "$importer" linear "$ref" --dispatch "w-state-${#state}"
	bd list --all --external-ref "$ref" --json | jq -e --arg w "w-state-${#state}" '.[0].status == "in_progress" and .[0].assignee == $w' >/dev/null
done
# A competing write before the guarded prep (exit 13) or the claim stops dispatch.
for race in prep:blocked:racer claim:in_progress:w-racer; do
	IFS=: read -r race state winner <<<"$race"
	ref="https://linear.app/team/issue/RACE-${#race}"
	check 1 'race:' env IMPORT_STATUS=blocked IMPORT_RACE="$race" "$importer" linear "$ref" --dispatch "w-race-${#race}"
	bd list --all --external-ref "$ref" --json | jq -e --arg s "$state" --arg w "$winner" '.[0] | .status == $s and .assignee == $w' >/dev/null
	bd list --all --external-ref "$ref" --json | jq -r '.[0].id' | xargs bd show --json | jq -e '.[0].metadata.key == null' >/dev/null
done
ref=https://linear.app/team/issue/CLOSED-1
check 1 'remote closed' env IMPORT_STATUS=closed "$importer" linear "$ref" --dispatch w-closed-1
bd list --all --external-ref "$ref" --json | jq -e '.[0].status == "blocked" and (.[0].assignee // "") == ""' >/dev/null
# Preserve the key-only bead's identity even when native pull wipes metadata.
local_task=$(bd create 'Local draft' --parent "$ORCH_EPIC" --metadata '{"key":"local-1"}' --silent)
ref=https://jira.example.invalid/browse/LOCAL-1
check 0 "bead=$local_task" "$importer" jira "$ref"
[[ $(bd list --all --external-ref "$ref" --json | jq length) == 1 ]]
# An already-imported duplicate never silently replaces the local draft.
bd create 'Unreconciled local' --parent "$ORCH_EPIC" --metadata '{"key":"local-1"}' --silent >/dev/null
: > "$tmp/pulls"
check 1 'reconciliation conflict' "$importer" jira "$ref"
[[ ! -s $tmp/pulls ]]
# An outside blocker retains remote state and no session parent.
ref=https://linear.app/team/issue/BLOCK-1
check 0 'bead=' env IMPORT_STATUS=blocked "$importer" linear "$ref" --blocker
outside=$(bd list --all --external-ref "$ref" --json | jq -r '.[0].id')
bd show "$outside" --json | jq -e '.[0].status == "blocked" and .[0].parent == null' >/dev/null
ref=https://linear.app/team/issue/WAIT-1
check 0 'bead=' "$importer" linear "$ref"
waiting=$(bd list --all --external-ref "$ref" --json | jq -r '.[0].id')
bd dep add "$waiting" "$outside" >/dev/null
check 1 'not ready' "$importer" linear "$ref" --dispatch w-wait-1
bd close "$outside" >/dev/null
check 0 "bead=$waiting" "$importer" linear "$ref" --dispatch w-wait-1
# Native Linear relations cannot replace the session parent.
planning=$(bd create 'Remote planning epic' --type epic --external-ref https://linear.app/team/project/planning --silent)
ref=https://linear.app/team/issue/PARENT-1
check 0 'bead=' env IMPORT_PARENT="$planning" "$importer" linear "$ref"
bd list --all --external-ref "$ref" --json | jq -e --arg epic "$ORCH_EPIC" '.[0].parent == $epic' >/dev/null
bd show "$ORCH_EPIC" --json | jq -e '.[0].metadata.source == "https://linear.app/team/project/planning"' >/dev/null
# A live session cannot be adopted; dead sessions require explicit consent.
old=$(bd create 'Other session' --type epic --metadata '{"session":"t9"}' --silent)
ref=https://linear.app/team/issue/ADOPT-1
orphan=$(bd create 'Other task' --external-ref "$ref" --parent "$old" --silent)
: > "$tmp/pulls"
check 1 'live session' env MODE=status-live "$importer" linear "$ref" --adopt "$old"
check 1 'orphan:' env MODE=gone "$importer" linear "$ref"
[[ ! -s $tmp/pulls ]]
check 0 "bead=$orphan" env MODE=gone "$importer" linear "$ref" --adopt "$old"
bd show "$orphan" --json | jq -e --arg epic "$ORCH_EPIC" '.[0].parent == $epic' >/dev/null
bd comments "$orphan" --json | jq -e --arg old "$old" 'any(.[]; .text == "event=adopted from=" + $old)' >/dev/null
ref=https://github.com/owner/repo/issues/7
check 0 'bead=' "$importer" github "$ref" --key github-7
# Exact duplicate references stop before a pull.
bd create Duplicate --external-ref "$ref" --silent >/dev/null
: > "$tmp/pulls"
check 5 'duplicate external_ref' "$importer" github "$ref"
[[ ! -s $tmp/pulls ]]
rm "$tmp/bin/bd" "$tmp/bin/gh"
unset ORCH_EPIC HC_TERMINAL_ID
