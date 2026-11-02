#!/usr/bin/env bash
# Run isolated CLI fixtures; never contacts a live remote or Orca session.
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
cat > "$tmp/bin/orca" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$FIXTURE/calls"
case "$1 $2" in
	'terminal show') printf '{"result":{"terminal":{"title":"%s"}}}\n' "${TITLE:-}" ;;
	'terminal set-pane-title') ;;
	'worktree create')
		[[ ${MODE:-} != create-fail ]] || { echo '{"error":{"code":"runtime_error"}}' >&2; exit 1; }
		echo '{"result":{"worktree":{"id":"repo1::/wt/b","path":"/wt/b"},"launch":{"outcome":{"handle":"term_1"}}}}' ;;
	'orchestration worker-start')
		[[ ${MODE:-} != start-fail ]] || { echo '{"error":{"failedStage":"launch"}}'; exit 1; }
		echo '{"result":{"dispatchId":"d1","taskId":"t1"}}' ;;
	*) exit 1 ;;
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
[[ ${MODE:-} != gh-error ]] || { echo 'authentication failed' >&2; exit 1; }
[[ ${MODE:-} != gh-malformed ]] || { echo broken; exit; }
mergeable=MERGEABLE
status=COMPLETED
[[ ${MODE:-} != conflict || $3 != 22 ]] || mergeable=CONFLICTING
if [[ $MODE == pending && $3 == 11 && ! -e $FIXTURE/polled ]]; then
	status=WAITING
	touch "$FIXTURE/polled"
fi
printf '{"mergeable":"%s","headRefOid":"head-%s","statusCheckRollup":[{"status":"%s","conclusion":"FAILURE","name":"unit"},{"state":"ERROR","context":"deploy"}]}\n' "$mergeable" "$3" "$status"
MOCK
chmod +x "$tmp/bin/"*

# orchestrate-init.sh: needs Orca, labels the terminal once, logs outside the repo.
export ORCA_TERMINAL_HANDLE=term_orch
check 0 'orchestrate-using-orca/term_orch.tsv' env MODE=ok "$scripts/orchestrate-init.sh" api
[[ $(grep -c 'set-pane-title --terminal term_orch --title \[o\] api' "$tmp/calls") == 1 ]]
: > "$tmp/calls"
check 0 'log=' env TITLE='api work' "$scripts/orchestrate-init.sh" api
grep -q -- '--title \[o\] api work' "$tmp/calls"
: > "$tmp/calls"
check 0 'log=' env TITLE='[o] kept' "$scripts/orchestrate-init.sh" api
! grep -q set-pane-title "$tmp/calls"
check 1 'not inside Orca' env -u ORCA_TERMINAL_HANDLE "$scripts/orchestrate-init.sh" api
check 1 'usage' "$scripts/orchestrate-init.sh"

# start-worker.sh: handoff is one create with the agent; --run creates the
# worktree bare, then starts a supervised worker, and never retries.
brief="$tmp/brief.md"
printf 'do the thing ulw\n' > "$brief"
: > "$tmp/calls"
check 0 'term_1' "$scripts/start-worker.sh" worker-a feat/a main "$brief" --repo id:r1
[[ $(wc -l < "$tmp/calls") == 1 ]]
grep -q -- '--name feat/a --branch feat/a --base-branch main --no-parent --comment worker-a --repo id:r1 --agent pi --prompt do the thing ulw' "$tmp/calls"
! grep -q -- '--path' "$tmp/calls"
: > "$tmp/calls"
check 0 'd1' "$scripts/start-worker.sh" worker-a feat/a main "$brief" --run --kind claude
[[ $(sed -n 1p "$tmp/calls") != *--agent* && $(sed -n 1p "$tmp/calls") != *--prompt* ]]
[[ $(sed -n 2p "$tmp/calls") == 'orchestration worker-start --worktree id:repo1::/wt/b --agent claude --spec do the thing ulw --json' ]]
check 0 'worktree id=repo1::/wt/b path=/wt/b' "$scripts/start-worker.sh" worker-a feat/a main "$brief" --run
: > "$tmp/calls"
check 1 'failedStage' env MODE=start-fail "$scripts/start-worker.sh" worker-a feat/a main "$brief" --run
[[ $(grep -c 'worker-start' "$tmp/calls") == 1 ]]
: > "$tmp/calls"
check 1 'runtime_error' env MODE=create-fail "$scripts/start-worker.sh" worker-a feat/a main "$brief" --run
! grep -q 'worker-start' "$tmp/calls"
check 1 'invalid agent name' "$scripts/start-worker.sh" Worker_A feat/a main "$brief"
check 1 'unreadable brief' "$scripts/start-worker.sh" worker-a feat/a main "$tmp/missing"
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
# Fake only the TCP-listener query; cwd lookups use the real lsof.
cat > "$tmp/bin/lsof" <<'MOCK'
#!/usr/bin/env bash
case " $* " in
	*' -iTCP '*) printf '%s\n' $(cat "$FIXTURE/listeners") ;;
	*) PATH=${PATH#"$FIXTURE/bin:"} exec lsof "$@" ;;
esac
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
