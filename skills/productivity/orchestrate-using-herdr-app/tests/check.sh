#!/usr/bin/env bash
# Run isolated CLI fixtures; never contacts a live remote or herdr-core session.
set -euo pipefail
scripts=$(realpath "$(dirname -- "${BASH_SOURCE[0]}")/../scripts")
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export HOME="$tmp/home"
mkdir -p "$HOME" "$tmp/bin"
export FIXTURE="$tmp" PATH="$tmp/bin:$PATH"
unset HC_TERMINAL_ID
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
cat > "$tmp/bin/hc" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
	ls) cat "${FIXTURE}/terminals.json"; exit ;;
	run)
		printf '%s\n' "$*" >> "$FIXTURE/calls"
		printf '%s\0' "$@" > "$FIXTURE/argv"
		[[ $MODE != run-fail ]] || { echo '{"error":{"kind":"name_taken"}}' >&2; exit 1; }
		echo '{"address":"t9","state":"live","turn":0}'
		exit ;;
	label)
		printf '%s\n' "$*" >> "$FIXTURE/labels"
		exit ;;
	send|rm)
		printf '%s\n' "$*" >> "$FIXTURE/calls"
		[[ $1 != rm ]] || touch "$FIXTURE/removed"
		exit ;;
	wait)
		[[ $MODE != gone ]] || { echo '{"error":{"kind":"not_found"}}' >&2; exit 3; }
		[[ $MODE != wait-error ]] || { echo '{"error":{"kind":"io"}}' >&2; exit 1; }
		case "$MODE" in quiet*) echo '{"reason":"timeout"}' ;; *) echo '{"reason":"status"}' ;; esac
		exit ;;
	read)
		r=$(( $(cat "$FIXTURE/reads" 2>/dev/null || echo 0) + 1 ))
		echo "$r" > "$FIXTURE/reads"
		printf 'transcript: 1. Goal blocked earlier\n'; printf 'line\n%.0s' {1..20}
		case "$MODE" in
			quiet) printf '⠋ Working (%sm%ss · ↓ 1.2k tokens) 4%s tok/s 12:0%s\n' "$r" "$r" "$r" "$r" ;;
			quiet-hint) printf '❯ 1. Yes\nGoal blocked (/goal resume)\n' ;;
			compact) [[ $r -ge 2 ]] || printf 'Compacting\n' ;;
		esac
		exit ;;
esac
[[ $2 != orch ]] || { echo '{"labels":{"herdr.space":"sp1"}}'; exit; }
n=$(( $(cat "$FIXTURE/gets" 2>/dev/null || echo 0) + 1 ))
echo "$n" > "$FIXTURE/gets"
state=live status="${AGENT_STATUS:-idle}" turn=1
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
cat > "$tmp/bin/gh" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
[[ $PWD == "$FIXTURE/work" ]]
[[ $* == "pr view $3 --json mergeable,headRefOid,statusCheckRollup" ]]
[[ $MODE != gh-error ]] || { echo 'authentication failed' >&2; exit 1; }
[[ $MODE != gh-malformed ]] || { echo broken; exit; }
mergeable=MERGEABLE
status=COMPLETED
[[ $MODE != conflict || $3 != 22 ]] || mergeable=CONFLICTING
if [[ $MODE == pending && $3 == 11 && ! -e $FIXTURE/polled ]]; then
	status=WAITING
	touch "$FIXTURE/polled"
fi
printf '{"mergeable":"%s","headRefOid":"head-%s","statusCheckRollup":[{"status":"%s","conclusion":"FAILURE","name":"unit"},{"state":"ERROR","context":"deploy"}]}\n' "$mergeable" "$3" "$status"
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
[[ $(cat "$tmp/reads") -eq 2 ]]
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

# start-worker.sh: short prompt, literal brief outside cwd, confirm by turn.
mkdir -p "$tmp/wt-a"
# shellcheck disable=SC2016 # literal brief text
printf 'Fix $skill:x and $skill:y ; $(false)\nPrivate brief body\nulw' > "$tmp/brief with spaces"
ln -s 'brief with spaces' "$tmp/brief"
printf -v prompt 'Read the brief file at %q and follow it.' "$tmp/brief with spaces"
pi_prompt="$prompt \$skill:x \$skill:y ulw"
rm -f "$tmp/gets"
check 0 'turn 1' env MODE=start-turn "$scripts/start-worker.sh" worker-a "$tmp/wt-a" "$tmp/brief"
[[ $(cat "$tmp/gets") == 3 ]]
mapfile -d '' -t argv < "$tmp/argv"
[[ ${argv[*]} == "run --bg --json --no-notify --name worker-a --cwd $tmp/wt-a --outlive-parent env AGENT_BROWSER_NAMESPACE=worker-a pi $pi_prompt" ]] || { echo 'FAIL: short Pi argv must reference absolute brief and preserve skill/ulw triggers'; exit 1; }
[[ ${argv[-1]} == "$pi_prompt" && ${argv[*]} != *'Private brief body'* ]]
[[ ! -s $tmp/labels ]]
# A relative brief resolves before hc switches to the worker cwd.
check 0 'turn 1' env MODE=settled "$scripts/start-worker.sh" worker-a "$tmp/wt-a" "$(realpath --relative-to="$PWD" "$tmp/brief with spaces")"
mapfile -d '' -t argv < "$tmp/argv"
[[ ${argv[-1]} == "$pi_prompt" ]]
[[ $(cat "$tmp/brief") == "Fix \$skill:x and \$skill:y ; \$(false)"$'\nPrivate brief body\nulw' ]]
check 0 '' env MODE=settled HC_TERMINAL_ID=orch "$scripts/start-worker.sh" worker-a "$tmp/wt-a" "$tmp/brief"
[[ $(cat "$tmp/labels") == "label worker-a space=sp1" ]]
: > "$tmp/calls"
check 0 '' env MODE=settled "$scripts/start-worker.sh" worker-a "$tmp/wt-a" "$tmp/brief" --resume s-1
mapfile -d '' -t argv < "$tmp/argv"
[[ ${argv[*]} == *"AGENT_BROWSER_NAMESPACE=worker-a pi --session s-1 $pi_prompt" ]]
: > "$tmp/calls"
check 0 '' env MODE=settled "$scripts/start-worker.sh" worker-a "$tmp/wt-a" "$tmp/brief" --kind claude --resume u-1
mapfile -d '' -t argv < "$tmp/argv"
[[ ${argv[*]} == *"AGENT_BROWSER_NAMESPACE=worker-a claude --resume u-1 $prompt" && ${argv[-1]} == "$prompt" ]]
check 1 'cannot resume' "$scripts/start-worker.sh" worker-a "$tmp/wt-a" "$tmp/brief" --kind codex --resume x
: > "$tmp/calls"
check 0 '' env MODE=settled "$scripts/start-worker.sh" worker-a "$tmp/wt-a" "$tmp/brief" --kind codex
mapfile -d '' -t argv < "$tmp/argv"
[[ ${argv[*]} == *"AGENT_BROWSER_NAMESPACE=worker-a codex --no-daemon $prompt" && ${argv[-1]} == "$prompt" ]]
check 0 'working' env MODE=settled AGENT_STATUS=working "$scripts/start-worker.sh" worker-a "$tmp/wt-a" "$tmp/brief" --kind claude
check 2 'blocked' env MODE=settled AGENT_STATUS=blocked "$scripts/start-worker.sh" worker-a "$tmp/wt-a" "$tmp/brief" --kind claude
check 2 'terminal finished' env MODE=finished "$scripts/start-worker.sh" worker-a "$tmp/wt-a" "$tmp/brief"
check 2 'not confirmed' env MODE=start-never "$scripts/start-worker.sh" worker-a "$tmp/wt-a" "$tmp/brief"
[[ $(tail -n 1 "$tmp/sleeps") == 2 ]]
: > "$tmp/calls"
check 1 'name_taken' env MODE=run-fail "$scripts/start-worker.sh" worker-a "$tmp/wt-a" "$tmp/brief"
: > "$tmp/calls"
check 1 'invalid agent name' "$scripts/start-worker.sh" Worker_A "$tmp/wt-a" "$tmp/brief"
check 1 'no worktree' "$scripts/start-worker.sh" worker-a "$tmp/missing" "$tmp/brief"
check 1 'unreadable brief' "$scripts/start-worker.sh" worker-a "$tmp/wt-a" "$tmp/missing"
check 1 'usage' "$scripts/start-worker.sh" worker-a "$tmp/wt-a"
[[ ! -s $tmp/calls ]]

# Reviewer startup uses hc ls's observed string status, not hc get's object.
ln -s "$tmp/wt-a" "$tmp/wt-alias"
printf '{"terminals":[{"address":"t1","name":"worker-a","cwd":"%s","state":"live","status":"working"}]}\n' "$tmp/wt-alias" > "$tmp/terminals.json"
: > "$tmp/calls"
check 3 'working in worktree' env MODE=settled "$scripts/start-worker.sh" task-review "$tmp/wt-a" "$tmp/brief"
[[ ! -s $tmp/calls ]]
for terminal in 'live idle worker-a' 'finished working worker-a' 'live working other-review'; do
	read -r state status name <<< "$terminal"
	printf '{"terminals":[{"address":"t1","name":"%s","cwd":"%s","state":"%s","status":"%s"}]}\n' "$name" "$tmp/wt-a" "$state" "$status" > "$tmp/terminals.json"
	check 0 'turn 1' env MODE=settled "$scripts/start-worker.sh" task-review "$tmp/wt-a" "$tmp/brief"
done
printf '{"terminals":[{"address":"t1","cwd":"%s","state":"live","status":"working"}]}\n' "$tmp/wt-a" > "$tmp/terminals.json"
check 3 'working in worktree' env MODE=settled "$scripts/start-worker.sh" task-review "$tmp/wt-a" "$tmp/brief"
printf '{"terminals":[{"address":"t1","name":"worker-a","cwd":"%s","state":"live","status":"working"}]}\n' "$tmp" > "$tmp/terminals.json"
check 0 'turn 1' env MODE=settled "$scripts/start-worker.sh" task-review "$tmp/wt-a" "$tmp/brief"
printf '{"terminals":[]}\n' > "$tmp/terminals.json"
: > "$tmp/calls"

# send-followup.sh: hc send to a live worker; revive a resumable finished one.
check 0 'sent' env MODE=settled "$scripts/send-followup.sh" worker-a "$tmp/wt-a" "$tmp/brief"
[[ $(cat "$tmp/calls") == "send worker-a $(cat "$tmp/brief")" ]]
: > "$tmp/calls"
check 2 'blocked' env MODE=settled AGENT_STATUS=blocked "$scripts/send-followup.sh" worker-a "$tmp/wt-a" "$tmp/brief"
[[ ! -s $tmp/calls ]]
rm -f "$tmp/removed"
check 0 'working' env MODE=hibernated AGENT_STATUS=working RESUME='env AGENT_BROWSER_NAMESPACE=worker-a pi --session s-9' "$scripts/send-followup.sh" worker-a "$tmp/wt-a" "$tmp/brief"
[[ $(head -n 1 "$tmp/calls") == "rm worker-a" ]]
mapfile -d '' -t argv < "$tmp/argv"
[[ ${argv[*]} == *"AGENT_BROWSER_NAMESPACE=worker-a pi --session s-9 $pi_prompt" && ${argv[-1]} == "$pi_prompt" ]]
: > "$tmp/calls"
rm -f "$tmp/removed"
check 0 'working' env MODE=hibernated AGENT_STATUS=working RESUME='claude --resume u-9' "$scripts/send-followup.sh" worker-a "$tmp/wt-a" "$tmp/brief"
mapfile -d '' -t argv < "$tmp/argv"
[[ ${argv[*]} == *"AGENT_BROWSER_NAMESPACE=worker-a claude --resume u-9 $prompt" && ${argv[-1]} == "$prompt" ]]
: > "$tmp/calls"
check 2 'without a resumable session' env MODE=finished "$scripts/send-followup.sh" worker-a "$tmp/wt-a" "$tmp/brief"
[[ ! -s $tmp/calls ]]
check 1 'unreadable brief' "$scripts/send-followup.sh" worker-a "$tmp/wt-a" "$tmp/missing"
check 1 'usage' "$scripts/send-followup.sh" worker-a "$tmp/wt-a"

# A later reviewer round cannot bypass the base gate, even on resume.
: > "$tmp/calls"
check 3 'requires --last-reviewed' env MODE=settled "$scripts/send-followup.sh" task-review "$tmp/wt-a" "$tmp/brief"
check 3 'requires --last-reviewed' env MODE=finished "$scripts/send-followup.sh" task-review "$tmp/wt-a" "$tmp/brief"
[[ ! -s $tmp/calls ]]

# orchestrate-init.sh: requires an hc terminal; log keyed by terminal id.
check 1 'not inside' env -u HC_TERMINAL_ID -u XDG_STATE_HOME "$scripts/orchestrate-init.sh" api
check 0 "log=$HOME/.local/state/orchestrate-using-herdr-app/t3.tsv" env -u XDG_STATE_HOME HC_TERMINAL_ID=t3 "$scripts/orchestrate-init.sh" api
check 1 'usage' env -u XDG_STATE_HOME HC_TERMINAL_ID=t3 "$scripts/orchestrate-init.sh"

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
check 3 'not a commit' env MODE=settled "$scripts/send-followup.sh" task-review "$tmp/work" "$tmp/brief" --last-reviewed missing
[[ ! -s $tmp/calls ]]
review_body=$'Review fixes\nReport by ending your turn; never `hc send` to the orchestrator.\nulw'
printf '%s' "$review_body" > "$tmp/review-brief"
check 0 'sent' env MODE=settled "$scripts/send-followup.sh" task-review "$tmp/work" "$tmp/review-brief" --last-reviewed "$main"
[[ $(cat "$tmp/calls") == *"$main..HEAD"* ]]
[[ $(cat "$tmp/calls") == *"$review_body" ]] || { echo 'FAIL: live reviewer prompt must preserve the reporting footer and final ulw'; exit 1; }
# Same reviewer name and session survive finished-terminal revival.
rm -f "$tmp/removed"
check 0 'working' env MODE=hibernated AGENT_STATUS=working RESUME='pi --session review-9' "$scripts/send-followup.sh" task-review "$tmp/work" "$tmp/review-brief" --last-reviewed "$head"
mapfile -d '' -t argv < "$tmp/argv"
[[ ${argv[*]} == *'--name task-review'* && ${argv[*]} == *'pi --session review-9'* ]]
[[ $(cat "$tmp/review-brief") == *"$head..HEAD"* ]]
[[ $(cat "$tmp/review-brief") == *"$review_body" && ${argv[-1]} == *' ulw' ]] || { echo 'FAIL: resumed reviewer brief and prompt must retain final ulw'; exit 1; }
check 0 $'11 head-11 FAIL: deploy, unit\n22 head-22 FAIL: deploy, unit' env MODE=pending "$scripts/watch-ci.sh" "$tmp/work" 11 22
[[ $(tail -n 1 "$tmp/sleeps") == 90 ]]
check 2 'PR 22 CONFLICTING' env MODE=conflict "$scripts/watch-ci.sh" "$tmp/work" 11 22
check 1 'authentication failed' env MODE=gh-error "$scripts/watch-ci.sh" "$tmp/work" 11
check 5 '' env MODE=gh-malformed "$scripts/watch-ci.sh" "$tmp/work" 11

# Guard failures must happen before the passed command executes.
check 1 'not on branch' "$scripts/push-pinned.sh" "$tmp/work" other "$main" -- touch "$tmp/built"
check 3 'expected wrong' "$scripts/push-pinned.sh" "$tmp/work" topic wrong -- touch "$tmp/built"
git -C "$tmp/work" switch -q --orphan unrelated
git -C "$tmp/work" commit -qm unrelated --allow-empty
: > "$tmp/calls"
check 3 'not an ancestor' env MODE=settled "$scripts/send-followup.sh" task-review "$tmp/work" "$tmp/review-brief" --last-reviewed "$main"
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

# reap-worker.sh: only the worker's namespace, Compose projects, and processes.
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
cat > "$tmp/bin/ss" <<'MOCK'
#!/usr/bin/env bash
[[ -s $FIXTURE/listeners ]] || exit 0
printf 'LISTEN 0 0 127.0.0.1:3456 *:* users:(("node",pid=%s,fd=3))\n' $(cat "$FIXTURE/listeners")
MOCK
chmod +x "$tmp/bin/"*
mkdir -p "$tmp/wt/apps/web" "$tmp/wt-other"
spawn() { (cd "$1" && exec tail -f /dev/null >/dev/null 2>&1) & echo $!; }
dev=$(spawn "$tmp/wt/apps/web"); agent=$(spawn "$tmp/wt"); other=$(spawn "$tmp/wt-other")
echo "$dev $other" > "$tmp/listeners"
: > "$tmp/labels"
check 0 'processes under' "$scripts/reap-worker.sh" "$tmp/wt" worker-a --keep-agent
! kill -0 "$dev" 2>/dev/null || [[ $(ps -o stat= -p "$dev") == Z* ]]
kill -0 "$agent" && kill -0 "$other"
[[ $(cat "$tmp/browser") == 'worker-a close --all' ]]
[[ $(cat "$tmp/docker") == $'rm -f -v c-mine\nvolume rm -f volume-mine\nnetwork rm network-mine' ]]
[[ $(cat "$tmp/labels") == 'label worker-a hibernate=ok' ]] || { echo 'FAIL: settled worker must become hibernatable after reaping'; exit 1; }
: > "$tmp/listeners"
check 0 '0 stopped' "$scripts/reap-worker.sh" "$tmp/wt" worker-a --keep-agent
[[ $(cat "$tmp/labels") == $'label worker-a hibernate=ok\nlabel worker-a hibernate=ok' ]]
: > "$tmp/labels"
check 0 '1 stopped' "$scripts/reap-worker.sh" "$tmp/wt" worker-a
[[ ! -s $tmp/labels ]]
! kill -0 "$agent" 2>/dev/null || [[ $(ps -o stat= -p "$agent") == Z* ]]
kill -0 "$other"
kill "$other"; wait "$dev" "$agent" "$other" 2>/dev/null || true
check 1 'usage' "$scripts/reap-worker.sh" "$tmp/wt"
check 1 'refusing' "$scripts/reap-worker.sh" / worker-a
printf '%s CLI checks plus safety assertions passed\n' "$checks"
