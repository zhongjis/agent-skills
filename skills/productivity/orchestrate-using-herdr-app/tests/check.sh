#!/usr/bin/env bash
# Run isolated CLI fixtures; never contacts a live remote or herdr-core session.
set -euo pipefail
trap 'printf "FAIL: %s:%s (exit %s): %s\n" "${BASH_SOURCE[0]}" "$LINENO" "$?" "$BASH_COMMAND" >&2' ERR
# Capture the real anchor before replacing HOME, and resolve symlink aliases too.
global_data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
global_anchor=$(realpath -m -- "$global_data_home/beads/global/.beads")
scripts=$(realpath "$(dirname -- "${BASH_SOURCE[0]}")/../scripts")
tmp=$(realpath "$(mktemp -d)")
trap 'rm -rf -- "$tmp"' EXIT
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export HOME="$tmp/home"
mkdir -p "$HOME" "$tmp/bin"
export FIXTURE="$tmp" PATH="$tmp/bin:$PATH"
unset HC_TERMINAL_ID ORCH_MAX ORCH_EPIC ORCH_SOURCE ORCH_BEAD BEADS_DOLT_SHARED_SERVER
export BEADS_DIR="$tmp/beads-project/.beads" BEADS_ACTOR=fixture
# Check the effective isolated path, not the global defaults inherited at login.
if [[ $(realpath -m -- "$BEADS_DIR") == "$global_anchor" ]]; then
	printf 'FAIL: refusing global beads anchor: %s\n' "$BEADS_DIR" >&2
	exit 1
fi
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
# Refuse an effective DB path aliased to the anchor before the first bd call.
mkdir -p "$tmp/refusal/beads-project"
ln -s "$global_anchor" "$tmp/refusal/beads-project/.beads"
cat > "$tmp/bin/mktemp" <<'MOCK'
#!/usr/bin/env bash
printf '%s/refusal\n' "$FIXTURE"
MOCK
cat > "$tmp/bin/bd" <<'MOCK'
#!/usr/bin/env bash
printf 'unexpected bd call\n' >> "$BD_GUARD_CALLS"
exit 99
MOCK
chmod +x "$tmp/bin/bd" "$tmp/bin/mktemp"
check 1 'FAIL: refusing global beads anchor' env XDG_DATA_HOME="$global_data_home" BD_GUARD_CALLS="$tmp/bd-calls" bash "${BASH_SOURCE[0]}"
[[ ! -e $tmp/bd-calls ]]
rm "$tmp/bin/bd" "$tmp/bin/mktemp"
mkdir -p "$tmp/beads-project"
# init runs in the enclosing scratch project, never inside .beads or this repo.
(pushd "$tmp/beads-project" >/dev/null; bd init --prefix orch --skip-hooks --skip-agents --non-interactive >/dev/null)
launch_epic=$(bd create 'Launch fixtures' --type epic --silent)
launch_task=$(bd create 'Worker A' --parent "$launch_epic" --metadata '{"key":"worker-a"}' --silent)

cat > "$tmp/bin/hc" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
	connect)
		jq -e '.jsonrpc == "2.0" and .id == 1 and .method == "doc.get" and .params.name == "herdr-app"' >/dev/null
		[[ ${PANE_DOC_FAIL:-false} != true ]] || exit 1
		jq -cn --arg title "${PANE_NAME:-}" '{result:{value:{spaces:[{id:"sp1",children:[{id:"p-other",title:"[o] other"},{id:"p1",type:"block",content:{terminal:"t3"}} + (if $title == "" then {} else {title:$title} end)]}]}}}'
		exit ;;
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
		if [[ $1 == send ]]; then
			printf '%s' "$3" > "$FIXTURE/sent-text"
			if [[ -n ${EXPECT_INSTRUCTION_BEAD:-} ]]; then
				bd comments "$EXPECT_INSTRUCTION_BEAD" --json | jq -e --arg text "$EXPECT_INSTRUCTION_TEXT" '.[-1].text | endswith("\n\n" + $text)' >/dev/null
			fi
			echo sent >> "$FIXTURE/sends"
		fi
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
state=live status="${AGENT_STATUS:-idle}" turn="${AGENT_TURN:-1}"
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
printf '{"state":"%s","status":{"state":"%s"},"turn":%s,"argv":["env","PATH=fixture","AGENT_BROWSER_NAMESPACE=w-worker-a","%s"],"labels":{"resume":"%s"}}\n' "$state" "$status" "$turn" "${AGENT_KIND:-pi}" "${RESUME:-}"
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

# start-worker.sh: bead bootstrap, explicit environment and design-only Pi tokens.
mkdir -p "$tmp/wt-a"
# shellcheck disable=SC2016 # literal Pi tokens
bd update "$launch_task" --description 'Private body $skill:description-only' --design 'Use $skill:x and $skill:y and $skill:x' >/dev/null
# start-worker.sh requires the bead's claim actor to be the agent name.
assign() { bd update "$launch_task" --assignee "$1" >/dev/null; }
check 3 'not assigned to w-worker-a' "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$launch_task"
assign w-worker-a
rm -f "$tmp/gets"
check 0 'turn 1' env MODE=start-turn "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$launch_task"
[[ $(cat "$tmp/gets") == 3 ]]
mapfile -d '' -t argv < "$tmp/argv"
[[ ${argv[*]:0:${#argv[@]}-1} == "run --bg --json --no-notify --name w-worker-a --cwd $tmp/wt-a --outlive-parent --label orch-context=$scripts/worker-context.sh env PATH=$PATH AGENT_BROWSER_NAMESPACE=w-worker-a BEADS_ACTOR=w-worker-a ORCH_BEAD=$launch_task BEADS_DIR=$BEADS_DIR BEADS_DOLT_SHARED_SERVER= pi" ]]
# shellcheck disable=SC2016 # literal Pi triggers
[[ ${argv[-1]} == *"bd show $launch_task"* && ${argv[-1]} == *"agent=w-worker-a in bd comments $launch_task"* && ${argv[-1]} == *'work that bead'* && ${argv[-1]} == *' $skill:orchestrated-worker $skill:x $skill:y ulw' && ${argv[*]} != *'Private body'* ]]
[[ -x $scripts/worker-context.sh && ! -s $tmp/labels ]]
# Exercise nonempty server passthrough without contacting any server: bd itself
# still uses the embedded fixture, while hc captures the worker's environment.
export REAL_BD
REAL_BD=$(command -v bd)
cat > "$tmp/bin/bd" <<'MOCK'
#!/usr/bin/env bash
exec env -u BEADS_DOLT_SHARED_SERVER "$REAL_BD" "$@"
MOCK
chmod +x "$tmp/bin/bd"
check 0 'turn 1' env MODE=settled BEADS_DOLT_SHARED_SERVER=fixture-server:3307 "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$launch_task"
mapfile -d '' -t argv < "$tmp/argv"
[[ ${argv[*]} == *'BEADS_DOLT_SHARED_SERVER=fixture-server:3307'* ]]
rm "$tmp/bin/bd"
check 0 'turn 1' env HC_TERMINAL_ID=orch MODE=settled "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$launch_task"
[[ $(cat "$tmp/labels") == 'label w-worker-a space=sp1' ]]
for kind in pi claude codex; do
	check 0 'turn 1' env MODE=settled "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$launch_task" --kind "$kind"
	mapfile -d '' -t argv < "$tmp/argv"
	[[ ${argv[-1]} == *"bd prime"* && ${argv[-1]} == *"bd show $launch_task"* && ${argv[-1]} == *orchestrated-worker* ]]
	if [[ $kind == pi ]]; then [[ ${argv[-1]} == *' ulw' ]]; fi
	[[ $kind != codex || ${argv[*]} == *'codex --no-daemon '* ]]
done
check 0 'turn 1' env MODE=settled "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$launch_task" --resume s-1
mapfile -d '' -t argv < "$tmp/argv"
[[ ${argv[*]} == *'pi --session s-1 '* ]]
check 0 'turn 1' env MODE=settled "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$launch_task" --kind claude --resume u-1
mapfile -d '' -t argv < "$tmp/argv"
[[ ${argv[*]} == *'claude --resume u-1 '* ]]
check 1 'cannot resume' "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$launch_task" --kind codex --resume x
check 2 'blocked' env MODE=settled AGENT_STATUS=blocked "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$launch_task"
check 2 'terminal finished' env MODE=finished "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$launch_task"
check 2 'not confirmed' env MODE=start-never "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$launch_task"
check 1 'name_taken' env MODE=run-fail "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$launch_task"
check 1 'invalid agent name' "$scripts/start-worker.sh" Worker_A "$tmp/wt-a" "$launch_task"
check 1 'invalid agent name' "$scripts/start-worker.sh" no-prefix "$tmp/wt-a" "$launch_task"
check 1 'no worktree' "$scripts/start-worker.sh" w-worker-a "$tmp/missing" "$launch_task"
check 1 '' "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" orch-missing
check 1 'usage' "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a"
# Events target the explicit bead, independent of epic and agent-name keys.
assign w-unrelated
check 0 'working' env HC_TERMINAL_ID=orch MODE=settled AGENT_STATUS=working "$scripts/start-worker.sh" w-unrelated "$tmp/wt-a" "$launch_task"
bd comments "$launch_task" --json | jq -e '.[-1] | .author == "o-orch" and (.text | startswith("event=dispatched ") and contains("agent=w-unrelated"))' >/dev/null
rows=$(bd comments "$launch_task" --json | jq length)
assign w-worker-a
check 2 'blocked' env HC_TERMINAL_ID=orch MODE=settled AGENT_STATUS=blocked "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$launch_task"
[[ $(bd comments "$launch_task" --json | jq length) == "$rows" ]]
other_epic=$(bd create 'Other session' --type epic --silent)
instruction=$'Fix literal ; $(false)\nSecond line\nulw'

# Mirrors the create-and-claim block in references/supervise.md, local review step 2.
create_review() {
	local round=$1 design=$2 review
	review=$(bd create --title "Review $launch_task round $round" --description "Review $launch_task" --design "$design" --silent) &&
		bd update "$review" --claim --actor r-task >/dev/null &&
		bd dep add "$review" "$launch_task" --type parent-child >/dev/null &&
		bd update "$launch_task" --set-metadata "review_round=$round" >/dev/null &&
		printf '%s\n' "$review"
}
# shellcheck disable=SC2016 # literal Pi tokens
review_one=$(create_review 1 'Review main...HEAD $skill:axis-review')
bd show "$review_one" --json | jq -e --arg task "$launch_task" '.[0] | .assignee == "r-task" and .status == "in_progress" and (.design | contains("main...HEAD")) and any(.dependencies[]; .id == $task and .dependency_type == "parent-child")' >/dev/null
bd show "$launch_task" --json | jq -e '.[0].metadata.review_round | tostring == "1"' >/dev/null
check 1 'issue already claimed by' bd update "$review_one" --claim --actor r-other
check 3 'not assigned in progress' env MODE=settled "$scripts/start-worker.sh" r-other "$tmp/wt-a" "$review_one"

# Reviewer startup uses hc ls's observed string status, not hc get's object.
ln -s "$tmp/wt-a" "$tmp/wt-alias"
printf '{"terminals":[{"address":"t1","name":"w-worker-a","cwd":"%s","state":"live","status":"working"}]}\n' "$tmp/wt-alias" > "$tmp/terminals.json"
: > "$tmp/calls"
check 3 'working in worktree' env MODE=settled "$scripts/start-worker.sh" r-task "$tmp/wt-a" "$review_one"
[[ ! -s $tmp/calls ]]
for terminal in 'live idle w-worker-a' 'finished working w-worker-a' 'live working r-other'; do
	read -r state status name <<< "$terminal"
	printf '{"terminals":[{"address":"t1","name":"%s","cwd":"%s","state":"%s","status":"%s"}]}\n' "$name" "$tmp/wt-a" "$state" "$status" > "$tmp/terminals.json"
	check 0 'turn 1' env MODE=settled "$scripts/start-worker.sh" r-task "$tmp/wt-a" "$review_one"
done
printf '{"terminals":[{"address":"t1","cwd":"%s","state":"live","status":"working"}]}\n' "$tmp/wt-a" > "$tmp/terminals.json"
check 3 'working in worktree' env MODE=settled "$scripts/start-worker.sh" r-task "$tmp/wt-a" "$review_one"
printf '{"terminals":[{"address":"t1","name":"w-worker-a","cwd":"%s","state":"live","status":"working"}]}\n' "$tmp" > "$tmp/terminals.json"
check 0 'turn 1' env MODE=settled "$scripts/start-worker.sh" r-task "$tmp/wt-a" "$review_one"
printf '{"terminals":[]}\n' > "$tmp/terminals.json"
: > "$tmp/calls"
check 0 'turn 1' env MODE=settled "$scripts/start-worker.sh" r-task "$tmp/wt-a" "$review_one"
mapfile -d '' -t argv < "$tmp/argv"
# shellcheck disable=SC2016 # literal Pi tokens
[[ ${argv[*]} == *"BEADS_ACTOR=r-task ORCH_BEAD=$review_one"* && ${argv[-1]} == *"bd show $review_one"* && ${argv[-1]} == *' $skill:orchestrated-worker $skill:axis-review ulw' ]]
check 0 'turn 1' env MODE=settled "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$launch_task"
mapfile -d '' -t argv < "$tmp/argv"
# shellcheck disable=SC2016 # literal Pi tokens
[[ ${argv[-1]} != *'axis-review'* && ${argv[-1]} == *' $skill:x $skill:y ulw' ]]

# Re-instructions persist full text before sending only a bootstrap pointer.
: > "$tmp/calls"
check 0 'sent' env HC_TERMINAL_ID=orch MODE=settled EXPECT_INSTRUCTION_BEAD="$launch_task" EXPECT_INSTRUCTION_TEXT="$instruction" "$scripts/send-reinstruction.sh" w-worker-a "$tmp/wt-a" "$launch_task" "$instruction"
bd comments "$launch_task" --json | jq -e --arg text "$instruction" '.[-1] | .author == "o-orch" and (.text | endswith("\n\n" + $text))' >/dev/null
[[ $(cat "$tmp/calls") == *"bd comments $launch_task"* && $(cat "$tmp/calls") != *"$instruction"* ]]
# An ordinary live relay is a plain agent-scoped pointer: no skill reload.
rm -f "$tmp/sends"
check 0 'sent' env HC_TERMINAL_ID=orch MODE=settled AGENT_KIND=pi "$scripts/send-reinstruction.sh" w-worker-a "$tmp/wt-a" "$launch_task" "$instruction"
sent=$(cat "$tmp/sent-text")
# shellcheck disable=SC2016 # literal Pi triggers
[[ $sent == *"agent=w-worker-a in bd comments $launch_task"* && $sent != *'$skill:'* && $sent != *' ulw' && $sent != *'bd prime'* ]]
# A live Pi after /new needs the same skill activation as first launch.
rm -f "$tmp/sends"
check 0 'sent' env HC_TERMINAL_ID=orch MODE=settled AGENT_KIND=pi AGENT_TURN=0 "$scripts/send-reinstruction.sh" w-worker-a "$tmp/wt-a" "$launch_task" "$instruction" --new-context
sent=$(cat "$tmp/sent-text")
# shellcheck disable=SC2016 # literal machine-consumed Pi triggers
[[ $sent == *' $skill:orchestrated-worker $skill:x $skill:y ulw' && $sent != *'$skill:description-only'* ]]
[[ $sent == *"bd prime"* && $sent == *"bd show $launch_task"* && $sent == *"bd comments $launch_task"* && $sent == *event=report* ]]
# Claude and Codex keep plain bootstrap prompts, without Pi-only activation.
for kind in claude codex; do
	rm -f "$tmp/sends"
	check 0 'sent' env HC_TERMINAL_ID=orch MODE=settled AGENT_KIND="$kind" AGENT_TURN=0 "$scripts/send-reinstruction.sh" w-worker-a "$tmp/wt-a" "$launch_task" "$instruction" --new-context
	sent=$(cat "$tmp/sent-text")
	# shellcheck disable=SC2016 # Pi trigger must not route to other harnesses
	[[ $sent != *'$skill:'* && $sent != *' ulw' ]]
	[[ $sent == *orchestrated-worker* && $sent == *"bd prime"* && $sent == *"bd show $launch_task"* && $sent == *"bd comments $launch_task"* && $sent == *event=report* ]]
done
: > "$tmp/calls"
rows=$(bd comments "$launch_task" --json | jq length)
check 2 'blocked' env HC_TERMINAL_ID=orch MODE=settled AGENT_STATUS=blocked "$scripts/send-reinstruction.sh" w-worker-a "$tmp/wt-a" "$launch_task" "$instruction"
[[ ! -s $tmp/calls && $(bd comments "$launch_task" --json | jq length) == "$rows" ]]
for resume in 'pi --session s-9' 'claude --resume u-9'; do
	rm -f "$tmp/removed"
	check 0 'working' env HC_TERMINAL_ID=orch MODE=hibernated AGENT_STATUS=working RESUME="$resume" "$scripts/send-reinstruction.sh" w-worker-a "$tmp/wt-a" "$launch_task" "$instruction"
	mapfile -d '' -t argv < "$tmp/argv"
	[[ ${argv[*]} == *"$resume"* && ${argv[-1]} == *"bd comments $launch_task"* ]]
done
: > "$tmp/calls"
check 2 'without a resumable session' env HC_TERMINAL_ID=orch MODE=finished "$scripts/send-reinstruction.sh" w-worker-a "$tmp/wt-a" "$launch_task" "$instruction"
[[ ! -s $tmp/calls ]]
check 1 'usage' "$scripts/send-reinstruction.sh" w-worker-a "$tmp/wt-a"
: > "$tmp/calls"
check 1 '' env HC_TERMINAL_ID=orch MODE=settled "$scripts/send-reinstruction.sh" w-worker-a "$tmp/wt-a" orch-missing "$instruction"
[[ ! -s $tmp/calls ]]
check 2 'no turn started' env HC_TERMINAL_ID=orch MODE=send-stuck "$scripts/send-reinstruction.sh" w-worker-a "$tmp/wt-a" "$launch_task" "$instruction"

# Compaction context is all-or-nothing and resolves current assigned work.
bd update "$launch_task" --notes 'Plan: context fixture notes' >/dev/null
bd comments add "$launch_task" $'event=re-instructed agent=w-worker-a\n\nLatest context instruction' >/dev/null
bd comments add "$launch_task" 'event=note detail=not-an-instruction' >/dev/null
bd comments add "$launch_task" $'event=re-instructed agent=w-previous\n\nPrevious assignee instruction' >/dev/null
out=$(BEADS_ACTOR=w-worker-a ORCH_BEAD="$launch_task" "$scripts/worker-context.sh")
skill_text=$(cat "$scripts/../../orchestrated-worker/SKILL.md")
# bd show includes comment history; the final block is the selected instruction.
[[ $out == "$skill_text"* && $out == *'context fixture notes'* && $out == *$'\n\nevent=re-instructed agent=w-worker-a\n\nLatest context instruction' ]]
# A failed assignee query still falls back to ORCH_BEAD.
cat > "$tmp/bin/bd" <<'MOCK'
#!/usr/bin/env bash
[[ $1 != list ]] || exit 1
exec "$REAL_BD" "$@"
MOCK
chmod +x "$tmp/bin/bd"
out=$(BEADS_ACTOR=w-worker-a ORCH_BEAD="$launch_task" "$scripts/worker-context.sh")
[[ $out == *'context fixture notes'* ]]
rm "$tmp/bin/bd"
# Installed layout: the skill folder is a symlink into a store without siblings.
mkdir -p "$tmp/store/pkg" "$tmp/harness"
cp -r "$scripts/.." "$tmp/store/pkg/orchestrate-using-herdr-app"
ln -s "$tmp/store/pkg/orchestrate-using-herdr-app" "$tmp/harness/orchestrate-using-herdr-app"
printf 'Installed standing contract\n' > "$tmp/installed-skill"
mkdir -p "$tmp/harness/orchestrated-worker"
ln -s "$tmp/installed-skill" "$tmp/harness/orchestrated-worker/SKILL.md"
out=$(BEADS_ACTOR=w-worker-a ORCH_BEAD="$launch_task" "$tmp/harness/orchestrate-using-herdr-app/scripts/worker-context.sh")
[[ $out == 'Installed standing contract'* && $out == *'context fixture notes'* ]]
current=$(bd create 'Current assigned work' --assignee w-context --silent)
bd update "$current" --status in_progress --notes 'Current notepad' >/dev/null
out=$(BEADS_ACTOR=w-context ORCH_BEAD="$launch_task" "$scripts/worker-context.sh")
[[ $out == *'Current notepad'* && $out != *'context fixture notes'* ]]
newest=$(bd create 'Newer assigned work' --assignee w-context --silent)
bd update "$newest" --status in_progress --notes 'Newest notepad' >/dev/null
out=$(BEADS_ACTOR=w-context ORCH_BEAD="$launch_task" "$scripts/worker-context.sh")
[[ $out == *'Newest notepad'* && $out != *'Current notepad'* ]]
[[ -z $(env -u ORCH_BEAD BEADS_ACTOR=unassigned "$scripts/worker-context.sh") ]]
[[ -z $(ORCH_BEAD=orch-missing BEADS_ACTOR=unassigned "$scripts/worker-context.sh") ]]
[[ -z $(BEADS_DIR="$tmp/nonexistent/.beads" "$scripts/worker-context.sh" 2>&1) ]]

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
rows=$(bd comments "$launch_task" --json | jq length)
assign w-e
check 4 'no free slot' env ORCH_MAX=2 HC_TERMINAL_ID=orch MODE=settled "$scripts/start-worker.sh" w-e "$tmp/wt-a" "$launch_task"
check 4 'no free slot' env ORCH_MAX=2 HC_TERMINAL_ID=orch MODE=settled "$scripts/send-reinstruction.sh" w-c "$tmp/wt-a" "$launch_task" "$instruction"
check 4 'no free slot' env HC_TERMINAL_ID=orch ORCH_MAX=2 HC_TERMINAL_ID=orch MODE=settled "$scripts/send-reinstruction.sh" r-x "$tmp/wt-a" "$launch_task" "$instruction" --last-reviewed HEAD
[[ ! -s $tmp/calls && $(bd comments "$launch_task" --json | jq length) == "$rows" ]] || { echo 'FAIL: a refused start or follow-up must have no side effects'; exit 1; }
# A follow-up to an agent already working takes no new slot.
check 0 'sent' env HC_TERMINAL_ID=orch ORCH_MAX=2 HC_TERMINAL_ID=orch MODE=settled AGENT_STATUS=working "$scripts/send-reinstruction.sh" w-a "$tmp/wt-a" "$launch_task" "$instruction"
check 0 'turn 1' env ORCH_MAX=3 HC_TERMINAL_ID=orch MODE=settled "$scripts/start-worker.sh" w-e "$tmp/wt-a" "$launch_task"
mapfile -d '' -t argv < "$tmp/argv"
[[ ${argv[*]} == *"--outlive-parent --label orch-context=$scripts/worker-context.sh --label orch=orch env "* ]] || { echo 'FAIL: a worker must carry its orchestrator label from launch'; exit 1; }
printf '{"terminals":[]}\n' > "$tmp/terminals.json"
: > "$tmp/calls"

# A later reviewer round cannot bypass the base gate, even on resume.
: > "$tmp/calls"
check 3 'requires --last-reviewed' env HC_TERMINAL_ID=orch MODE=settled "$scripts/send-reinstruction.sh" r-task "$tmp/wt-a" "$launch_task" "$instruction"
check 3 'requires --last-reviewed' env HC_TERMINAL_ID=orch MODE=finished "$scripts/send-reinstruction.sh" r-task "$tmp/wt-a" "$launch_task" "$instruction"
[[ ! -s $tmp/calls ]]

# herdr-app mock: init never touches the person's real window.
cat > "$tmp/bin/herdr-app" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
	ls) printf '{"spaces":[{"tabs":[{"id":"tb1","name":"[o] shared tab","terminals":[{"terminal":"other","pane":"p-other","name":"[o] other"},{"terminal":"t3","pane":"p1","name":"pi"}]}]}]}' ;;
	do)
		[[ $# == 3 && $2 == pane.rename ]] || exit 1
		printf '%s\n' "$3" >> "$FIXTURE/herdr" ;;
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
rm -f "$tmp/herdr"
check 1 'shared blocker' env HC_TERMINAL_ID=t3 PANE_NAME='[o] api' "$scripts/orchestrate-init.sh" api --mode '--off'
[[ $(tail -n 1 "$tmp/labels") == 'label t3 orch-context=' ]]
jq -se 'length == 1 and .[0] == {pane:"p1",name:""}' "$tmp/herdr" >/dev/null
rm "$tmp/bin/bd"
# Outside Git, use the cwd as repo metadata and allow --off without creating an epic.
count=$(bd list --type epic --all --limit 0 --json | jq 'length')
out=$(pushd "$tmp/wt-a" >/dev/null; HC_TERMINAL_ID=outside "$scripts/orchestrate-init.sh" api --mode '--off')
[[ $out == $'unset ORCH_EPIC\nunset ORCH_MAX' && $(bd list --type epic --all --limit 0 --json | jq 'length') == "$count" ]]
out=$(pushd "$tmp/wt-a" >/dev/null; HC_TERMINAL_ID=outside "$scripts/orchestrate-init.sh" api)
outside_epic=$(sed -n 's/^epic=//p' <<<"$out")
bd show "$outside_epic" --json | jq -e --arg repo "$tmp/wt-a" '.[0].metadata.repo == $repo' >/dev/null
out=$(pushd "$tmp/wt-a" >/dev/null; HC_TERMINAL_ID=outside "$scripts/orchestrate-init.sh" api --mode '--off')
[[ $out == *"epic=$outside_epic"* && $(bd show "$outside_epic" --json | jq -r '.[0].status') == closed ]]
rm -f "$tmp/herdr"
out=$(HC_TERMINAL_ID=t3 ORCH_SOURCE=fixture-source "$scripts/orchestrate-init.sh" api --mode '--auto --track')
epic=$(sed -n 's/^epic=//p' <<<"$out")
[[ -n $epic && $out == *"export ORCH_EPIC=$epic"* ]]
repo=$(git rev-parse --show-toplevel)
bd show "$epic" --json | jq -e --arg repo "$repo" '.[0] | .issue_type == "epic" and .status == "open" and .metadata == {session:"t3",repo:$repo,source:"fixture-source"}' >/dev/null
bd comments "$epic" --json | jq -e '.[-1] | .author == "o-t3" and .text == "event=mode flags=--auto --track max=none"' >/dev/null
jq -se 'length == 1 and .[0] == {pane:"p1",name:"[o] api"}' "$tmp/herdr" >/dev/null
[[ $(tail -n 1 "$tmp/labels") == "label t3 orch-context=$scripts/compact-context.sh" ]]
ln -s "$scripts" "$tmp/logical-scripts"
check 0 "epic=$epic" env HC_TERMINAL_ID=t3 "$tmp/logical-scripts/orchestrate-init.sh" api
[[ $(tail -n 1 "$tmp/labels") == "label t3 orch-context=$tmp/logical-scripts/compact-context.sh" ]]
check 0 "epic=$epic" env HC_TERMINAL_ID=t3 ORCH_EPIC="$other_epic" "$scripts/orchestrate-init.sh" api
check 0 "export ORCH_EPIC=$epic" env HC_TERMINAL_ID=t3 "$scripts/orchestrate-init.sh" api
rm -f "$tmp/herdr"
check 0 "epic=$epic" env HC_TERMINAL_ID=t3 "$scripts/orchestrate-init.sh" retro-skills_ui-audit-fix
jq -se 'length == 1 and .[0] == {pane:"p1",name:"[o] retro skills ui audit"}' "$tmp/herdr" >/dev/null
rm -f "$tmp/herdr"
check 0 "epic=$epic" env HC_TERMINAL_ID=t3 PANE_NAME='[o] existing title' "$scripts/orchestrate-init.sh" api
[[ ! -e "$tmp/herdr" ]] || { echo 'FAIL: init must leave an already marked pane'; exit 1; }
check 0 "epic=$epic" env HC_TERMINAL_ID=t3 PANE_NAME='[w] previous title' "$scripts/orchestrate-init.sh" 'quoted-"title"_path\name'
jq -se 'length == 1 and .[0] == {pane:"p1",name:"[o] quoted \"title\" path\\name"}' "$tmp/herdr" >/dev/null
rm -f "$tmp/herdr"
check 0 "epic=$epic" env HC_TERMINAL_ID=t3 PANE_DOC_FAIL=true "$scripts/orchestrate-init.sh" api
[[ ! -e "$tmp/herdr" ]]
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
# --off always records mode and clears context/title; open children prevent closure.
init_child=$(bd create 'Unfinished' --parent "$epic" --metadata '{"key":"unfinished"}' --silent)
rm -f "$tmp/herdr"
check 0 "epic=$epic" env HC_TERMINAL_ID=t3 PANE_NAME='[o] api' "$scripts/orchestrate-init.sh" api --mode '--off'
[[ $(bd show "$epic" --json | jq -r '.[0].status') == open && $(tail -n 1 "$tmp/labels") == 'label t3 orch-context=' ]]
jq -se 'length == 1 and .[0] == {pane:"p1",name:""}' "$tmp/herdr" >/dev/null
rm -f "$tmp/herdr"
check 0 "epic=$epic" env HC_TERMINAL_ID=t3 PANE_NAME='[w] user title' "$scripts/orchestrate-init.sh" api --mode '--off'
[[ ! -e "$tmp/herdr" ]]
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
# Repeated --off leaves no junk epic after the previous one closed.
count=$(bd list --type epic --all --limit 0 --json | jq 'length')
check 0 'unset ORCH_EPIC' env HC_TERMINAL_ID=t3 "$scripts/orchestrate-init.sh" fresh --mode '--off'
[[ $(bd list --type epic --all --limit 0 --json | jq 'length') == "$count" ]]

# --from links a peer's epic discovered-from its handoff bead; --off closes both.
count=$(bd list --type epic --all --limit 0 --json | jq 'length')
check 1 'orch-missing not found' env HC_TERMINAL_ID=t5 "$scripts/orchestrate-init.sh" peer --from orch-missing
[[ $(bd list --type epic --all --limit 0 --json | jq 'length') == "$count" ]]
check 1 'usage' env HC_TERMINAL_ID=t5 "$scripts/orchestrate-init.sh" peer --from
handoff=$(bd create 'Side issue' --silent)
bd update "$handoff" --claim --actor h-side >/dev/null
out=$(HC_TERMINAL_ID=t5 "$scripts/orchestrate-init.sh" peer --mode '--watch' --from "$handoff")
peer_epic=$(sed -n 's/^epic=//p' <<<"$out")
check 0 "epic=$peer_epic" env HC_TERMINAL_ID=t5 "$scripts/orchestrate-init.sh" peer --from "$handoff"
bd dep list "$peer_epic" --type discovered-from --json | jq -e --arg h "$handoff" 'map(.id) == [$h]' >/dev/null
check 0 "epic=$peer_epic" env HC_TERMINAL_ID=t5 "$scripts/orchestrate-init.sh" peer --mode '--off'
[[ $(bd show "$peer_epic" --json | jq -r '.[0].status') == closed && $(bd show "$handoff" --json | jq -r '.[0].status') == closed ]]
# An option-shaped ID is an ID, not a bd flag.
check 1 'not found' env HC_TERMINAL_ID=t5 "$scripts/orchestrate-init.sh" peer --from --help
# A failed handoff close after the epic closed is retried by the next --off.
retry_handoff=$(bd create 'Retry side issue' --silent)
bd update "$retry_handoff" --claim --actor h-retry >/dev/null
out=$(HC_TERMINAL_ID=t6 "$scripts/orchestrate-init.sh" retry --from "$retry_handoff")
retry_epic=$(sed -n 's/^epic=//p' <<<"$out")
real_bd=$(command -v bd)
cat > "$tmp/bin/bd" <<MOCK
#!/usr/bin/env bash
[[ \$1 == close && \$2 == "\${FAIL_CLOSE:-}" ]] && exit 1
exec "$real_bd" "\$@"
MOCK
chmod +x "$tmp/bin/bd"
check 1 '' env HC_TERMINAL_ID=t6 FAIL_CLOSE="$retry_handoff" "$scripts/orchestrate-init.sh" retry --mode '--off'
[[ $(bd show "$retry_epic" --json | jq -r '.[0].status') == closed && $(bd show "$retry_handoff" --json | jq -r '.[0].status') != closed ]]
count=$(bd list --type epic --all --limit 0 --json | jq 'length')
check 0 'unset ORCH_EPIC' env HC_TERMINAL_ID=t6 "$scripts/orchestrate-init.sh" retry --mode '--off'
[[ $(bd show "$retry_handoff" --json | jq -r '.[0].status') == closed && $(bd list --type epic --all --limit 0 --json | jq 'length') == "$count" ]]
rm "$tmp/bin/bd"

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
# A later round revisits the same reviewer with a new bead.
: > "$tmp/calls"
check 3 'not a commit' env HC_TERMINAL_ID=orch MODE=settled "$scripts/send-reinstruction.sh" r-task "$tmp/work" "$review_one" "$instruction" --last-reviewed missing
[[ ! -s $tmp/calls ]]
bd update "$review_one" --notes 'Round one findings' --actor r-task >/dev/null
bd comments add "$review_one" "event=report kind=done head=$main" --actor r-task >/dev/null
check 1 'assignee is "r-task", actor is "o-orch"' bd close "$review_one" --actor o-orch
bd close "$review_one" --actor r-task >/dev/null
review_body=$'Review fixes\nReport by ending your turn; never `hc send` to the orchestrator.\nulw'
instruction="$review_body"
# shellcheck disable=SC2016 # literal Pi tokens
review_task=$(create_review 2 "Review $main..HEAD "'$skill:axis-review')
bd show "$launch_task" --json | jq -e '.[0].metadata.review_round | tostring == "2"' >/dev/null
check 3 'not assigned in progress' env HC_TERMINAL_ID=orch MODE=settled "$scripts/send-reinstruction.sh" r-task "$tmp/work" "$review_one" "$instruction" --last-reviewed "$main"
check 0 'sent' env HC_TERMINAL_ID=orch ORCH_EPIC="$launch_epic" MODE=settled "$scripts/send-reinstruction.sh" r-task "$tmp/work" "$review_task" "$instruction" --last-reviewed "$main"
bd comments "$review_task" --json | jq -e --arg base "$main" --arg bead "$review_task" '.[-1].text | startswith("event=re-instructed agent=r-task bead=" + $bead + " last-reviewed=" + $base)' >/dev/null
sent=$(cat "$tmp/sent-text")
[[ $sent == *"Review bead $review_task is your current bead for all reads, notes, and reports"* && $sent == *"bd show $review_task"* && $sent == *"bd comments $review_task"* ]]
out=$(BEADS_ACTOR=r-task ORCH_BEAD="$review_one" "$scripts/worker-context.sh")
[[ $out == *"$review_task"* && $out == *"$main..HEAD"* && $out == *"$review_body"* && $out != *'Round one findings'* ]]
# After /new, tokens come from the new review bead's design.
check 0 'sent' env HC_TERMINAL_ID=orch MODE=settled "$scripts/send-reinstruction.sh" r-task "$tmp/work" "$review_task" "$instruction" --last-reviewed "$main" --new-context
sent=$(cat "$tmp/sent-text")
# shellcheck disable=SC2016 # literal Pi tokens
[[ $sent == *"bd prime"* && $sent == *"agent=r-task in bd comments $review_task"* && $sent == *' $skill:orchestrated-worker $skill:axis-review ulw' ]]
# Same reviewer name and session survive finished-terminal revival.
rm -f "$tmp/removed"
check 0 'working' env HC_TERMINAL_ID=orch MODE=hibernated AGENT_STATUS=working RESUME='pi --session review-9' "$scripts/send-reinstruction.sh" r-task "$tmp/work" "$review_task" "$instruction" --last-reviewed "$head"
mapfile -d '' -t argv < "$tmp/argv"
[[ ${argv[*]} == *'--name r-task'* && ${argv[*]} == *"ORCH_BEAD=$review_task"* && ${argv[*]} == *'pi --session review-9'* && ${argv[-1]} == *' ulw' ]]

bd comments "$review_task" --json | jq -e --arg bead "$review_task" --arg base "$head" --arg body "$review_body" '
	any(.[]; .text | startswith("event=re-instructed agent=r-task bead=" + $bead + " last-reviewed=" + $base + "\n\n") and contains($base + "..HEAD") and endswith("\n\n" + $body))' >/dev/null

# Mirrors the one-write follow-up form in orchestrated-worker/SKILL.md (Bead permissions and notepad).
for source_bead in "$launch_task" "$review_task"; do
	gap=$(bd create --title 'Later gap' --deps "discovered-from:$source_bead" --labels follow-up --description 'Gap: missing example; small; docs' --status deferred --silent)
	bd show "$gap" --json | jq -e --arg source "$source_bead" '.[0] | .status == "deferred" and (.assignee // "") == "" and .labels == ["follow-up"] and ((.metadata // {}) | length == 0) and (.dependencies | length == 1 and .[0].id == $source and .[0].dependency_type == "discovered-from")' >/dev/null
	bd ready --parent "$launch_epic" --json | jq -e --arg gap "$gap" 'all(.[]; .id != $gap)' >/dev/null
	bd dep list "$source_bead" --direction=up --type discovered-from --json | jq -e --arg gap "$gap" 'any(.[]; .id == $gap)' >/dev/null
done

git -C "$tmp/work" switch -q --orphan unrelated
git -C "$tmp/work" commit -qm unrelated --allow-empty
: > "$tmp/calls"
check 3 'not an ancestor' env HC_TERMINAL_ID=orch MODE=settled "$scripts/send-reinstruction.sh" r-task "$tmp/work" "$review_task" "$instruction" --last-reviewed "$main"
[[ ! -s $tmp/calls ]]

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
check 0 '0 stopped' env HC_TERMINAL_ID=orch "$scripts/reap-worker.sh" --bead "$launch_task" "$tmp/wt" w-worker-a --keep-agent
bd comments "$launch_task" --json | jq -e '.[-1].text | test("^event=reaped stopped=browser(,compose)?$")' >/dev/null
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
# A failing source pre-push hook must not block the remote branch delete.
printf '#!/usr/bin/env bash\nexit 1\n' > "$tmp/full-src/.git/hooks/pre-push"
chmod +x "$tmp/full-src/.git/hooks/pre-push"
echo "$$" > "$tmp/pids"; : > "$tmp/listeners"; : > "$tmp/removed-names"
printf 'w-a1-topic\nr-a1-topic\n' > "$tmp/full-terms"
check 1 'needs HC_TERMINAL_ID' env -u HC_TERMINAL_ID "$scripts/reap-worker.sh" --bead "$launch_task" "$tmp/full-wt" w-a1-topic --full topic-full
[[ -e $tmp/full-wt ]]
check 0 'full cleanup w-a1-topic' env MODE=full HC_TERMINAL_ID=orch "$scripts/reap-worker.sh" --bead "$launch_task" "$tmp/full-wt" w-a1-topic --full topic-full
# The script records what it removed, so no session writes reaped by hand.
bd comments "$launch_task" --json | jq -e '.[-1] | .author == "o-orch" and (.text | test("^event=reaped stopped=([a-z-]+,)*worker,reviewer,worktree,branch,remote-branch$"))' >/dev/null
[[ $(sort "$tmp/removed-names") == $'r-a1-topic\nw-a1-topic' ]]
[[ ! -e $tmp/full-wt ]]
check 1 '' git -C "$tmp/full-src" rev-parse --verify -q refs/heads/topic-full
check 1 '' git --git-dir="$tmp/full-remote" rev-parse --verify -q refs/heads/topic-full

# --full --keep-remote: non-merge work keeps its pushed branch and refuses dirty or unpushed heads.
git -C "$tmp/full-src" worktree add -q -b topic-keep "$tmp/keep-wt"
git -C "$tmp/full-src" push -q --no-verify origin topic-keep
printf 'w-a2-keep\nr-a2-keep\n' > "$tmp/full-terms"; : > "$tmp/removed-names"
touch "$tmp/keep-wt/dirty"
check 1 'uncommitted work' env MODE=full "$scripts/reap-worker.sh" "$tmp/keep-wt" w-a2-keep --full topic-keep --keep-remote
git -C "$tmp/keep-wt" add dirty && git -C "$tmp/keep-wt" -c user.email=f@example.invalid -c user.name=F commit -qm dirty
check 1 'head not on origin' env MODE=full "$scripts/reap-worker.sh" "$tmp/keep-wt" w-a2-keep --full topic-keep --keep-remote
[[ -e $tmp/keep-wt ]] && [[ ! -s $tmp/removed-names ]]
git -C "$tmp/full-src" push -q --no-verify origin topic-keep
check 0 'full cleanup w-a2-keep' env MODE=full "$scripts/reap-worker.sh" "$tmp/keep-wt" w-a2-keep --full topic-keep --keep-remote
[[ ! -e $tmp/keep-wt ]]
check 1 '' git -C "$tmp/full-src" rev-parse --verify -q refs/heads/topic-keep
check 0 '' git --git-dir="$tmp/full-remote" rev-parse --verify -q refs/heads/topic-keep
check 1 'usage' "$scripts/reap-worker.sh" "$tmp/keep-wt" w-a2-keep --full topic-keep --bogus
rm "$tmp/bin/uname" "$tmp/bin/ps" "$tmp/bin/lsof"

# event.sh: real comments, fixed event vocabulary, attributed one-line fields.
status_epic=$(bd create 'Status session' --type epic --metadata '{"session":"status-orch"}' --silent)
alpha=$(bd create Alpha --parent "$status_epic" --metadata '{"key":"alpha"}' --silent)
for event in mode ticketed dispatched handed-off queued re-instructed ready merged settled reaped blocked decided note adopted; do
	case "$event" in
		merged) required=merged_sha=0123456789abcdef0123456789abcdef01234567 ;;
		settled) required=result=succeeded ;;
		reaped) required=stopped=browser,worker,remote-branch ;;
		*) required=note=x ;;
	esac
	check 0 '' env HC_TERMINAL_ID=events "$scripts/event.sh" "$alpha" "$event" "$required" 'detail=spaces stay together'
done
comments=$(bd comments "$alpha" --json)
jq -e 'length == 14 and all(.[]; .author == "o-events" and (.text | endswith(" detail=spaces stay together")))' <<<"$comments" >/dev/null
check 1 'usage' "$scripts/event.sh"
check 1 'invalid event' env HC_TERMINAL_ID=events "$scripts/event.sh" "$alpha" reviewed
check 1 'HC_TERMINAL_ID' env -u HC_TERMINAL_ID "$scripts/event.sh" "$alpha" note
for field in missing-equals '=empty-key' 'event=note' $'detail=new\nline' $'detail=carriage\rreturn' $'detail=tab\tvalue'; do
	check 1 'invalid event field' env HC_TERMINAL_ID=events "$scripts/event.sh" "$alpha" note "$field"
done
[[ $(bd comments "$alpha" --json | jq 'length') == 14 ]]
# Shared fields are enforced, so stale prose cannot write them free-form.
for bad in 'merged sha=0123456789abcdef0123456789abcdef01234567' 'merged merged_sha=abc' 'settled result=done' 'settled detail=x' 'reaped stopped=browser namespace' 'reaped stopped=worker,terminals' 'reaped detail=x'; do
	read -r ev field <<<"$bad"
	check 1 "$ev needs" env HC_TERMINAL_ID=events "$scripts/event.sh" "$alpha" "$ev" "$field"
done
[[ $(bd comments "$alpha" --json | jq 'length') == 14 ]]
bd show "$alpha" --json | jq -e '.[0].metadata.merged_sha == "0123456789abcdef0123456789abcdef01234567"' >/dev/null
# A needs-user hold persists as metadata until the answer; other decisions keep other holds.
check 0 '' env HC_TERMINAL_ID=events "$scripts/event.sh" "$alpha" blocked reason=needs-user --body 'Approve the test exception?'
bd show "$alpha" --json | jq -e '.[0].metadata.blocked_reason == "needs-user"' >/dev/null
check 0 '' env HC_TERMINAL_ID=events "$scripts/event.sh" "$alpha" note detail=later
bd show "$alpha" --json | jq -e '.[0].metadata.blocked_reason == "needs-user"' >/dev/null
check 0 '' env HC_TERMINAL_ID=events "$scripts/event.sh" "$alpha" decided by=user 'q=Approve?' a=yes
bd show "$alpha" --json | jq -e '.[0].metadata.blocked_reason == null' >/dev/null
bd update "$alpha" --set-metadata blocked_reason=pull-skipped >/dev/null
check 0 '' env HC_TERMINAL_ID=events "$scripts/event.sh" "$alpha" decided by=orchestrator 'q=Other?' a=no
bd show "$alpha" --json | jq -e '.[0].metadata.blocked_reason == "pull-skipped"' >/dev/null
bd update "$alpha" --unset-metadata blocked_reason --unset-metadata merged_sha >/dev/null
# --body may follow the k=v fields; it goes after the parseable first line.
check 0 '' env HC_TERMINAL_ID=events "$scripts/event.sh" "$alpha" note detail=one --body $'free\ntext' extra=two
bd comments "$alpha" --json | jq -e 'last.text == "event=note detail=one extra=two\n\nfree\ntext"' >/dev/null
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
check 0 '' env HC_TERMINAL_ID=status-orch "$scripts/event.sh" "$alpha" ready 'detail=PR #7 | green' head=head7
# Non-event comments do not replace the latest milestone.
bd comments add "$alpha" 'Human observation, not an event' >/dev/null
check 0 '' env HC_TERMINAL_ID=status-orch "$scripts/event.sh" "$beta" dispatched agent=w-beta terminal=t10
check 0 '' env HC_TERMINAL_ID=status-orch "$scripts/event.sh" "$beta" reaped stopped=reviewer
bd close "$beta" >/dev/null
check 0 '' env HC_TERMINAL_ID=status-orch "$scripts/event.sh" "$gamma" dispatched agent=w-gamma terminal=t11
check 0 '' env HC_TERMINAL_ID=status-orch "$scripts/event.sh" "$status_epic" note detail=one
check 0 '' env HC_TERMINAL_ID=status-orch "$scripts/event.sh" "$status_epic" note detail=two
alpha_since=$(bd comments "$alpha" --json | jq -r '[.[] | select(.text | startswith("event=ready "))][-1].created_at')
delta_since=$(bd show "$delta" --json | jq -r '.[0].created_at')
out=$("$scripts/status.sh" "$status_epic")
[[ $out == *'| Task | Worker | Event | Result | Evidence | Since |'* && $out == *'| alpha | w-alpha (t9) | ready | in_progress |'* && $out == *'| beta | w-beta (t10) | reaped | closed |'* ]]
[[ $(grep -c '^| alpha |' <<<"$out") == 1 && $out != *'| all |'* && $out == *'2 notes (all).'* ]]
[[ $(awk -F'|' '/^\| (alpha|beta|gamma|delta) \|/ { gsub(/ /, "", $2); print $2 }' <<<"$out") == $'alpha\nbeta\ngamma\ndelta' ]]
for evidence in 'PR #7 &#124; green' 'head=head7' 'pr_url=https://example.invalid/pr/7' 'head_sha=head7' 'merged_sha=merge7' 'review_round=3' 'blocked_reason=needs approval'; do
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

# Import fixtures reuse this isolated DB and real bd for every non-pull call.
# shellcheck source=import.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/import.sh"

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
