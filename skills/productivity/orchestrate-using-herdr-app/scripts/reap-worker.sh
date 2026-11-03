#!/usr/bin/env bash
# Usage: reap-worker.sh <worktree> <agent> [--keep-agent]
# Stop what a worker started in <worktree>: its agent-browser namespace,
# Compose projects whose working_dir is inside <worktree>, and its processes.
# --keep-agent stops only listening processes (dev servers) and keeps the
# agent, its LSP and MCP children, and the worktree for follow-ups.
# Linux only: matches processes by /proc/<pid>/cwd.
set -euo pipefail

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ] || { [ "$#" -eq 3 ] && [ "$3" != --keep-agent ]; }; then
	printf 'usage: reap-worker.sh <worktree> <agent> [--keep-agent]\n' >&2
	exit 1
fi
root=$(realpath -m -- "$1")
agent="$2"
keep_agent="${3:-}"
[ "$root" != / ] && [ "$root" != "$(realpath -m -- "$HOME")" ] || {
	printf 'refusing to reap %s\n' "$root" >&2
	exit 1
}

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

if [ "$keep_agent" = --keep-agent ]; then
	candidates=$(ss -ltnpH | grep -o 'pid=[0-9]*' | cut -d= -f2 | sort -u)
else
	candidates=$(ls /proc | grep -E '^[0-9]+$')
fi
pids=()
for pid in $candidates; do
	[ -z "${spare[$pid]:-}" ] || continue
	cwd=$(readlink "/proc/$pid/cwd" 2>/dev/null) || continue
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
