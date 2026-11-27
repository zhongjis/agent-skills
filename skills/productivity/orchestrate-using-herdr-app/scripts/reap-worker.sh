#!/usr/bin/env bash
# Usage: reap-worker.sh [--bead <id>] <worktree> <agent> [--keep-agent | --full <branch> [--keep-remote] | --ported <checkout>]
# Stop what a worker started in <worktree>: its agent-browser namespace,
# Compose projects whose working_dir is inside <worktree>, and its processes.
# --keep-agent stops only listening processes (dev servers) and keeps the
# agent, its LSP and MCP children, and the worktree for follow-ups, then
# labels the settled worker hibernate=ok after cleanup, except a Codex worker, which
# cannot be revived once hibernated.
# --full <branch> is full cleanup after a merged, released task: it also removes the
# w-/r- terminals for the agent's stem, the git worktree, and the local and remote
# <branch>, then confirms each is gone. --keep-remote, for non-merge work, keeps the
# remote branch as evidence and refuses a dirty worktree or a head missing from origin.
# Without --keep-remote, --full needs --bead and refuses (exit 1, before removing
# anything) unless the bead binds to every target: metadata worktree, branch and repo (each
# when set; worktree or branch required) match, the worktree is on that branch, <agent> is the
# bead's assignee or its newest orchestrator dispatch's agent, and every live w-/r- terminal
# of the stem is inside the worktree. Then either the bead is still closed and its newest
# orchestrator `settled` is result=abandoned with no later dispatched/re-instructed/handed-off/
# adopted/report event, or its merged_sha is a 40-hex ancestor of the base ref, the worktree
# is clean, and the local tip is the head of the newest orchestrator `ready` event before the
# `merged` event (else an ancestor of the base ref) and the remote branch, if any, is at the
# local tip. The remote branch is deleted first, leased on that verified tip.
# --ported <checkout> is the same full cleanup for non-merge work whose diff was ported to
# another checkout (the local branch is the worktree's current branch; a remote branch is never
# deleted). It needs --bead and the same binding as --full, the bead closed with its newest
# orchestrator `settled` result=succeeded, and the worktree's uncommitted diff (`git diff HEAD
# --binary` plus untracked files, nonempty) must reverse-apply cleanly on <checkout>
# (`git apply -R --check`), proving the port is there.
# --bead records `event=reaped stopped=<what was removed>` on that bead.
# Matches cwd via /proc on Linux and lsof on macOS.
set -euo pipefail

usage() {
	printf 'usage: reap-worker.sh [--bead <id>] <worktree> <agent> [--keep-agent | --full <branch> [--keep-remote] | --ported <checkout>]\n' >&2
	exit 1
}
bead=""
if [ "${1:-}" = --bead ]; then
	[ "$#" -ge 2 ] && [ -n "$2" ] || usage
	bead="$2"
	shift 2
	[ -n "${HC_TERMINAL_ID:-}" ] || { printf 'reap-worker.sh --bead needs HC_TERMINAL_ID\n' >&2; exit 1; }
fi
stopped=()
record() {
	[ -n "$bead" ] || return 0
	local IFS=,
	"$(dirname -- "${BASH_SOURCE[0]}")/event.sh" "$bead" reaped "stopped=${stopped[*]:-none}" >/dev/null || {
		printf 'reaped, but recording on %s failed\n' "$bead" >&2
		exit 1
	}
}
keep_agent="" branch="" keep_remote="" ported=""
case "$#" in
	2) ;;
	3) [ "$3" = --keep-agent ] || usage; keep_agent=--keep-agent ;;
	4)
		if [ "$3" = --full ] && [ -n "$4" ]; then branch="$4"
		elif [ "$3" = --ported ] && [ -n "$4" ]; then ported="$4"
		else usage; fi ;;
	5) [ "$3" = --full ] && [ -n "$4" ] && [ "$5" = --keep-remote ] || usage; branch="$4" keep_remote=1 ;;
	*) usage ;;
esac
root=$(realpath -m -- "$1")
agent="$2"
[ "$root" != / ] && [ "$root" != "$(realpath -m -- "$HOME")" ] || {
	printf 'refusing to reap %s\n' "$root" >&2
	exit 1
}

if [ -n "$ported" ]; then
	branch=$(git -C "$root" symbolic-ref -q --short HEAD) || { printf 'refusing: %s is on no branch\n' "$root" >&2; exit 1; }
	ported=$(realpath -m -- "$ported")
fi

if [ -n "$keep_remote" ]; then
	[ -z "$(git -C "$root" status --porcelain)" ] || {
		printf 'refusing: uncommitted work in %s\n' "$root" >&2
		exit 1
	}
	git -C "$root" fetch -q origin "$branch" && git -C "$root" merge-base --is-ancestor HEAD FETCH_HEAD || {
		printf 'refusing: %s head not on origin\n' "$branch" >&2
		exit 1
	}
fi

inside() { [ "$1" = "$root" ] || [[ "$1" == "$root"/* ]]; }

remote_deleted=""
if [ -n "$branch" ] && [ -z "$keep_remote" ]; then
	[ -n "$bead" ] || { printf 'refusing: %s needs --bead\n' "${ported:+--ported}${ported:---full without --keep-remote}" >&2; exit 1; }
	refuse() { printf 'refusing: %s\n' "$*" >&2; exit 1; }
	task=$(bd show "$bead" --json)
	comments=$(bd comments "$bead" --json)
	meta() { jq -r --arg k "$1" '.[0].metadata[$k] // "" | tostring' <<<"$task"; }
	# Quoted field values are stripped first so prose cannot pose as a field.
	line_def='def line: .text | split("\n")[0] | gsub(" [a-z][a-z0-9_-]*=\"(?:[^\"\\\\]|\\\\.)*\"(?= |$)"; "");'
	# Bind the bead to every target: what it recorded must be what is about to be deleted.
	meta_worktree=$(meta worktree) meta_branch=$(meta branch) meta_repo=$(meta repo)
	[ -n "$meta_worktree" ] || [ -n "$meta_branch" ] || refuse "$bead records no worktree or branch to bind $branch to"
	[ -z "$meta_worktree" ] || [ "$(realpath -m -- "$meta_worktree")" = "$root" ] || refuse "$bead worktree $meta_worktree is not $root"
	[ -z "$meta_branch" ] || [ "$meta_branch" = "$branch" ] || refuse "$bead branch $meta_branch is not $branch"
	common() { local d; d=$(git -C "$1" rev-parse --path-format=absolute --git-common-dir) || return 1; realpath -m -- "$d"; }
	root_repo=$(common "$root" 2>/dev/null) || refuse "$root is not a git worktree"
	[ -z "$meta_repo" ] || [ "$(common "$meta_repo" 2>/dev/null || true)" = "$root_repo" ] || refuse "$bead repo $meta_repo is not the repository of $root"
	[ "$(git -C "$root" symbolic-ref -q HEAD || true)" = "refs/heads/$branch" ] || refuse "$root is not on branch $branch"
	tip=$(git -C "$root" rev-parse --verify -q "refs/heads/$branch^{commit}") || refuse "no local branch $branch"
	# The agent whose browser and terminals are cleaned must be the bead's: its assignee or
	# the agent of its newest orchestrator dispatch, with every live terminal inside the worktree.
	assignee=$(jq -r '.[0].assignee // ""' <<<"$task")
	dispatched=$(jq -r "$line_def"'
		[.[] | select((.author // "") | startswith("o-")) | select(line | test("^event=dispatched( |$)")) | line | capture(" agent=(?<a>[^ ]+)")? | .a] | last // ""' <<<"$comments")
	[ "$agent" = "$assignee" ] || [ "$agent" = "$dispatched" ] || refuse "$agent is not the agent of $bead (assignee ${assignee:-none}, dispatched ${dispatched:-none})"
	for name in "$agent" "w-${agent#[wr]-}" "r-${agent#[wr]-}"; do
		info=$(hc get "$name" --json 2>/dev/null) || continue
		tcwd=$(jq -r '.cwd // ""' <<<"$info")
		{ [ -n "$tcwd" ] && inside "$(realpath -m -- "$tcwd")"; } || refuse "terminal $name is not inside $root"
	done
	merged=$(meta merged_sha)
	ref=$(meta base | cut -d@ -f1)
	ref=${ref#origin/}
	# Abandonment is the newest orchestrator settle, with no later activity on the bead, while
	# the bead is still closed: a plain reopen is current work again.
	abandoned=$(jq -r "$line_def"'
		to_entries as $e |
		[$e[] | select(.value | line | test("^event=settled( |$)")) | select((.value.author // "") | startswith("o-"))] | last as $s |
		if $s == null or ($s.value | line | test(" result=abandoned( |$)") | not) then false
		else [$e[] | select(.key > $s.key) | .value | select(line | test("^event=(dispatched|re-instructed|handed-off|adopted|report)( |$)"))] | length == 0 end' <<<"$comments")
	[ "$(jq -r '.[0].status // ""' <<<"$task")" = closed ] || abandoned=false
	if [ -n "$ported" ]; then
		# Non-merge work ported elsewhere: the bead settled succeeded, and the worktree's whole
		# uncommitted diff must be undoable on the other checkout, so nothing is lost.
		[ "$(jq -r '.[0].status // ""' <<<"$task")" = closed ] || refuse "$bead is not closed"
		succeeded=$(jq -r "$line_def"'
			[.[] | select((.author // "") | startswith("o-")) | select(line | test("^event=settled( |$)"))] | last // null |
			if . == null then false else (line | test(" result=succeeded( |$)")) end' <<<"$comments")
		[ "$succeeded" = true ] || refuse "$bead has no orchestrator settled result=succeeded as its newest settle"
		git -C "$ported" rev-parse --git-dir >/dev/null 2>&1 || refuse "$ported is not a git checkout"
		patch=$(mktemp) idx=$(mktemp -u)
		{ GIT_INDEX_FILE=$idx git -C "$root" read-tree HEAD &&
			GIT_INDEX_FILE=$idx git -C "$root" add -A &&
			GIT_INDEX_FILE=$idx git -C "$root" diff --cached HEAD --binary >"$patch"; } || { rm -f "$patch" "$idx"; refuse "cannot read the diff of $root"; }
		rm -f "$idx"
		[ -s "$patch" ] || { rm -f "$patch"; refuse "$root has no uncommitted diff to verify as ported"; }
		git -C "$ported" apply -R --check <"$patch" 2>/dev/null || { rm -f "$patch"; refuse "the diff of $root is not applied on $ported"; }
		rm -f "$patch"
	elif [ "$abandoned" != true ]; then
		{ [[ $merged =~ ^[0-9a-f]{40}$ ]] && [ -n "$ref" ] &&
			git -C "$root" fetch -q origin "$ref" && git -C "$root" merge-base --is-ancestor "$merged" FETCH_HEAD; } || {
			printf 'refusing: %s has no verified merge on %s\n' "$branch" "${ref:-its base ref}" >&2
			exit 1
		}
		[ -z "$(git -C "$root" status --porcelain)" ] || refuse "uncommitted or untracked changes in $root"
		[ "$(git -C "$root" rev-parse HEAD)" = "$tip" ] || refuse "$root is not at the tip of $branch"
		# The merged head is the head of the newest orchestrator ready event before the merged
		# event, not the mutable head_sha metadata; without one, the tip must be on the base ref.
		ready_head=$(jq -r --arg m "$merged" "$line_def"'
			to_entries as $e |
			[$e[] | select((.value.author // "") | startswith("o-")) | select(.value | line | test("^event=merged( |$)") and test(" merged_sha=" + $m + "( |$)"))] | last as $mg |
			if $mg == null then "" else
			[$e[] | select(.key < $mg.key) | select((.value.author // "") | startswith("o-")) | .value | select(line | test("^event=ready( |$)")) | line | capture(" head=(?<h>[0-9a-f]{7,40})( |$)")? | .h] | last // "" end' <<<"$comments")
		if [ -n "$ready_head" ]; then
			[[ $tip == "$ready_head"* ]] || refuse "$branch has commits after the merged head $ready_head"
		else
			if ! git -C "$root" merge-base --is-ancestor "$tip" FETCH_HEAD; then
				# Without a ready event before the merged event, the merged head is unknown.
				ready_seen=$(jq -r --arg m "$merged" "$line_def"'
					to_entries as $e |
					[$e[] | select((.value.author // "") | startswith("o-")) | select(.value | line | test("^event=merged( |$)") and test(" merged_sha=" + $m + "( |$)"))] | last as $mg |
					if $mg == null then 0 else
					[$e[] | select(.key < $mg.key) | select((.value.author // "") | startswith("o-")) | select(.value | line | test("^event=ready( |$)"))] | length end' <<<"$comments")
				if [ "$ready_seen" = 0 ]; then
					refuse "no orchestrator ready event before merged_sha=$merged; record scripts/event.sh $bead ready head=<merged head> and retry"
				fi
				refuse "$branch has commits not on $ref"
			fi
		fi
	fi
	if [ -z "$ported" ]; then
		rc=0
		remote_tip=$(git -C "$root" ls-remote --heads origin "refs/heads/$branch") || rc=$?
		[ "$rc" -eq 0 ] || refuse "cannot read origin to compare $branch"
		remote_tip=${remote_tip%%[[:space:]]*}
		[ -z "$remote_tip" ] || [ "$abandoned" = true ] || [ "$remote_tip" = "$tip" ] || refuse "origin/$branch is not at the local tip of $branch"
		# Delete only the verified remote tip, before anything local is removed: a remote that
		# moved since the check fails the lease and nothing is touched. --no-verify because the
		# source checkout's pre-push hook tests unrelated local state.
		if [ -n "$remote_tip" ]; then
			git -C "$root" push -q --no-verify "--force-with-lease=refs/heads/$branch:$remote_tip" origin ":refs/heads/$branch"
			remote_deleted=1
		fi
	fi
fi

if command -v agent-browser >/dev/null; then
	AGENT_BROWSER_NAMESPACE="$agent" agent-browser close --all >/dev/null 2>&1 || true
	printf 'browser namespace %s: closed\n' "$agent"
	stopped+=(browser)
fi

compose=""
if command -v docker >/dev/null; then
	while IFS=$'\t' read -r project dir; do
		[ -n "$project" ] && inside "$dir" || continue
		filter="label=com.docker.compose.project=$project"
		docker ps -aq --filter "$filter" | xargs -r docker rm -f -v >/dev/null
		docker volume ls -q --filter "$filter" | xargs -r docker volume rm -f >/dev/null
		docker network ls -q --filter "$filter" | xargs -r docker network rm >/dev/null
		printf 'compose %s: removed\n' "$project"
		compose=1
	done < <(docker ps -a --format '{{.Label "com.docker.compose.project"}}	{{.Label "com.docker.compose.project.working_dir"}}' | sort -u)
fi

# Never signal this script or the shell that called it.
declare -A spare=()
p=$$
while [ "$p" -gt 1 ]; do
	spare[$p]=1
	p=$(ps -o ppid= -p "$p" | tr -d ' ')
done

platform=$(uname -s)
if [ "$platform" = Darwin ]; then
	if [ "$keep_agent" = --keep-agent ]; then
		# lsof exits 1 when no listeners match.
		candidates=$(lsof -nP -iTCP -sTCP:LISTEN -t | sort -u) || [ "$?" -eq 1 ]
	else
		candidates=$(ps -axo pid=)
	fi
elif [ "$keep_agent" = --keep-agent ]; then
	candidates=$(ss -ltnpH | { grep -o 'pid=[0-9]*' || [ "$?" -eq 1 ]; } | cut -d= -f2 | sort -u)
else
	candidates=$(ls /proc | grep -E '^[0-9]+$')
fi
pids=()
for pid in $candidates; do
	[ -z "${spare[$pid]:-}" ] || continue
	if [ "$platform" = Darwin ]; then
		cwd=$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p') || continue
	else
		cwd=$(readlink "/proc/$pid/cwd" 2>/dev/null) || continue
	fi
	inside "${cwd% (deleted)}" && pids+=("$pid")
done

if [ "${#pids[@]}" -gt 0 ]; then
	kill -TERM "${pids[@]}" 2>/dev/null || true
	for _ in 1 2 3 4 5; do
		alive=()
		for pid in "${pids[@]}"; do kill -0 "$pid" 2>/dev/null && alive+=("$pid"); done
		[ "${#alive[@]}" -eq 0 ] && break
		sleep 1
	done
	for pid in "${pids[@]}"; do kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null || true; done
fi
[ -z "$compose" ] || stopped+=(compose)
printf 'processes under %s: %s stopped\n' "$root" "${#pids[@]}"
[ "${#pids[@]}" -eq 0 ] || stopped+=(processes)
if [ "$keep_agent" = --keep-agent ]; then
	# herdr-app hibernates any hibernate=ok worker, and a Codex session cannot be revived:
	# label only a positively identified non-Codex agent.
	# The program is `.status.app`, else only the executable token of argv (after a leading
	# `env` and its K=V assignments), never the prompt. Codex wins if either names it.
	kind=$(hc get "$agent" --json 2>/dev/null | jq -er '
		def known: select(IN("pi", "claude", "agy", "copilot", "codex"));
		def exe: (.argv // []) | (if ((.[0] // "") | split("/") | last) == "env" then .[1:] else . end) |
			(map(test("^[A-Za-z_][A-Za-z0-9_]*=")) | index(false)) as $i | if $i == null then empty else .[$i] | split("/") | last end;
		[(.status.app // empty | if . == "claude-code" then "claude" else . end | known), (exe | known)] |
		if index("codex") then "codex" else first // empty end' 2>/dev/null) || kind=
	case "$kind" in
		codex)
			printf 'codex workers are not hibernated\n'
			hc label "$agent" hibernate= >/dev/null ;;
		"") printf 'cannot identify the agent program of %s; not labelled hibernate=ok\n' "$agent" ;;
		*) hc label "$agent" hibernate=ok >/dev/null ;;
	esac
fi

[ -n "$branch" ] || { record; exit 0; }
source=$(dirname -- "$(git -C "$root" rev-parse --path-format=absolute --git-common-dir)")
stem="${agent#[wr]-}"
for name in "w-$stem" "r-$stem"; do
	hc get "$name" --json >/dev/null 2>&1 || continue
	hc kill "$name" >/dev/null 2>&1 || true
	hc rm "$name" >/dev/null
	printf 'terminal %s: removed\n' "$name"
	if [[ $name == w-* ]]; then stopped+=(worker); else stopped+=(reviewer); fi
done
git -C "$source" worktree remove --force "$root"
git -C "$source" branch -D "$branch" >/dev/null
stopped+=(worktree branch)
[ -z "$remote_deleted" ] || stopped+=(remote-branch)
left=""
for name in "w-$stem" "r-$stem"; do hc get "$name" --json >/dev/null 2>&1 && left+=" terminal $name"; done
git -C "$source" worktree list --porcelain | grep -qxF "worktree $root" && left+=" worktree"
[ ! -e "$root" ] || left+=" path"
git -C "$source" rev-parse --verify -q "refs/heads/$branch" >/dev/null && left+=" branch"
if [ -n "$left" ]; then
	printf 'full cleanup incomplete:%s\n' "$left" >&2
	exit 1
fi
record
printf 'full cleanup %s: terminals, worktree and branch %s removed\n' "$agent" "$branch"
