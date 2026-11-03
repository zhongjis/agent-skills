#!/usr/bin/env bash
# Usage: push-pinned.sh <worktree> <branch> <expected-main-sha> [-- <build-command> [args...]]
# Fetch, verify pinned ancestry, optionally build, and push with an explicit lease.
set -euo pipefail

if [ "$#" -lt 3 ]; then
	printf 'usage: push-pinned.sh <worktree> <branch> <expected-main-sha> [-- <build-command> [args...]]\n' >&2
	exit 1
fi
worktree="$1"
branch="$2"
expected="$3"
shift 3
if [ "$#" -gt 0 ]; then
	if [ "$1" != -- ] || [ "$#" -lt 2 ]; then
		printf 'build command must follow --\n' >&2
		exit 1
	fi
	shift
fi

git check-ref-format --branch "$branch" >/dev/null
if [ "$(git -C "$worktree" branch --show-current)" != "$branch" ]; then
	printf 'STOP: worktree not on branch %s\n' "$branch" >&2
	exit 1
fi
git -C "$worktree" fetch --prune origin '+refs/heads/*:refs/remotes/origin/*'
main=$(git -C "$worktree" rev-parse --verify refs/remotes/origin/main)
if [ "$main" != "$expected" ]; then
	printf 'STOP: origin/main is %s, expected %s\n' "$main" "$expected" >&2
	exit 3
fi
git -C "$worktree" merge-base --is-ancestor "$main" HEAD || {
	printf 'STOP: origin/main is not an ancestor of HEAD\n' >&2
	exit 3
}
head=$(git -C "$worktree" rev-parse HEAD)
old=$(git -C "$worktree" rev-parse --verify "refs/remotes/origin/$branch" 2>/dev/null) || old=''
if [ "$#" -gt 0 ]; then
	(pushd -- "$worktree" >/dev/null; "$@")
fi
if [ "$(git -C "$worktree" branch --show-current)" != "$branch" ] ||
	[ "$(git -C "$worktree" rev-parse HEAD)" != "$head" ] ||
	[ "$(git -C "$worktree" rev-parse --verify refs/remotes/origin/main)" != "$main" ]; then
	printf 'STOP: branch, HEAD, or origin/main changed during build\n' >&2
	exit 3
fi
git -C "$worktree" push "--force-with-lease=$branch:$old" origin "$head:refs/heads/$branch"
