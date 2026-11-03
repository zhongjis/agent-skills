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
	run)
		printf '%s\n' "$*" >> "$FIXTURE/calls"
		[[ $MODE != run-fail ]] || { echo '{"error":{"kind":"name_taken"}}' >&2; exit 1; }
		echo '{"address":"t9","state":"live","turn":0}'
		exit ;;
	wait)
		[[ $MODE != gone ]] || { echo '{"error":{"kind":"not_found"}}' >&2; exit 3; }
		[[ $MODE != wait-error ]] || { echo '{"error":{"kind":"io"}}' >&2; exit 1; }
		echo '{"reason":"status"}'
		exit ;;
esac
n=$(( $(cat "$FIXTURE/gets" 2>/dev/null || echo 0) + 1 ))
echo "$n" > "$FIXTURE/gets"
state=live status="${AGENT_STATUS:-idle}" turn=1
case "$MODE" in
	gone) echo '{"error":{"kind":"not_found"}}'; exit 3 ;;
	auth) echo '{"error":{"kind":"unauthorized"}}'; exit 1 ;;
	malformed) echo broken; exit ;;
	finished) state=finished ;;
	resume) [[ $n -ge 2 ]] || status=working ;;
	start-turn) [[ $n -ge 3 ]] || turn=0 ;;
	start-never) turn=0 ;;
esac
printf '{"state":"%s","status":{"state":"%s"},"turn":%s}\n' "$state" "$status" "$turn"
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
for status in idle 'done' blocked error; do
	rm -f "$tmp/gets"
	check 0 "settled: $status" env MODE=settled AGENT_STATUS="$status" "$scripts/watch-agent.sh" worker
done
rm -f "$tmp/gets"
check 0 'settled: done' env MODE=resume AGENT_STATUS=done "$scripts/watch-agent.sh" worker
[[ $(cat "$tmp/sleeps") == $'30\n30\n30\n30\n30\n30' ]]
check 0 'gone' env MODE=gone "$scripts/watch-agent.sh" worker
check 0 'terminal finished' env MODE=finished "$scripts/watch-agent.sh" worker
check 1 'unauthorized' env MODE=auth "$scripts/watch-agent.sh" worker
check 5 '' env MODE=malformed "$scripts/watch-agent.sh" worker
check 1 'wait failed' env MODE=wait-error "$scripts/watch-agent.sh" worker

# start-worker.sh: one hc launch with namespace and brief, confirm by turn.
mkdir -p "$tmp/wt-a"
# shellcheck disable=SC2016 # literal brief text
printf 'Fix $skill:x ; $(false)\nulw' > "$tmp/brief"
rm -f "$tmp/gets"
check 0 'turn 1' env MODE=start-turn "$scripts/start-worker.sh" worker-a "$tmp/wt-a" "$tmp/brief"
[[ $(cat "$tmp/gets") == 3 ]]
[[ $(head -n 1 "$tmp/calls") == "run --bg --json --name worker-a --cwd $tmp/wt-a --outlive-parent env AGENT_BROWSER_NAMESPACE=worker-a pi Fix \$skill:x ; \$(false)" ]]
: > "$tmp/calls"
check 0 '' env MODE=settled "$scripts/start-worker.sh" worker-a "$tmp/wt-a" "$tmp/brief" --kind codex
[[ $(head -n 1 "$tmp/calls") == *'AGENT_BROWSER_NAMESPACE=worker-a codex --no-daemon Fix'* ]]
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
printf 'LISTEN 0 0 127.0.0.1:3456 *:* users:(("node",pid=%s,fd=3))\n' $(cat "$FIXTURE/listeners")
MOCK
chmod +x "$tmp/bin/"*
mkdir -p "$tmp/wt/apps/web" "$tmp/wt-other"
spawn() { (cd "$1" && exec tail -f /dev/null >/dev/null 2>&1) & echo $!; }
dev=$(spawn "$tmp/wt/apps/web"); agent=$(spawn "$tmp/wt"); other=$(spawn "$tmp/wt-other")
echo "$dev $other" > "$tmp/listeners"
check 0 'processes under' "$scripts/reap-worker.sh" "$tmp/wt" worker-a --keep-agent
! kill -0 "$dev" 2>/dev/null || [[ $(ps -o stat= -p "$dev") == Z* ]]
kill -0 "$agent" && kill -0 "$other"
[[ $(cat "$tmp/browser") == 'worker-a close --all' ]]
[[ $(cat "$tmp/docker") == $'rm -f -v c-mine\nvolume rm -f volume-mine\nnetwork rm network-mine' ]]
check 0 '1 stopped' "$scripts/reap-worker.sh" "$tmp/wt" worker-a
! kill -0 "$agent" 2>/dev/null || [[ $(ps -o stat= -p "$agent") == Z* ]]
kill -0 "$other"
kill "$other"; wait "$dev" "$agent" "$other" 2>/dev/null || true
check 1 'usage' "$scripts/reap-worker.sh" "$tmp/wt"
check 1 'refusing' "$scripts/reap-worker.sh" / worker-a
printf '%s CLI checks plus safety assertions passed\n' "$checks"
