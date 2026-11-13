#!/usr/bin/env bash
# Run isolated CLI fixtures; never contacts a live remote or herdr-core session.
set -euo pipefail
scripts=$(realpath "$(dirname -- "${BASH_SOURCE[0]}")/../scripts")
tmp=$(realpath "$(mktemp -d)")
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
[[ ${argv[*]} == "run --bg --json --no-notify --name w-worker-a --cwd $tmp/wt-a --outlive-parent env AGENT_BROWSER_NAMESPACE=w-worker-a pi $pi_prompt" ]] || { echo 'FAIL: short Pi argv must reference absolute brief and preserve skill/ulw triggers'; exit 1; }
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

# ORCH_LOG: dispatch and follow-up append rows only on success and only when set.
orch_log="$tmp/orch.tsv"
rm -f "$orch_log"
check 0 'working' env MODE=settled AGENT_STATUS=working "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$tmp/brief"
[[ ! -e $orch_log ]]
check 0 'working' env ORCH_LOG="$orch_log" MODE=settled AGENT_STATUS=working "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$tmp/brief" --kind claude
[[ $(tail -n 1 "$orch_log") == *$'\tw-worker-a\tdispatched\tterminal=t9 worktree='"$tmp/wt-a"' brief='"$tmp/brief with spaces"$' kind=claude\tworking' ]]
check 2 'blocked' env ORCH_LOG="$orch_log" MODE=settled AGENT_STATUS=blocked "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$tmp/brief"
check 1 'name_taken' env ORCH_LOG="$orch_log" MODE=run-fail "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$tmp/brief"
[[ $(wc -l < "$orch_log") -eq 2 ]]
# A logging failure never fails the dispatch.
check 0 'working' env ORCH_LOG="$tmp/wt-a" MODE=settled AGENT_STATUS=working "$scripts/start-worker.sh" w-worker-a "$tmp/wt-a" "$tmp/brief"
: > "$tmp/calls"
check 0 'sent' env ORCH_LOG="$orch_log" MODE=settled "$scripts/send-followup.sh" w-worker-a "$tmp/wt-a" "$tmp/brief"
[[ $(tail -n 1 "$orch_log") == *$'\tw-worker-a\tre-instructed\tbrief='"$tmp/brief"$'\tworking' ]]
rm -f "$tmp/removed"
check 0 'working' env ORCH_LOG="$orch_log" MODE=hibernated AGENT_STATUS=working RESUME='pi --session s-8' "$scripts/send-followup.sh" w-worker-a "$tmp/wt-a" "$tmp/brief"
[[ $(tail -n 1 "$orch_log") == *$'\tw-worker-a\tre-instructed\t'* && $(grep -c dispatched "$orch_log") -eq 1 ]]
check 2 'blocked' env ORCH_LOG="$orch_log" MODE=settled AGENT_STATUS=blocked "$scripts/send-followup.sh" w-worker-a "$tmp/wt-a" "$tmp/brief"
[[ $(wc -l < "$orch_log") -eq 4 ]]
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
# orchestrate-init.sh: requires an hc terminal; log keyed by terminal id.
check 1 'not inside' env -u HC_TERMINAL_ID -u XDG_STATE_HOME "$scripts/orchestrate-init.sh" api
check 0 "log=$HOME/.local/state/orchestrate-using-herdr-app/t3.tsv" env -u XDG_STATE_HOME HC_TERMINAL_ID=t3 "$scripts/orchestrate-init.sh" api
check 0 "export ORCH_LOG=$HOME/.local/state/orchestrate-using-herdr-app/t3.tsv" env -u XDG_STATE_HOME HC_TERMINAL_ID=t3 "$scripts/orchestrate-init.sh" api
check 1 'usage' env -u XDG_STATE_HOME HC_TERMINAL_ID=t3 "$scripts/orchestrate-init.sh"
# The invocation's flags land in the log; the orchestrator's own tab is marked once.
rm -f "$tmp/herdr"
check 0 'log=' env -u XDG_STATE_HOME HC_TERMINAL_ID=t3 "$scripts/orchestrate-init.sh" api --mode '--auto --track'
[[ $(tail -n 1 "$HOME/.local/state/orchestrate-using-herdr-app/t3.tsv") == *$'\torchestrator\tmode\tflags=--auto --track slug=api\tok' ]] || { echo 'FAIL: init must log the invocation flags'; exit 1; }
[[ $(cat "$tmp/herdr") == 'do tab.rename --id tb1 --name [o] api' ]] || { echo 'FAIL: init must mark its own tab [o] <title>'; exit 1; }
rm -f "$tmp/herdr"
check 0 'log=' env -u XDG_STATE_HOME HC_TERMINAL_ID=t3 "$scripts/orchestrate-init.sh" retro-skills_ui-audit-fix
[[ $(cat "$tmp/herdr") == 'do tab.rename --id tb1 --name [o] retro skills ui audit' ]] || { echo 'FAIL: init tab title must split hyphens into at most four words'; exit 1; }
rm -f "$tmp/herdr"
check 0 'log=' env -u XDG_STATE_HOME HC_TERMINAL_ID=t3 TAB_NAME='[o] api' "$scripts/orchestrate-init.sh" api
[[ ! -e "$tmp/herdr" ]] || { echo 'FAIL: init must leave an already marked tab'; exit 1; }
[[ $(tail -n 1 "$HOME/.local/state/orchestrate-using-herdr-app/t3.tsv") == *$'\tflags=none slug=api\tok' ]] || { echo 'FAIL: init without --mode must log flags=none'; exit 1; }
check 1 'usage' env -u XDG_STATE_HOME HC_TERMINAL_ID=t3 "$scripts/orchestrate-init.sh" api --mode

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
rm "$tmp/bin/uname" "$tmp/bin/ps" "$tmp/bin/lsof"

# status.sh: latest stem/worker/reviewer row wins; live uses the worker dispatch.
cat > "$tmp/status.tsv" <<'TSV'
ts	task	event	evidence	result
2026-01-01T00:00:00Z	orchestrator	mode	flags=--auto	ok
2026-01-01T00:01:00Z	w-alpha	dispatched	terminal=t9 brief=/brief	working
2026-01-01T00:02:00Z	w-beta	dispatched	terminal=t10	working
2026-01-01T00:03:00Z	all	note	one	ok
2026-01-01T00:04:00Z	alpha	settled	PR #7 | green	succeeded
2026-01-01T00:05:00Z	beta	reaped	terminal=reviewer	ok
2026-01-01T00:06:00Z	all	note	two	ok
2026-01-01T00:07:00Z	w-gamma	dispatched	terminal=t11	working
2026-01-01T00:08:00Z	delta	queued	needs=alpha	pending
TSV
check 0 '| alpha | w-alpha (t9) | settled | succeeded | PR #7 &#124; green | 2026-01-01T00:04:00Z |' "$scripts/status.sh" "$tmp/status.tsv"
out=$("$scripts/status.sh" "$tmp/status.tsv")
[[ $(grep -c '^| alpha |' <<<"$out") == 1 && $out != *orchestrator* && $out != *'| all |'* && $out == *'2 notes (all).'* ]]
check 0 '| Since | Live |' env MODE=status-live "$scripts/status.sh" "$tmp/status.tsv" --live
out=$(MODE=status-live "$scripts/status.sh" "$tmp/status.tsv" --live)
[[ $out == *'00:04:00Z | working |'* && $out == *'00:05:00Z | finished |'* && $out == *'00:07:00Z | gone |'* && $out == *'00:08:00Z |  |'* ]]
[[ $(sort -u "$tmp/live-calls") == $'get t10 --json\nget t11 --json\nget t9 --json' ]]
check 1 'unauthorized' env MODE=auth "$scripts/status.sh" "$tmp/status.tsv" --live
check 1 'usage' "$scripts/status.sh" "$tmp/status.tsv" --unknown
check 1 '' "$scripts/status.sh" "$tmp/missing.tsv"

# Mixed names collapse to one task; the newest reviewer row cannot replace its worker.
cat > "$tmp/mixed.tsv" <<'TSV'
ts	task	event	evidence	result
2026-01-01T00:00:00Z	w-x	dispatched	terminal=old	working
2026-01-01T00:01:00Z	w-x	dispatched	terminal=t9	working
2026-01-01T00:02:00Z	x	settled	PR #8	succeeded
2026-01-01T00:03:00Z	r-x	dispatched	terminal=t11	working
2026-01-01T00:04:00Z	r-x	reviewed	findings=/review	approved
TSV
check 0 '| x | w-x (t9) | reviewed | approved | findings=/review | 2026-01-01T00:04:00Z |' "$scripts/status.sh" "$tmp/mixed.tsv"
out=$("$scripts/status.sh" "$tmp/mixed.tsv")
[[ $(grep -c '^| ' <<<"$out") == 3 && $(grep -c '^| x |' <<<"$out") == 1 ]]
check 0 '| 2026-01-01T00:04:00Z | working |' env MODE=status-live "$scripts/status.sh" "$tmp/mixed.tsv" --live

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
printf '%s CLI checks plus safety assertions passed\n' "$checks"
