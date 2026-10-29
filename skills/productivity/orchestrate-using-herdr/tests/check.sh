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
printf '%s CLI checks plus safety assertions passed\n' "$checks"
