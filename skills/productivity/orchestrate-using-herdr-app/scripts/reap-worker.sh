#!/usr/bin/env bash
# Usage: reap-worker.sh <worktree> <agent> [--keep-agent | --full <branch> [--keep-remote]]
# Stop what a worker started in <worktree>: its agent-browser namespace,
# Compose projects whose working_dir is inside <worktree>, and its processes.
# --keep-agent stops only listening processes (dev servers) and keeps the
# agent, its LSP and MCP children, and the worktree for follow-ups, then
# labels the settled worker hibernate=ok after cleanup.
# --full <branch> is full cleanup after a merged, released task: it also removes the
# w-/r- terminals for the agent's stem, the git worktree, and the local and remote
# <branch>, then confirms each is gone. --keep-remote, for non-merge work, keeps the
# remote branch as evidence and refuses a dirty worktree or a head missing from origin.
# Matches cwd via /proc on Linux and lsof on macOS.
set -euo pipefail

usage() {
	printf 'usage: reap-worker.sh <worktree> <agent> [--keep-agent | --full <branch> [--keep-remote]]\n' >&2
	exit 1
}
keep_agent="" branch="" keep_remote=""
case "$#" in
	2) ;;
	3) [ "$3" = --keep-agent ] || usage; keep_agent=--keep-agent ;;
	4) [ "$3" = --full ] && [ -n "$4" ] || usage; branch="$4" ;;
	5) [ "$3" = --full ] && [ -n "$4" ] && [ "$5" = --keep-remote ] || usage; branch="$4" keep_remote=1 ;;
	*) usage ;;
esac
root=$(realpath -m -- "$1")
agent="$2"
[ "$root" != / ] && [ "$root" != "$(realpath -m -- "$HOME")" ] || {
	printf 'refusing to reap %s\n' "$root" >&2
	exit 1
}

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

if command -v agent-browser >/dev/null; then
	AGENT_BROWSER_NAMESPACE="$agent" agent-browser close --all >/dev/null 2>&1 || true
	printf 'browser namespace %s: closed\n' "$agent"
fi

if command -v docker >/dev/null; then
	while IFS=$'\t' read -r project dir; do
		[ -n "$project" ] && inside "$dir" || continue
		filter="label=com.docker.compose.project=$project"
		docker ps -aq --filter "$filter" | xargs -r docker rm -f -v >/dev/null
		docker volume ls -q --filter "$filter" | xargs -r docker volume rm -f >/dev/null
		docker network ls -q --filter "$filter" | xargs -r docker network rm >/dev/null
		printf 'compose %s: removed\n' "$project"
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
printf 'processes under %s: %s stopped\n' "$root" "${#pids[@]}"
if [ "$keep_agent" = --keep-agent ]; then hc label "$agent" hibernate=ok >/dev/null; fi

[ -n "$branch" ] || exit 0
source=$(dirname -- "$(git -C "$root" rev-parse --path-format=absolute --git-common-dir)")
stem="${agent#[wr]-}"
for name in "w-$stem" "r-$stem"; do
	hc get "$name" --json >/dev/null 2>&1 || continue
	hc kill "$name" >/dev/null 2>&1 || true
	hc rm "$name" >/dev/null
	printf 'terminal %s: removed\n' "$name"
done
git -C "$source" worktree remove --force "$root"
git -C "$source" branch -D "$branch" >/dev/null
if [ -z "$keep_remote" ] && git -C "$source" ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
	# The source checkout's pre-push hook tests unrelated local state.
	git -C "$source" push -q --no-verify origin --delete "$branch"
fi
left=""
for name in "w-$stem" "r-$stem"; do hc get "$name" --json >/dev/null 2>&1 && left+=" terminal $name"; done
git -C "$source" worktree list --porcelain | grep -qxF "worktree $root" && left+=" worktree"
[ ! -e "$root" ] || left+=" path"
git -C "$source" rev-parse --verify -q "refs/heads/$branch" >/dev/null && left+=" branch"
if [ -n "$left" ]; then
	printf 'full cleanup incomplete:%s\n' "$left" >&2
	exit 1
fi
printf 'full cleanup %s: terminals, worktree and branch %s removed\n' "$agent" "$branch"
