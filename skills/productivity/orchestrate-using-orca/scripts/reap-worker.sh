#!/usr/bin/env bash
# Usage: reap-worker.sh <worktree> <agent> [--keep-agent]
# Stop what a worker started in <worktree>: its agent-browser namespace,
# Compose projects whose working_dir is inside <worktree>, and its processes.
# --keep-agent stops only listening processes (dev servers) and keeps the
# agent, its LSP and MCP children, and the worktree for follow-ups.
# Finds processes with lsof, so it runs on macOS and Linux.
set -euo pipefail

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ] || { [ "$#" -eq 3 ] && [ "$3" != --keep-agent ]; }; then
	printf 'usage: reap-worker.sh <worktree> <agent> [--keep-agent]\n' >&2
	exit 1
fi
command -v lsof >/dev/null || {
	printf 'lsof required\n' >&2
	exit 1
}
root=$(cd -- "$1" && pwd -P)
agent="$2"
keep_agent="${3:-}"
[ "$root" != / ] && [ "$root" != "$(cd -- "$HOME" && pwd -P)" ] || {
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
		[ -n "$project" ] || continue
		# Compare real paths: on macOS /var and /tmp are symlinks into /private.
		real=$(cd -- "$dir" 2>/dev/null && pwd -P) || real="$dir"
		inside "$real" || continue
		filter="label=com.docker.compose.project=$project"
		docker ps -aq --filter "$filter" | xargs -r docker rm -f -v >/dev/null
		docker volume ls -q --filter "$filter" | xargs -r docker volume rm -f >/dev/null
		docker network ls -q --filter "$filter" | xargs -r docker network rm >/dev/null
		printf 'compose %s: removed\n' "$project"
	done < <(docker ps -a --format '{{.Label "com.docker.compose.project"}}	{{.Label "com.docker.compose.project.working_dir"}}' | sort -u)
fi

# Never signal this script or the shell that called it.
spare=" "
p=$$
while [ "$p" -gt 1 ]; do
	spare="$spare$p "
	p=$(ps -o ppid= -p "$p" | tr -d ' ')
done

# --keep-agent narrows candidates to processes listening on TCP.
only=""
if [ "$keep_agent" = --keep-agent ]; then
	only=" $(lsof -nP -iTCP -sTCP:LISTEN -t 2>/dev/null | sort -u | tr '\n' ' ') "
fi
pids=()
pid=""
while IFS= read -r line; do
	case "$line" in
		p*) pid=${line#p} ;;
		n*)
			case "$spare" in *" $pid "*) continue ;; esac
			if [ -n "$only" ]; then
				case "$only" in *" $pid "*) ;; *) continue ;; esac
			fi
			n=${line#n}
			inside "${n% (deleted)}" && pids+=("$pid")
			;;
	esac
done < <(lsof -a -d cwd -Fpn 2>/dev/null || true)

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
