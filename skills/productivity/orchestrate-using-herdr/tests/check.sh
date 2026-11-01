#!/usr/bin/env bash
# Run isolated CLI fixtures; never contacts a live remote or Herdr session.
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
cat > "$tmp/bin/herdr" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [[ $1 == pane || $2 == start ]]; then
	echo "$*" >> "$FIXTURE/calls"
fi
if [[ $1 == pane ]]; then
	[[ $MODE != pane-fail ]] || { echo '{"error":{"code":"pane_not_found"}}' >&2; exit 1; }
	exit
fi
if [[ $2 == start ]]; then
	case "$MODE" in
		start-busy)
			n=$(( $(cat "$FIXTURE/starts" 2>/dev/null || echo 0) + 1 ))
			echo "$n" > "$FIXTURE/starts"
			[[ $n -ge 3 ]] || { echo '{"error":{"code":"agent_pane_busy"}}' >&2; exit 1; } ;;
		start-busy-forever) echo '{"error":{"code":"agent_pane_busy"}}' >&2; exit 1 ;;
		start-notready) echo '{"error":{"code":"agent_not_ready"}}' >&2; exit 1 ;;
		start-text) echo 'herdr: daemon unreachable' >&2; exit 1 ;;
	esac
	echo '{"result":{"agent":{"agent_status":"idle"}}}'
	exit
fi
if [[ $2 == wait ]]; then
	[[ $MODE != wait-error && $MODE != gone ]]
	exit
fi
case "$MODE" in
	gone) echo '{"error":{"code":"agent_not_found"}}'; exit 1 ;;
	auth) echo '{"error":{"code":"unauthorized"}}'; exit 1 ;;
	malformed) echo broken ;;
	resume)
		if [[ ! -e $FIXTURE/resumed ]]; then
			touch "$FIXTURE/resumed"
			echo '{"result":{"agent":{"agent_status":"working"}}}'
		else
			echo '{"result":{"agent":{"agent_status":"done"}}}'
		fi ;;
	*) printf '{"result":{"agent":{"agent_status":"%s"}}}\n' "${AGENT_STATUS:-idle}" ;;
esac
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
for status in idle 'done' blocked; do
	check 0 "settled: $status" env MODE=settled AGENT_STATUS="$status" "$scripts/watch-agent.sh" worker
done
check 0 'settled: done' env MODE=resume "$scripts/watch-agent.sh" worker
[[ $(cat "$tmp/sleeps") == $'30\n30\n30\n30\n30' ]]
check 0 'gone' env MODE=gone "$scripts/watch-agent.sh" worker
check 1 'unauthorized' env MODE=auth "$scripts/watch-agent.sh" worker
check 5 '' env MODE=malformed "$scripts/watch-agent.sh" worker
check 1 'wait failed' env MODE=wait-error "$scripts/watch-agent.sh" worker

# start-worker.sh: namespace export first, retry only on agent_pane_busy.
check 0 'idle' env MODE=start-busy "$scripts/start-worker.sh" worker-a wF1:p1
[[ $(cat "$tmp/starts") == 3 ]]
[[ $(cat "$tmp/calls") == $'pane run wF1:p1 export AGENT_BROWSER_NAMESPACE=worker-a\nagent start worker-a --kind pi --pane wF1:p1\nagent start worker-a --kind pi --pane wF1:p1\nagent start worker-a --kind pi --pane wF1:p1' ]]
[[ $(tail -n 2 "$tmp/sleeps" | tr '\n' ' ') == '4 4 ' ]]
: > "$tmp/calls"
check 2 'still busy' env MODE=start-busy-forever "$scripts/start-worker.sh" worker-a wF1:p1
[[ $(grep -c 'agent start' "$tmp/calls") == 6 ]]
[[ $(tail -n 5 "$tmp/sleeps" | tr '\n' ' ') == '4 4 4 4 4 ' ]]
: > "$tmp/calls"
check 1 'agent_not_ready' env MODE=start-notready "$scripts/start-worker.sh" worker-a wF1:p1 --kind claude
[[ $(tail -n 1 "$tmp/calls") == 'agent start worker-a --kind claude --pane wF1:p1' ]]
: > "$tmp/calls"
check 1 'daemon unreachable' env MODE=start-text "$scripts/start-worker.sh" worker-a wF1:p1
[[ $(grep -c 'agent start' "$tmp/calls") == 1 ]]
: > "$tmp/calls"
check 1 'pane_not_found' env MODE=pane-fail "$scripts/start-worker.sh" worker-a wF1:p1
! grep -q 'agent start' "$tmp/calls"
check 1 'invalid agent name' "$scripts/start-worker.sh" Worker_A wF1:p1
check 1 'usage' "$scripts/start-worker.sh" worker-a

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
