#!/usr/bin/env bash
# Run isolated CLI fixtures; never contacts a live remote or herdr-core session.
set -euo pipefail
# Capture the real anchor before replacing HOME, and resolve symlink aliases too.
global_data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
global_anchor=$(realpath -m -- "$global_data_home/beads/global/.beads")
if [[ -n ${BEADS_DIR:-} && $(realpath -m -- "$BEADS_DIR") == "$global_anchor" ]]; then
	printf 'refusing global beads anchor: %s\n' "$BEADS_DIR" >&2
	exit 1
fi
scripts=$(realpath "$(dirname -- "${BASH_SOURCE[0]}")/../scripts")
tmp=$(realpath "$(mktemp -d)")
trap 'rm -rf -- "$tmp"' EXIT
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export HOME="$tmp/home"
mkdir -p "$HOME" "$tmp/bin"
export FIXTURE="$tmp" PATH="$tmp/bin:$PATH"
unset HC_TERMINAL_ID ORCH_MAX ORCH_EPIC ORCH_SOURCE BEADS_DOLT_SHARED_SERVER
export BEADS_DIR="$tmp/beads-project/.beads" BEADS_ACTOR=fixture
checks=0
check() {
	local expected="$1" needle="$2" out status=0
	shift 2
	out=$("$@" 2>&1) || status=$?
	if [[ "$status" != "$expected" || "$out" != *"$needle"* ]]; then
		printf 'FAIL: %s (exit %s, expected %s / %s)\n%s\n' "$*" "$status" "$expected" "$needle" "$out" >&2
		exit 1
	fi
	checks=$((checks + 1))
}
# Refuse a realpath alias before invoking bd, including when HOME is already isolated.
ln -s "$global_anchor" "$tmp/global-alias"
cat > "$tmp/bin/bd" <<'MOCK'
#!/usr/bin/env bash
printf 'unexpected bd call\n' >> "$FIXTURE/bd-calls"
exit 99
MOCK
chmod +x "$tmp/bin/bd"
check 1 'refusing global beads anchor' env XDG_DATA_HOME="$global_data_home" BEADS_DIR="$tmp/global-alias" bash "${BASH_SOURCE[0]}"
[[ ! -e $tmp/bd-calls ]]
rm "$tmp/bin/bd"
mkdir -p "$tmp/beads-project"
# init runs in the enclosing scratch project, never inside .beads or this repo.
(pushd "$tmp/beads-project" >/dev/null; bd init --prefix orch --skip-hooks --skip-agents --non-interactive >/dev/null)
launch_epic=$(bd create 'Launch fixtures' --type epic --silent)
launch_task=$(bd create 'Worker A' --parent "$launch_epic" --metadata '{"key":"worker-a"}' --silent)

cat > "$tmp/bin/hc" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
	ls)
		printf '%s\n' "$*" >> "$FIXTURE/ls-calls"
		cat "${FIXTURE}/terminals.json"; exit ;;
	run)
		printf '%s\n' "$*" >> "$FIXTURE/calls"
		printf '%s\0' "$@" > "$FIXTURE/argv"
		rm -f "$FIXTURE/sends"
		[[ $MODE != run-fail ]] || { echo '{"error":{"kind":"name_taken"}}' >&2; exit 1; }
		echo '{"address":"t9","state":"live","turn":0}'
		exit ;;
	label)
		printf '%s\n' "$*" >> "$FIXTURE/labels"
		exit ;;
	send|rm)
		printf '%s\n' "$*" >> "$FIXTURE/calls"
		[[ $1 != rm ]] || { touch "$FIXTURE/removed"; echo "$2" >> "$FIXTURE/removed-names"; }
		[[ $1 != send ]] || echo sent >> "$FIXTURE/sends"
		exit ;;
	wait)
		[[ $MODE != gone ]] || { echo '{"error":{"kind":"not_found"}}' >&2; exit 3; }
		[[ $MODE != wait-error ]] || { echo '{"error":{"kind":"io"}}' >&2; exit 1; }
		case "$MODE" in quiet*) echo '{"reason":"timeout"}' ;; *) echo '{"reason":"status"}' ;; esac
		exit ;;
	keys)
		printf '%s\n' "$*" > "$FIXTURE/keys-call"
		[[ $MODE != keys-fail ]] || { echo '{"error":{"kind":"invalid_params"}}' >&2; exit 1; }
		exit ;;
	read)
		r=$(( $(cat "$FIXTURE/reads" 2>/dev/null || echo 0) + 1 ))
		echo "$r" > "$FIXTURE/reads"
		printf 'transcript: 1. Goal blocked earlier\n'; printf 'line\n%.0s' {1..20}
		case "$MODE" in
			quiet) printf '⠋ Working (%sm%ss · ↓ 1.2k tokens) 4%s tok/s 12:0%s\n' "$r" "$r" "$r" "$r" ;;
			quiet-hint) printf '❯ 1. Yes\nGoal blocked (/goal resume)\n' ;;
			compact) [[ $r -ge 2 ]] || printf 'Compacting\n' ;;
			crash) printf 'pi exiting due to uncaughtException:\nAbortError: The operation was aborted\n' ;;
		esac
		exit ;;
esac
if [[ $MODE == status-live ]]; then
	printf '%s\n' "$*" >> "$FIXTURE/live-calls"
	case "$2" in
		t9) echo '{"state":"live","status":{"state":"working"}}' ;;
		t10) echo '{"state":"finished"}' ;;
		t11) exit 3 ;;
		*) echo 'unexpected terminal' >&2; exit 1 ;;
	esac
	exit
fi
[[ $2 != orch ]] || { echo '{"labels":{"herdr.space":"sp1"}}'; exit; }
n=$(( $(cat "$FIXTURE/gets" 2>/dev/null || echo 0) + 1 ))
echo "$n" > "$FIXTURE/gets"
state=live status="${AGENT_STATUS:-idle}" turn=1
# Each hc send starts a turn, except in send-stuck.
if [[ -e $FIXTURE/sends && $MODE != send-stuck ]]; then turn=$((turn + $(wc -l < "$FIXTURE/sends"))); fi
if [[ $MODE == full ]]; then
	grep -qxF "$2" "$FIXTURE/full-terms" && ! grep -qxF "$2" "$FIXTURE/removed-names" 2>/dev/null || exit 3
fi
case "$MODE" in
	gone) echo '{"error":{"kind":"not_found"}}'; exit 3 ;;
	auth) echo '{"error":{"kind":"unauthorized"}}'; exit 1 ;;
	malformed) echo broken; exit ;;
	finished) state=finished ;;
	resume) [[ $n -ge 2 ]] || status=working ;;
	flicker) [[ $n -ne 2 ]] || status=working ;;
	quiet*) status=working ;;
	start-turn) [[ $n -ge 3 ]] || turn=0 ;;
	start-never) turn=0 ;;
	hibernated) [[ -e $FIXTURE/removed ]] || state=finished ;;
esac
printf '{"state":"%s","status":{"state":"%s"},"turn":%s,"labels":{"resume":"%s"}}\n' "$state" "$status" "$turn" "${RESUME:-}"
MOCK
cat > "$tmp/bin/sleep" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$1" >> "$FIXTURE/sleeps"
MOCK
chmod +x "$tmp/bin/"*
printf '{"terminals":[]}\n' > "$tmp/terminals.json"
for status in idle 'done' blocked error; do
	rm -f "$tmp/gets"
	check 0 "settled: $status" env MODE=settled AGENT_STATUS="$status" "$scripts/watch-agent.sh" worker
done
rm -f "$tmp/gets"
check 0 'settled: done (turn 1)' env MODE=resume AGENT_STATUS=done "$scripts/watch-agent.sh" worker
# idle, done, resume: six 5 s confirm polls each; blocked, error: one 5 s re-check.
[[ $(wc -l < "$tmp/sleeps") -eq 20 && $(sort -u "$tmp/sleeps") == 5 ]]
rm -f "$tmp/gets" "$tmp/sleeps"
check 0 'settled: blocked' env MODE=flicker AGENT_STATUS=blocked "$scripts/watch-agent.sh" worker
[[ $(cat "$tmp/gets") -eq 4 ]]
rm -f "$tmp/gets" "$tmp/sleeps"
check 0 'settled: idle' env MODE=flicker AGENT_STATUS=idle "$scripts/watch-agent.sh" worker
[[ $(cat "$tmp/gets") -eq 9 ]]
rm -f "$tmp/gets" "$tmp/reads"
check 0 'settled: done' env MODE=compact AGENT_STATUS=done "$scripts/watch-agent.sh" worker
# Two Compacting checks, one background-task check, then one read for the settle evidence.
[[ $(cat "$tmp/reads") -eq 4 ]]
# A crashed agent reads done; the settle says exited and shows the crash.
check 0 'settled: exited (turn 1)' env MODE=crash AGENT_STATUS=done "$scripts/watch-agent.sh" worker
check 0 'AbortError: The operation was aborted' env MODE=crash AGENT_STATUS=done "$scripts/watch-agent.sh" worker
rm -f "$tmp/reads"
check 0 'quiet 0m (working) fp=' env MODE=quiet "$scripts/watch-agent.sh" worker --quiet 0
out=$(MODE=quiet-hint "$scripts/watch-agent.sh" worker --quiet 0)
[[ $out == *': ❯ 1. Yes' && $out != *earlier* ]]
check 1 'usage' "$scripts/watch-agent.sh" worker --quiet x
check 0 'gone' env MODE=gone "$scripts/watch-agent.sh" worker
check 0 'terminal finished' env MODE=finished "$scripts/watch-agent.sh" worker
check 1 'unauthorized' env MODE=auth "$scripts/watch-agent.sh" worker
check 5 '' env MODE=malformed "$scripts/watch-agent.sh" worker
check 1 'wait failed' env MODE=wait-error "$scripts/watch-agent.sh" worker

# A file-only macOS sha256sum must fall back to the stdin-capable shasum.
export REAL_SHASUM
REAL_SHASUM=$(command -v shasum)
cat > "$tmp/bin/sha256sum" <<'MOCK'
#!/usr/bin/env bash
printf 'Usage: sha256sum <file>\n' >&2
exit 1
MOCK
cat > "$tmp/bin/shasum" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FIXTURE/hashes"
exec "$REAL_SHASUM" "$@"
MOCK
chmod +x "$tmp/bin/sha256sum" "$tmp/bin/shasum"
rm -f "$tmp/reads"
check 0 'quiet 0m (working) fp=' env MODE=quiet "$scripts/watch-agent.sh" worker --quiet 0
rm -f "$tmp/reads"
out=$(MODE=quiet "$scripts/watch-agent.sh" worker --quiet 0)
[[ $out =~ fp=[0-9a-f]{12}$ && $(sort -u "$tmp/hashes") == '-a 256' ]]
rm "$tmp/bin/sha256sum" "$tmp/bin/shasum"

# start-worker.sh: short prompt, literal brief outside cwd, confirm by turn.
mkdir -p "$tmp/wt-a"
# shellcheck disable=SC2016 # literal brief text
printf 'Fix $skill:x and $skill:y ; $(false)\nPrivate brief body\nulw' > "$tmp/brief with spaces"
ln -s 'brief with spaces' "$tmp/brief"
printf -v prompt 'Read the brief file at %q and follow it.' "$tmp/brief with spaces"
pi_prompt="$prompt \$skill:x \$skill:y ulw"
rm -f "$tmp/gets"
check 0 'turn 1' env MODE=start-turn "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$tmp/brief"
[[ $(cat "$tmp/gets") == 3 ]]
mapfile -d '' -t argv < "$tmp/argv"
[[ ${argv[*]} == "run --bg --json --no-notify --name w-worker-a --cwd $tmp/wt-a --outlive-parent env PATH=$PATH AGENT_BROWSER_NAMESPACE=w-worker-a pi $pi_prompt" ]] || { echo 'FAIL: short Pi argv must reference absolute brief and preserve skill/ulw triggers'; exit 1; }
[[ ${argv[-1]} == "$pi_prompt" && ${argv[*]} != *'Private brief body'* ]]
[[ ! -s $tmp/labels ]]
# A relative brief resolves before hc switches to the worker cwd.
check 0 'turn 1' env MODE=settled "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$(realpath --relative-to="$PWD" "$tmp/brief with spaces")"
mapfile -d '' -t argv < "$tmp/argv"
[[ ${argv[-1]} == "$pi_prompt" ]]
[[ $(cat "$tmp/brief") == "Fix \$skill:x and \$skill:y ; \$(false)"$'\nPrivate brief body\nulw' ]]
check 0 '' env MODE=settled HC_TERMINAL_ID=orch "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$tmp/brief"
[[ $(cat "$tmp/labels") == "label w-worker-a space=sp1" ]]
: > "$tmp/calls"
check 0 '' env MODE=settled "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$tmp/brief" --resume s-1
mapfile -d '' -t argv < "$tmp/argv"
[[ ${argv[*]} == *"AGENT_BROWSER_NAMESPACE=w-worker-a pi --session s-1 $pi_prompt" ]]
: > "$tmp/calls"
check 0 '' env MODE=settled "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$tmp/brief" --kind claude --resume u-1
mapfile -d '' -t argv < "$tmp/argv"
[[ ${argv[*]} == *"AGENT_BROWSER_NAMESPACE=w-worker-a claude --resume u-1 $prompt" && ${argv[-1]} == "$prompt" ]]
check 1 'cannot resume' "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$tmp/brief" --kind codex --resume x
: > "$tmp/calls"
check 0 '' env MODE=settled "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$tmp/brief" --kind codex
mapfile -d '' -t argv < "$tmp/argv"
[[ ${argv[*]} == *"AGENT_BROWSER_NAMESPACE=w-worker-a codex --no-daemon $prompt" && ${argv[-1]} == "$prompt" ]]
check 0 'working' env MODE=settled AGENT_STATUS=working "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$tmp/brief" --kind claude
check 2 'blocked' env MODE=settled AGENT_STATUS=blocked "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$tmp/brief" --kind claude
check 2 'terminal finished' env MODE=finished "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$tmp/brief"
check 2 'not confirmed' env MODE=start-never "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$tmp/brief"
[[ $(tail -n 1 "$tmp/sleeps") == 2 ]]
: > "$tmp/calls"
check 1 'name_taken' env MODE=run-fail "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$tmp/brief"
: > "$tmp/calls"
check 1 'invalid agent name' "$scripts/start-worker.sh" Worker_A "$tmp/wt-a" "$tmp/brief"
# The role lives in the prefix: an unprefixed name is refused, and a worker
# whose stem ends in -review is still a worker.
check 1 'invalid agent name' "$scripts/start-worker.sh" a2a-618-mcp-review "$tmp/wt-a" "$tmp/brief"
check 1 'no worktree' "$scripts/start-worker.sh" w-worker-a "$tmp/missing" "$tmp/brief"
check 1 'unreadable brief' "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$tmp/missing"
check 1 'usage' "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a"
[[ ! -s $tmp/calls ]]

# ORCH_EPIC: write events on the existing child only after successful delivery.
check 0 'working' env MODE=settled AGENT_STATUS=working "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$tmp/brief"
[[ $(bd comments "$launch_task" --json | jq 'length') == 0 ]]
check 0 'working' env HC_TERMINAL_ID=orch ORCH_EPIC="$launch_epic" MODE=settled AGENT_STATUS=working "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$tmp/brief" --kind claude
comments=$(bd comments "$launch_task" --json)
jq -e --arg wt "$tmp/wt-a" --arg brief "$tmp/brief with spaces" 'length == 1 and .[0].author == "o-orch" and (.[0].text | startswith("event=dispatched ") and contains("agent=w-worker-a") and contains("terminal=t9") and contains("worktree=" + $wt) and contains("brief=" + $brief) and contains("kind=claude"))' <<<"$comments" >/dev/null
check 2 'blocked' env HC_TERMINAL_ID=orch ORCH_EPIC="$launch_epic" MODE=settled AGENT_STATUS=blocked "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$tmp/brief"
check 1 'name_taken' env HC_TERMINAL_ID=orch ORCH_EPIC="$launch_epic" MODE=run-fail "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$tmp/brief"
[[ $(bd comments "$launch_task" --json | jq 'length') == 1 ]]
# Missing children and event-write failures never fail a dispatch or create tasks.
children=$(bd list --parent "$launch_epic" --all --limit 0 --json | jq 'length')
check 0 'working' env HC_TERMINAL_ID=orch ORCH_EPIC="$launch_epic" MODE=settled AGENT_STATUS=working "$scripts/start-worker.sh" w-unknown "$tmp/wt-a" "$tmp/brief"
[[ $(bd list --parent "$launch_epic" --all --limit 0 --json | jq 'length') == "$children" ]]
check 0 'working' env ORCH_EPIC="$launch_epic" MODE=settled AGENT_STATUS=working "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$tmp/brief"
[[ $(bd comments "$launch_task" --json | jq 'length') == 1 ]]
: > "$tmp/calls"
check 0 'sent' env HC_TERMINAL_ID=orch ORCH_EPIC="$launch_epic" MODE=settled "$scripts/send-followup.sh" w-worker-a "$tmp/wt-a" "$tmp/brief"
comments=$(bd comments "$launch_task" --json)
jq -e 'length == 2 and (.[-1].text | startswith("event=re-instructed "))' <<<"$comments" >/dev/null
rm -f "$tmp/removed"
check 0 'working' env HC_TERMINAL_ID=orch ORCH_EPIC="$launch_epic" MODE=hibernated AGENT_STATUS=working RESUME='pi --session s-8' "$scripts/send-followup.sh" w-worker-a "$tmp/wt-a" "$tmp/brief"
comments=$(bd comments "$launch_task" --json)
jq -e 'length == 3 and ([.[] | select(.text | startswith("event=dispatched "))] | length == 1) and (.[-1].text | startswith("event=re-instructed "))' <<<"$comments" >/dev/null
check 2 'blocked' env HC_TERMINAL_ID=orch ORCH_EPIC="$launch_epic" MODE=settled AGENT_STATUS=blocked "$scripts/send-followup.sh" w-worker-a "$tmp/wt-a" "$tmp/brief"
[[ $(bd comments "$launch_task" --json | jq 'length') == 3 ]]
# Prefer the longest exact/hyphen-prefix metadata key; never match another epic.
short_task=$(bd create 'Short key' --parent "$launch_epic" --metadata '{"key":"worker"}' --silent)
other_epic=$(bd create 'Other launch session' --type epic --silent)
other_task=$(bd create 'Same key elsewhere' --parent "$other_epic" --metadata '{"key":"worker-a"}' --silent)
check 0 'working' env HC_TERMINAL_ID=orch ORCH_EPIC="$launch_epic" MODE=settled AGENT_STATUS=working "$scripts/start-worker.sh" w-worker-a-fix "$tmp/wt-a" "$tmp/brief"
check 0 'sent' env HC_TERMINAL_ID=orch ORCH_EPIC="$launch_epic" MODE=settled "$scripts/send-followup.sh" w-worker-a-fix "$tmp/wt-a" "$tmp/brief"
[[ $(bd comments "$launch_task" --json | jq 'length') == 5 && $(bd comments "$short_task" --json | jq 'length') == 0 && $(bd comments "$other_task" --json | jq 'length') == 0 ]]
: > "$tmp/calls"

# Reviewer startup uses hc ls's observed string status, not hc get's object.
ln -s "$tmp/wt-a" "$tmp/wt-alias"
printf '{"terminals":[{"address":"t1","name":"w-worker-a","cwd":"%s","state":"live","status":"working"}]}\n' "$tmp/wt-alias" > "$tmp/terminals.json"
: > "$tmp/calls"
check 3 'working in worktree' env MODE=settled "$scripts/start-worker.sh" r-task "$tmp/wt-a" "$tmp/brief"
[[ ! -s $tmp/calls ]]
for terminal in 'live idle w-worker-a' 'finished working w-worker-a' 'live working r-other'; do
	read -r state status name <<< "$terminal"
	printf '{"terminals":[{"address":"t1","name":"%s","cwd":"%s","state":"%s","status":"%s"}]}\n' "$name" "$tmp/wt-a" "$state" "$status" > "$tmp/terminals.json"
	check 0 'turn 1' env MODE=settled "$scripts/start-worker.sh" r-task "$tmp/wt-a" "$tmp/brief"
done
printf '{"terminals":[{"address":"t1","cwd":"%s","state":"live","status":"working"}]}\n' "$tmp/wt-a" > "$tmp/terminals.json"
check 3 'working in worktree' env MODE=settled "$scripts/start-worker.sh" r-task "$tmp/wt-a" "$tmp/brief"
printf '{"terminals":[{"address":"t1","name":"w-worker-a","cwd":"%s","state":"live","status":"working"}]}\n' "$tmp" > "$tmp/terminals.json"
check 0 'turn 1' env MODE=settled "$scripts/start-worker.sh" r-task "$tmp/wt-a" "$tmp/brief"
printf '{"terminals":[]}\n' > "$tmp/terminals.json"
: > "$tmp/calls"

# send-followup.sh: hc send to a live worker; revive a resumable finished one.
check 0 'sent' env MODE=settled "$scripts/send-followup.sh" w-worker-a "$tmp/wt-a" "$tmp/brief"
[[ $(cat "$tmp/calls") == "send w-worker-a $(cat "$tmp/brief")" ]]
: > "$tmp/calls"
check 2 'blocked' env MODE=settled AGENT_STATUS=blocked "$scripts/send-followup.sh" w-worker-a "$tmp/wt-a" "$tmp/brief"
[[ ! -s $tmp/calls ]]
rm -f "$tmp/removed"
check 0 'working' env MODE=hibernated AGENT_STATUS=working RESUME='env AGENT_BROWSER_NAMESPACE=w-worker-a pi --session s-9' "$scripts/send-followup.sh" w-worker-a "$tmp/wt-a" "$tmp/brief"
[[ $(head -n 1 "$tmp/calls") == "rm w-worker-a" ]]
mapfile -d '' -t argv < "$tmp/argv"
[[ ${argv[*]} == *"AGENT_BROWSER_NAMESPACE=w-worker-a pi --session s-9 $pi_prompt" && ${argv[-1]} == "$pi_prompt" ]]
: > "$tmp/calls"
rm -f "$tmp/removed"
check 0 'working' env MODE=hibernated AGENT_STATUS=working RESUME='claude --resume u-9' "$scripts/send-followup.sh" w-worker-a "$tmp/wt-a" "$tmp/brief"
mapfile -d '' -t argv < "$tmp/argv"
[[ ${argv[*]} == *"AGENT_BROWSER_NAMESPACE=w-worker-a claude --resume u-9 $prompt" && ${argv[-1]} == "$prompt" ]]
: > "$tmp/calls"
check 2 'without a resumable session' env MODE=finished "$scripts/send-followup.sh" w-worker-a "$tmp/wt-a" "$tmp/brief"
[[ ! -s $tmp/calls ]]
check 1 'unreadable brief' "$scripts/send-followup.sh" w-worker-a "$tmp/wt-a" "$tmp/missing"
check 1 'usage' "$scripts/send-followup.sh" w-worker-a "$tmp/wt-a"
# A sent follow-up must start a turn before the script returns.
check 2 'no turn started' env MODE=send-stuck "$scripts/send-followup.sh" w-worker-a "$tmp/wt-a" "$tmp/brief"

# --max: only this orchestrator's live working w-/r- agents hold a slot.
printf '{"terminals":[%s]}\n' '{"name":"w-a","state":"live","status":"working"},{"name":"r-b","state":"live","status":"working"},{"name":"w-c","state":"live","status":"idle"},{"name":"w-blocked","state":"live","status":"blocked"},{"name":"helper","state":"live","status":"working"},{"state":"live","status":"working"},{"name":"w-gone","state":"finished","status":"working"}' > "$tmp/terminals.json"
: > "$tmp/ls-calls"
check 0 '' env ORCH_MAX=3 HC_TERMINAL_ID=orch "$scripts/slot-free.sh"
[[ $(cat "$tmp/ls-calls") == 'ls --json --label orch=orch' ]] || { echo 'FAIL: slot count must be scoped to this orchestrator'; exit 1; }
check 4 'no free slot: 2 of max 2 working: w-a r-b' env ORCH_MAX=2 HC_TERMINAL_ID=orch "$scripts/slot-free.sh"
check 0 '' env ORCH_MAX=2 HC_TERMINAL_ID=orch "$scripts/slot-free.sh" w-a
check 0 '' "$scripts/slot-free.sh"
check 1 'invalid ORCH_MAX' env ORCH_MAX=0 HC_TERMINAL_ID=orch "$scripts/slot-free.sh"
check 1 'needs HC_TERMINAL_ID' env ORCH_MAX=2 "$scripts/slot-free.sh"
: > "$tmp/calls"
brief_before=$(cat "$tmp/brief")
check 4 'no free slot' env ORCH_MAX=2 HC_TERMINAL_ID=orch MODE=settled "$scripts/start-worker.sh" w-e "$tmp/wt-a" "$tmp/brief"
check 4 'no free slot' env ORCH_MAX=2 HC_TERMINAL_ID=orch MODE=settled "$scripts/send-followup.sh" w-c "$tmp/wt-a" "$tmp/brief"
check 4 'no free slot' env ORCH_MAX=2 HC_TERMINAL_ID=orch MODE=settled "$scripts/send-followup.sh" r-x "$tmp/wt-a" "$tmp/brief" --last-reviewed HEAD
[[ ! -s $tmp/calls && $(cat "$tmp/brief") == "$brief_before" ]] || { echo 'FAIL: a refused start or follow-up must have no side effects'; exit 1; }
# A follow-up to an agent already working takes no new slot.
check 0 'sent' env ORCH_MAX=2 HC_TERMINAL_ID=orch MODE=settled AGENT_STATUS=working "$scripts/send-followup.sh" w-a "$tmp/wt-a" "$tmp/brief"
check 0 'turn 1' env ORCH_MAX=3 HC_TERMINAL_ID=orch MODE=settled "$scripts/start-worker.sh" w-e "$tmp/wt-a" "$tmp/brief"
mapfile -d '' -t argv < "$tmp/argv"
[[ ${argv[*]} == *'--outlive-parent --label orch=orch env '* ]] || { echo 'FAIL: a worker must carry its orchestrator label from launch'; exit 1; }
printf '{"terminals":[]}\n' > "$tmp/terminals.json"
: > "$tmp/calls"

# A later reviewer round cannot bypass the base gate, even on resume.
: > "$tmp/calls"
check 3 'requires --last-reviewed' env MODE=settled "$scripts/send-followup.sh" r-task "$tmp/wt-a" "$tmp/brief"
check 3 'requires --last-reviewed' env MODE=finished "$scripts/send-followup.sh" r-task "$tmp/wt-a" "$tmp/brief"
[[ ! -s $tmp/calls ]]

# herdr-app mock: init never touches the person's real window.
cat > "$tmp/bin/herdr-app" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
	ls) printf '{"spaces":[{"tabs":[{"id":"tb1","name":"%s","terminals":[{"terminal":"t3"}]}]}]}' "${TAB_NAME:-1}" ;;
	do) printf '%s\n' "$*" >> "$FIXTURE/herdr" ;;
esac
MOCK
chmod +x "$tmp/bin/herdr-app"
# orchestrate-init.sh: requires hc and bd, creates/reuses this terminal's epic.
check 1 'not inside' env -u HC_TERMINAL_ID "$scripts/orchestrate-init.sh" api
check 1 'usage' env HC_TERMINAL_ID=t3 "$scripts/orchestrate-init.sh"
cat > "$tmp/bin/bd" <<'MOCK'
#!/usr/bin/env bash
[[ $1 == ping ]] || { echo 'unexpected bd call' >&2; exit 99; }
exit 1
MOCK
chmod +x "$tmp/bin/bd"
check 1 'shared blocker' env HC_TERMINAL_ID=t3 "$scripts/orchestrate-init.sh" api
rm "$tmp/bin/bd"
rm -f "$tmp/herdr"
out=$(HC_TERMINAL_ID=t3 ORCH_SOURCE=fixture-source "$scripts/orchestrate-init.sh" api --mode '--auto --track')
epic=$(sed -n 's/^epic=//p' <<<"$out")
[[ -n $epic && $out == *"export ORCH_EPIC=$epic"* ]]
repo=$(git rev-parse --show-toplevel)
bd show "$epic" --json | jq -e --arg repo "$repo" '.[0] | .issue_type == "epic" and .status == "open" and .metadata == {session:"t3",repo:$repo,source:"fixture-source"}' >/dev/null
bd comments "$epic" --json | jq -e '.[-1] | .author == "o-t3" and .text == "event=mode flags=--auto --track max=none"' >/dev/null
[[ $(cat "$tmp/herdr") == 'do tab.rename --id tb1 --name [o] api' ]] || { echo 'FAIL: init must mark its own tab [o] <title>'; exit 1; }
[[ $(tail -n 1 "$tmp/labels") == "label t3 orch-context=$scripts/compact-context.sh" ]]
check 0 "epic=$epic" env HC_TERMINAL_ID=t3 ORCH_EPIC="$other_epic" "$scripts/orchestrate-init.sh" api
check 0 "export ORCH_EPIC=$epic" env HC_TERMINAL_ID=t3 "$scripts/orchestrate-init.sh" api
rm -f "$tmp/herdr"
check 0 "epic=$epic" env HC_TERMINAL_ID=t3 "$scripts/orchestrate-init.sh" retro-skills_ui-audit-fix
[[ $(cat "$tmp/herdr") == 'do tab.rename --id tb1 --name [o] retro skills ui audit' ]] || { echo 'FAIL: init tab title must split hyphens into at most four words'; exit 1; }
rm -f "$tmp/herdr"
check 0 "epic=$epic" env HC_TERMINAL_ID=t3 TAB_NAME='[o] api' "$scripts/orchestrate-init.sh" api
[[ ! -e "$tmp/herdr" ]] || { echo 'FAIL: init must leave an already marked tab'; exit 1; }
bd comments "$epic" --json | jq -e '.[-1].text == "event=mode flags=none max=none"' >/dev/null
check 1 'usage' env HC_TERMINAL_ID=t3 "$scripts/orchestrate-init.sh" api --mode
rows=$(bd comments "$epic" --json | jq 'length')
check 1 'needs --watch or --auto' env HC_TERMINAL_ID=t3 "$scripts/orchestrate-init.sh" api --mode '--track --max 2'
check 1 'positive integer, got nothing' env HC_TERMINAL_ID=t3 "$scripts/orchestrate-init.sh" api --mode '--watch --max'
check 1 'positive integer, got 0' env HC_TERMINAL_ID=t3 "$scripts/orchestrate-init.sh" api --mode '--auto --max 0'
[[ $(bd comments "$epic" --json | jq 'length') == "$rows" ]]
check 0 'export ORCH_MAX=2' env HC_TERMINAL_ID=t3 "$scripts/orchestrate-init.sh" api --mode '--watch --max 2 --track'
bd comments "$epic" --json | jq -e '.[-1].text == "event=mode flags=--watch --max 2 --track max=2"' >/dev/null
check 0 'unset ORCH_MAX' env HC_TERMINAL_ID=t3 "$scripts/orchestrate-init.sh" api --mode '--auto'
# A second terminal gets its own epic, regardless of inherited ORCH_EPIC.
out=$(HC_TERMINAL_ID=t4 ORCH_EPIC="$epic" "$scripts/orchestrate-init.sh" second)
second_epic=$(sed -n 's/^epic=//p' <<<"$out")
[[ -n $second_epic && $second_epic != "$epic" ]]
# --off always records mode and clears context; open children prevent closure.
init_child=$(bd create 'Unfinished' --parent "$epic" --metadata '{"key":"unfinished"}' --silent)
check 0 "epic=$epic" env HC_TERMINAL_ID=t3 "$scripts/orchestrate-init.sh" api --mode '--off'
[[ $(bd show "$epic" --json | jq -r '.[0].status') == open && $(tail -n 1 "$tmp/labels") == 'label t3 orch-context=' ]]
bd comments "$epic" --json | jq -e '.[-1].text == "event=mode flags=--off max=none"' >/dev/null
bd close "$init_child" >/dev/null
check 0 "epic=$epic" env HC_TERMINAL_ID=t3 "$scripts/orchestrate-init.sh" api --mode '--off'
[[ $(bd show "$epic" --json | jq -r '.[0].status') == closed ]]
# Closed session epics are not reused; an empty session can close too.
out=$(HC_TERMINAL_ID=t3 "$scripts/orchestrate-init.sh" fresh)
fresh_epic=$(sed -n 's/^epic=//p' <<<"$out")
[[ -n $fresh_epic && $fresh_epic != "$epic" ]]
bd show "$fresh_epic" --json | jq -e '.[0].metadata.source == ""' >/dev/null
check 0 "epic=$fresh_epic" env HC_TERMINAL_ID=t3 "$scripts/orchestrate-init.sh" fresh --mode '--off'
[[ $(bd show "$fresh_epic" --json | jq -r '.[0].status') == closed ]]

git init -q --bare "$tmp/remote"
git init -q -b main "$tmp/work"
git -C "$tmp/work" config user.email fixture@example.invalid
git -C "$tmp/work" config user.name Fixture
git -C "$tmp/work" commit -qm main --allow-empty
main=$(git -C "$tmp/work" rev-parse HEAD)
git -C "$tmp/work" remote add origin "$tmp/remote"
git -C "$tmp/work" push -q origin main
git -C "$tmp/work" switch -qc topic
git -C "$tmp/work" push -q origin topic
git -C "$tmp/work" commit -qm feature --allow-empty
head=$(git -C "$tmp/work" rev-parse HEAD)
# Review scope must resolve to a commit in this worktree's HEAD history.
: > "$tmp/calls"
check 3 'not a commit' env MODE=settled "$scripts/send-followup.sh" r-task "$tmp/work" "$tmp/brief" --last-reviewed missing
[[ ! -s $tmp/calls ]]
review_body=$'Review fixes\nReport by ending your turn; never `hc send` to the orchestrator.\nulw'
printf '%s' "$review_body" > "$tmp/review-brief"
check 0 'sent' env MODE=settled "$scripts/send-followup.sh" r-task "$tmp/work" "$tmp/review-brief" --last-reviewed "$main"
[[ $(cat "$tmp/calls") == *"$main..HEAD"* ]]
[[ $(cat "$tmp/calls") == *"$review_body" ]] || { echo 'FAIL: live reviewer prompt must preserve the reporting footer and final ulw'; exit 1; }
# Same reviewer name and session survive finished-terminal revival.
rm -f "$tmp/removed"
check 0 'working' env MODE=hibernated AGENT_STATUS=working RESUME='pi --session review-9' "$scripts/send-followup.sh" r-task "$tmp/work" "$tmp/review-brief" --last-reviewed "$head"
mapfile -d '' -t argv < "$tmp/argv"
[[ ${argv[*]} == *'--name r-task'* && ${argv[*]} == *'pi --session review-9'* ]]
[[ $(cat "$tmp/review-brief") == *"$head..HEAD"* ]]
[[ $(cat "$tmp/review-brief") == *"$review_body" && ${argv[-1]} == *' ulw' ]] || { echo 'FAIL: resumed reviewer brief and prompt must retain final ulw'; exit 1; }

# Guard failures must happen before the passed command executes.
check 1 'not on branch' "$scripts/push-pinned.sh" "$tmp/work" other "$main" -- touch "$tmp/built"
check 3 'expected wrong' "$scripts/push-pinned.sh" "$tmp/work" topic wrong -- touch "$tmp/built"
git -C "$tmp/work" switch -q --orphan unrelated
git -C "$tmp/work" commit -qm unrelated --allow-empty
: > "$tmp/calls"
check 3 'not an ancestor' env MODE=settled "$scripts/send-followup.sh" r-task "$tmp/work" "$tmp/review-brief" --last-reviewed "$main"
[[ ! -s $tmp/calls ]]
check 3 'not an ancestor' "$scripts/push-pinned.sh" "$tmp/work" unrelated "$main" -- touch "$tmp/built"
[[ ! -e $tmp/built ]]
git -C "$tmp/work" switch -q topic
check 1 '' "$scripts/push-pinned.sh" "$tmp/work" topic "$main" -- false
[[ $(git --git-dir="$tmp/remote" rev-parse refs/heads/topic) == "$main" ]]
check 3 'changed during build' "$scripts/push-pinned.sh" "$tmp/work" topic "$main" -- git reset --hard "$main"
git -C "$tmp/work" reset -q --hard "$head"
check 3 'changed during build' "$scripts/push-pinned.sh" "$tmp/work" topic "$main" -- git update-ref refs/remotes/origin/main "$head"
check 3 'changed during build' "$scripts/push-pinned.sh" "$tmp/work" topic "$main" -- git switch main
git -C "$tmp/work" switch -q topic
# A remote race during build must fail the original lease.
other=$(git -C "$tmp/work" rev-parse unrelated)
git --git-dir="$tmp/remote" fetch -q "$tmp/work" "$other"
check 1 'stale info' "$scripts/push-pinned.sh" "$tmp/work" topic "$main" -- git --git-dir="$tmp/remote" update-ref refs/heads/topic "$other"
git --git-dir="$tmp/remote" update-ref refs/heads/topic "$main"
# Hooks run normally, including a veto, and build argv/cwd are preserved.
mkdir -p "$tmp/work/.git/hooks"
printf '#!/usr/bin/env bash\nexit 1\n' > "$tmp/work/.git/hooks/pre-push"
chmod +x "$tmp/work/.git/hooks/pre-push"
check 1 '' "$scripts/push-pinned.sh" "$tmp/work" topic "$main"
printf '#!/usr/bin/env bash\nprintf ran > "%s/hook"\n' "$tmp" > "$tmp/work/.git/hooks/pre-push"
cat > "$tmp/bin/build" <<'BUILD'
#!/usr/bin/env bash
set -euo pipefail
[[ $PWD == "$1" ]]
printf '%s' "$2" > "$3"
BUILD
chmod +x "$tmp/bin/build"
check 0 'topic' "$scripts/push-pinned.sh" "$tmp/work" topic "$main" -- build "$tmp/work" "literal ; \$(false)" "$tmp/build output"
[[ $(cat "$tmp/hook") == ran ]]
[[ $(cat "$tmp/build output") == "literal ; \$(false)" ]]
[[ $(git --git-dir="$tmp/remote" rev-parse refs/heads/topic) == "$head" ]]

# reap-worker.sh: Darwin discovery, only the worker's resources, spare ancestors.
export REAL_PS
REAL_PS=$(command -v ps)
cat > "$tmp/bin/uname" <<'MOCK'
#!/usr/bin/env bash
printf 'Darwin\n'
MOCK
cat > "$tmp/bin/ps" <<'MOCK'
#!/usr/bin/env bash
if [[ $* == '-axo pid=' ]]; then cat "$FIXTURE/pids"; else exec "$REAL_PS" "$@"; fi
MOCK
cat > "$tmp/bin/lsof" <<'MOCK'
#!/usr/bin/env bash
case "$*" in
	'-nP -iTCP -sTCP:LISTEN -t')
		[[ -s $FIXTURE/listeners ]] || exit 1
		tr ' ' '\n' < "$FIXTURE/listeners" ;;
	'-a -p '*' -d cwd -Fn')
		state=$("$REAL_PS" -o stat= -p "$3") || exit 1
		[[ $state != Z* ]] || exit 1
		awk -F '\t' -v pid="$3" '$1 == pid { print "p" $1; print "n" $2 }' "$FIXTURE/cwds" ;;
	*) exit 2 ;;
esac
MOCK
cat > "$tmp/bin/agent-browser" <<'MOCK'
#!/usr/bin/env bash
printf '%s %s\n' "$AGENT_BROWSER_NAMESPACE" "$*" >> "$FIXTURE/browser"
MOCK
cat > "$tmp/bin/docker" <<'MOCK'
#!/usr/bin/env bash
case "$1 $2" in
	'ps -a') printf 'mine\t%s\ntheirs\t%s\n\t\n' "$FIXTURE/wt/apps/web" "$FIXTURE/wt-other" ;;
	'ps -aq') echo "c-${4#*project=}" ;;
	'volume ls'|'network ls') echo "$1-${5#*project=}" ;;
	*) echo "$*" >> "$FIXTURE/docker" ;;
esac
MOCK
chmod +x "$tmp/bin/"*
mkdir -p "$tmp/wt/apps/web" "$tmp/wt-other"
spawn() { (cd "$1" && exec tail -f /dev/null >/dev/null 2>&1) & echo $!; }
dev=$(spawn "$tmp/wt/apps/web"); agent=$(spawn "$tmp/wt"); other=$(spawn "$tmp/wt-other")
echo "$dev $other $$" > "$tmp/listeners"
echo "$dev $agent $other $$" > "$tmp/pids"
printf '%s\t%s\n' "$dev" "$tmp/wt/apps/web" "$agent" "$tmp/wt" "$other" "$tmp/wt-other" "$$" "$tmp/wt" > "$tmp/cwds"
: > "$tmp/labels"
check 0 'processes under' "$scripts/reap-worker.sh" "$tmp/wt" w-worker-a --keep-agent
! kill -0 "$dev" 2>/dev/null || [[ $(ps -o stat= -p "$dev") == Z* ]]
kill -0 "$agent" && kill -0 "$other"
[[ $(cat "$tmp/browser") == 'w-worker-a close --all' ]]
[[ $(cat "$tmp/docker") == $'rm -f -v c-mine\nvolume rm -f volume-mine\nnetwork rm network-mine' ]]
[[ $(cat "$tmp/labels") == 'label w-worker-a hibernate=ok' ]] || { echo 'FAIL: settled worker must become hibernatable after reaping'; exit 1; }
: > "$tmp/listeners"
check 0 '0 stopped' "$scripts/reap-worker.sh" "$tmp/wt" w-worker-a --keep-agent
[[ $(cat "$tmp/labels") == $'label w-worker-a hibernate=ok\nlabel w-worker-a hibernate=ok' ]]
: > "$tmp/labels"
check 0 '1 stopped' "$scripts/reap-worker.sh" "$tmp/wt" w-worker-a
[[ ! -s $tmp/labels ]]
! kill -0 "$agent" 2>/dev/null || [[ $(ps -o stat= -p "$agent") == Z* ]]
kill -0 "$other"
kill "$other"; wait "$dev" "$agent" "$other" 2>/dev/null || true
check 1 'usage' "$scripts/reap-worker.sh" "$tmp/wt"
check 1 'refusing' "$scripts/reap-worker.sh" / w-worker-a
check 1 'usage' "$scripts/reap-worker.sh" "$tmp/wt" w-worker-a --full

# --full: removes both role terminals, the worktree, and the local and remote branch.
git init -q --bare "$tmp/full-remote"
git init -q -b main "$tmp/full-src"
git -C "$tmp/full-src" -c user.email=f@example.invalid -c user.name=F commit -qm main --allow-empty
git -C "$tmp/full-src" remote add origin "$tmp/full-remote"
git -C "$tmp/full-src" worktree add -q -b topic-full "$tmp/full-wt"
git -C "$tmp/full-src" push -q origin topic-full
echo "$$" > "$tmp/pids"; : > "$tmp/listeners"; : > "$tmp/removed-names"
printf 'w-a1-topic\nr-a1-topic\n' > "$tmp/full-terms"
check 0 'full cleanup w-a1-topic' env MODE=full "$scripts/reap-worker.sh" "$tmp/full-wt" w-a1-topic --full topic-full
[[ $(sort "$tmp/removed-names") == $'r-a1-topic\nw-a1-topic' ]]
[[ ! -e $tmp/full-wt ]]
check 1 '' git -C "$tmp/full-src" rev-parse --verify -q refs/heads/topic-full
check 1 '' git --git-dir="$tmp/full-remote" rev-parse --verify -q refs/heads/topic-full
rm "$tmp/bin/uname" "$tmp/bin/ps" "$tmp/bin/lsof"

# event.sh: real comments, fixed event vocabulary, attributed one-line fields.
status_epic=$(bd create 'Status session' --type epic --metadata '{"session":"status-orch"}' --silent)
alpha=$(bd create Alpha --parent "$status_epic" --metadata '{"key":"alpha"}' --silent)
for event in mode ticketed dispatched handed-off queued re-instructed reviewed ready merged settled reaped blocked decided note adopted; do
	check 0 '' env HC_TERMINAL_ID=events "$scripts/event.sh" "$alpha" "$event" 'detail=spaces stay together'
done
comments=$(bd comments "$alpha" --json)
jq -e 'length == 15 and all(.[]; .author == "o-events" and (.text | endswith(" detail=spaces stay together")))' <<<"$comments" >/dev/null
check 1 'usage' "$scripts/event.sh"
check 1 'invalid event' env HC_TERMINAL_ID=events "$scripts/event.sh" "$alpha" unknown
check 1 'HC_TERMINAL_ID' env -u HC_TERMINAL_ID "$scripts/event.sh" "$alpha" note
for field in missing-equals '=empty-key' 'event=note' $'detail=new\nline' $'detail=carriage\rreturn' $'detail=tab\tvalue'; do
	check 1 'invalid event field' env HC_TERMINAL_ID=events "$scripts/event.sh" "$alpha" note "$field"
done
[[ $(bd comments "$alpha" --json | jq 'length') == 15 ]]
check 1 '' env HC_TERMINAL_ID=events "$scripts/event.sh" orch-nonexistent note

# Status reads native state, latest event plus metadata, and the latest worker dispatch.
beta=$(bd create Beta --parent "$status_epic" --metadata '{"key":"beta"}' --silent)
gamma=$(bd create Gamma --parent "$status_epic" --metadata '{"key":"gamma"}' --silent)
delta=$(bd create Delta --parent "$status_epic" --metadata '{"key":"delta"}' --silent)
bd update "$alpha" --status in_progress --metadata '{"key":"alpha","pr_url":"https://example.invalid/pr/7","head_sha":"head7","merged_sha":"merge7","review_round":3,"blocked_reason":"needs approval"}' >/dev/null
check 0 '' env HC_TERMINAL_ID=status-orch "$scripts/event.sh" "$status_epic" mode 'flags=--auto' max=none
check 0 '' env HC_TERMINAL_ID=status-orch "$scripts/event.sh" "$alpha" dispatched agent=w-alpha terminal=old
check 0 '' env HC_TERMINAL_ID=status-orch "$scripts/event.sh" "$alpha" dispatched agent=w-alpha terminal=t9
check 0 '' env HC_TERMINAL_ID=status-orch "$scripts/event.sh" "$alpha" dispatched agent=r-alpha terminal=t11
check 0 '' env HC_TERMINAL_ID=status-orch "$scripts/event.sh" "$alpha" reviewed 'detail=PR #7 | green' findings=/review
# Non-event comments do not replace the latest milestone.
bd comments add "$alpha" 'Human observation, not an event' >/dev/null
check 0 '' env HC_TERMINAL_ID=status-orch "$scripts/event.sh" "$beta" dispatched agent=w-beta terminal=t10
check 0 '' env HC_TERMINAL_ID=status-orch "$scripts/event.sh" "$beta" reaped terminal=reviewer
bd close "$beta" >/dev/null
check 0 '' env HC_TERMINAL_ID=status-orch "$scripts/event.sh" "$gamma" dispatched agent=w-gamma terminal=t11
check 0 '' env HC_TERMINAL_ID=status-orch "$scripts/event.sh" "$status_epic" note detail=one
check 0 '' env HC_TERMINAL_ID=status-orch "$scripts/event.sh" "$status_epic" note detail=two
alpha_since=$(bd comments "$alpha" --json | jq -r '[.[] | select(.text | startswith("event=reviewed "))][-1].created_at')
delta_since=$(bd show "$delta" --json | jq -r '.[0].created_at')
out=$("$scripts/status.sh" "$status_epic")
[[ $out == *'| Task | Worker | Event | Result | Evidence | Since |'* && $out == *'| alpha | w-alpha (t9) | reviewed | in_progress |'* && $out == *'| beta | w-beta (t10) | reaped | closed |'* ]]
[[ $(grep -c '^| alpha |' <<<"$out") == 1 && $out != *'| all |'* && $out == *'2 notes (all).'* ]]
for evidence in 'PR #7 &#124; green' 'findings=/review' 'pr_url=https://example.invalid/pr/7' 'head_sha=head7' 'merged_sha=merge7' 'review_round=3' 'blocked_reason=needs approval'; do
	[[ $out == *"$evidence"* ]] || { printf 'FAIL: missing evidence %s\n%s\n' "$evidence" "$out" >&2; exit 1; }
done
[[ $out == *"$alpha_since"* && $out == *"$delta_since"* ]]
# ORCH_EPIC takes precedence; otherwise resolve by this terminal's metadata.
[[ $(ORCH_EPIC="$status_epic" HC_TERMINAL_ID=t4 "$scripts/status.sh") == "$out" ]]
[[ $(HC_TERMINAL_ID=status-orch "$scripts/status.sh") == "$out" ]]
[[ $(ORCH_EPIC="$other_epic" "$scripts/status.sh" "$status_epic") == "$out" ]]
check 0 '| Since | Live |' env MODE=status-live "$scripts/status.sh" "$status_epic" --live
out=$(MODE=status-live "$scripts/status.sh" "$status_epic" --live)
[[ $(grep '^| alpha |' <<<"$out") == *'| working |' && $(grep '^| beta |' <<<"$out") == *'| finished |' && $(grep '^| gamma |' <<<"$out") == *'| gone |' && $(grep '^| delta |' <<<"$out") == *'|  |' ]]
[[ $(sort -u "$tmp/live-calls") == $'get t10 --json\nget t11 --json\nget t9 --json' ]]
check 1 'unauthorized' env MODE=auth "$scripts/status.sh" "$status_epic" --live
check 1 'usage' "$scripts/status.sh" "$status_epic" --unknown
check 1 '' "$scripts/status.sh" orch-nonexistent

# Compaction uses the latest mode event, not the latest comment/event of any kind.
no_mode=$(bd create 'No mode yet' --type epic --silent)
[[ -z $("$scripts/compact-context.sh" "$no_mode") ]]
[[ -z $(env -u ORCH_EPIC -u HC_TERMINAL_ID "$scripts/compact-context.sh") ]]
out=$(MODE=status-live "$scripts/compact-context.sh" "$status_epic")
[[ $out == *'flags=--auto'* && $out == *'| alpha |'* && $out == *'| Since | Live |'* ]]
[[ $(MODE=status-live ORCH_EPIC="$status_epic" "$scripts/compact-context.sh") == "$out" ]]
[[ $(MODE=status-live HC_TERMINAL_ID=status-orch "$scripts/compact-context.sh") == "$out" ]]
check 0 '' env HC_TERMINAL_ID=status-orch "$scripts/event.sh" "$status_epic" mode 'flags=--watch --max 2' max=2
out=$(MODE=status-live "$scripts/compact-context.sh" "$status_epic")
[[ $out == *'flags=--watch --max 2'* && $out != *'flags=--auto'* ]]
check 0 '' env HC_TERMINAL_ID=status-orch "$scripts/event.sh" "$status_epic" mode flags=--off max=none
check 0 '' env HC_TERMINAL_ID=status-orch "$scripts/event.sh" "$status_epic" note detail=after-off
[[ -z $("$scripts/compact-context.sh" "$status_epic") ]]
checks=$((checks + 1))

# bot-active.sh: paginated API fixtures only, never real GitHub.
cat > "$tmp/bin/gh" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
[[ $1 == api ]] || exit 2
[[ $GH_MODE != api-error ]] || { echo 'API unavailable' >&2; exit 1; }
if [[ $2 == repos/owner/repo/pulls/7 ]]; then
	[[ $* == *"--jq .head.sha" ]] || exit 2
	echo fixture-head
	exit
fi
[[ $2 == --paginate && $3 == --slurp ]] || exit 2
case "$4" in
	repos/owner/repo/issues/7/comments) cat "$FIXTURE/bot-comments.json" ;;
	repos/owner/repo/issues/7/reactions) cat "$FIXTURE/bot-reactions.json" ;;
	repos/owner/repo/pulls/7/reviews) cat "$FIXTURE/bot-reviews.json" ;;
	repos/owner/repo/pulls/7/comments) cat "$FIXTURE/bot-inline.json" ;;
	repos/owner/repo/commits/fixture-head/check-runs) cat "$FIXTURE/bot-checks.json" ;;
	*) echo 'unexpected API path' >&2; exit 1 ;;
esac
MOCK
chmod +x "$tmp/bin/gh"
for channel in comments reactions reviews inline checks; do
	printf '[[]]\n' > "$tmp/bot-$channel.json"
done
printf '[{"check_runs":[]}]\n' > "$tmp/bot-checks.json"
check 1 '' env GH_MODE=ok "$scripts/bot-active.sh" 7 --repo owner/repo
for channel in comments reactions reviews inline; do
	# The second page has the bot; the human on the first must not count.
	printf '[[{"user":{"login":"human","type":"User"},"created_at":"2026-01-01T00:00:00Z"}],[{"user":{"login":"review[bot]","type":"Bot"},"created_at":"2026-01-01T01:00:00Z","submitted_at":"2026-01-01T01:00:00Z"}]]\n' > "$tmp/bot-$channel.json"
	check 0 'review[bot]' env GH_MODE=ok "$scripts/bot-active.sh" 7 --repo owner/repo --since 2026-01-01T00:30:00Z
	check 1 '' env GH_MODE=ok "$scripts/bot-active.sh" 7 --repo owner/repo --since 2026-01-01T02:00:00+01:00
	printf '[[]]\n' > "$tmp/bot-$channel.json"
done
printf '[{"check_runs":[{"app":{"slug":"checker"},"started_at":"2026-01-01T00:00:01Z"}]}]\n' > "$tmp/bot-checks.json"
check 0 'checker[bot]' env GH_MODE=ok "$scripts/bot-active.sh" 7 --repo owner/repo --since 2026-01-01T00:00:00.500Z
check 1 '' env GH_MODE=ok "$scripts/bot-active.sh" 7 --repo owner/repo --since 2026-01-01T00:00:02Z
printf '[{"check_runs":[]}]\n' > "$tmp/bot-checks.json"
printf '[[{"user":{"login":"ci-bot","type":"User"},"created_at":"2026-01-01T00:00:00Z"},{"user":{"login":"helperbot","type":"User"},"created_at":"2026-01-01T00:00:00Z"}]]\n' > "$tmp/bot-comments.json"
check 0 $'ci-bot\nhelperbot' env GH_MODE=ok "$scripts/bot-active.sh" 7 --repo owner/repo
check 2 'API unavailable' env GH_MODE=api-error "$scripts/bot-active.sh" 7 --repo owner/repo
check 2 'usage' "$scripts/bot-active.sh" 7
rm -f "$tmp/keys-call"
check 0 '' env MODE=ok "$scripts/type-command.sh" w-a '/mode-model a/B-1.2 x'
[[ $(cat "$tmp/keys-call") == 'keys w-a / m o d e - m o d e l space a / shift+b - 1 . 2 space x enter' ]] || { echo 'FAIL: type-command key split' >&2; exit 1; }
rm -f "$tmp/keys-call"
check 1 'usage' "$scripts/type-command.sh" w-a 'new'
check 1 'usage' "$scripts/type-command.sh" w-a '/'
check 1 'usage' "$scripts/type-command.sh" w-a
check 1 'cannot type' "$scripts/type-command.sh" w-a '/a_b'
[[ ! -e $tmp/keys-call ]] || { echo 'FAIL: type-command typed after rejecting input' >&2; exit 1; }
check 1 'invalid_params' env MODE=keys-fail "$scripts/type-command.sh" w-a /new
printf '%s CLI checks plus safety assertions passed\n' "$checks"
