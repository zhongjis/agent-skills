#!/usr/bin/env bash
# Run review-diff.sh against a disposable Git repository.
set -euo pipefail
trap 'printf "FAIL: %s:%s (exit %s): %s\n" "${BASH_SOURCE[0]}" "$LINENO" "$?" "$BASH_COMMAND" >&2' ERR
script="$(cd "$(dirname -- "${BASH_SOURCE[0]}")/../scripts" && pwd)/review-diff.sh"
tmp=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf -- "$tmp"' EXIT
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
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
assert() { jq -e "$1" <<<"$json" >/dev/null || { printf 'FAIL: %s\n%s\n' "$1" "$json" >&2; exit 1; }; checks=$((checks + 1)); }

w="$tmp/work"
git init -q -b main "$w"
git -C "$w" config user.email fixture@example.invalid
git -C "$w" config user.name Fixture
mkdir -p "$w/src" "$w/docs"
printf 'a\nb\nc\nd\ne\n' >"$w/src/old.sh"
printf 'x\n' >"$w/README.md"
printf '*.gen.ts linguist-generated\n' >"$w/.gitattributes"
git -C "$w" add -A && git -C "$w" commit -qm base
main=$(git -C "$w" rev-parse HEAD)

git -C "$w" switch -qc topic
git -C "$w" mv src/old.sh "src/new name.sh"
printf 'y\n' >>"$w/README.md"
printf 'test\n' >"$w/src/app.test.ts"
printf 'gen\n' >"$w/src/api.gen.ts"
printf 'lock\n' >"$w/flake.lock"
git -C "$w" add -A && git -C "$w" commit -qm first
first=$(git -C "$w" rev-parse HEAD)
git -C "$w" switch -q main
printf 'main moved\n' >"$w/docs/main.md"
git -C "$w" add -A && git -C "$w" commit -qm main-moved
git -C "$w" switch -q topic
printf 'f\n' >>"$w/src/new name.sh"
git -C "$w" add -A && git -C "$w" commit -qm second
head=$(git -C "$w" rev-parse HEAD)

# Full scope uses the merge-base, so main's later commit stays out.
json=$("$script" "$w" --base main --head "$head" --out "$tmp/full")
assert '.mode == "full" and .base == "main" and .from == "'"$main"'" and .head == "'"$head"'"'
assert '.range == "'"$main..$head"'" and .dirty == false'
assert '[.files[].path] | sort == ["README.md", "flake.lock", "src/api.gen.ts", "src/app.test.ts", "src/new name.sh"]'
assert '.files[] | select(.path == "src/new name.sh") | .status == "renamed" and .old_path == "src/old.sh" and .label == "code" and .insertions == 1'
assert '.files[] | select(.path == "README.md") | .label == "doc" and (has("old_path") | not)'
assert '.files[] | select(.path == "src/app.test.ts") | .label == "test" and .status == "added"'
assert '.files[] | select(.path == "src/api.gen.ts") | .label == "generated"'
assert '.files[] | select(.path == "flake.lock") | .label == "lockfile"'
assert '.size == {files: 3, lines: 3, level: "low"}'
assert '.patch == "'"$tmp/full/range.patch"'"'
grep -q '^rename to src/new name.sh$' "$tmp/full/range.patch" && ! grep -q 'main moved' "$tmp/full/range.patch"
checks=$((checks + 1))

# Incremental scope covers only commits after the last reviewed head; head defaults to HEAD.
json=$("$script" "$w" --last-reviewed "$first")
assert '.mode == "incremental" and .last_reviewed == "'"$first"'" and .from == "'"$first"'"'
assert '[.files[].path] == ["src/new name.sh"] and .files[0].status == "modified"'
assert '.patch | test("/range.patch$")'

# Guards.
check 3 'is not the pinned head' "$script" "$w" --base main --head "$first"
check 3 'is not an ancestor' "$script" "$w" --last-reviewed "$(git -C "$w" rev-parse main)"
check 3 'empty scope' "$script" "$w" --last-reviewed "$head"
check 3 'not a commit: nope' "$script" "$w" --base nope
out=$("$script" "$w" --base nope 2>&1) || true
[ "$out" = 'not a commit: nope' ] || { printf 'FAIL: unknown base printed extra errors:\n%s\n' "$out" >&2; exit 1; }
checks=$((checks + 1))
check 3 'is inside the worktree' "$script" "$w" --base main --out "$w/rev"
[ ! -e "$w/rev" ] || { printf 'FAIL: --out inside the worktree was created\n' >&2; exit 1; }
checks=$((checks + 1))
check 1 usage "$script" "$w" --base main --last-reviewed "$first"
check 1 usage "$script" "$w" --head "$head"

# Copies are detected, and user diff config does not change patch headers.
seq 1 40 >"$w/src/copy-me.sh"
git -C "$w" add -A && git -C "$w" commit -qm source
copy_base=$(git -C "$w" rev-parse HEAD)
cp "$w/src/copy-me.sh" "$w/src/copied.sh"
printf 'extra\n' >>"$w/src/copy-me.sh"
git -C "$w" add -A && git -C "$w" commit -qm copy
json=$(GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=diff.noprefix GIT_CONFIG_VALUE_0=true "$script" "$w" --last-reviewed "$copy_base" --out "$tmp/copy")
assert '.files[] | select(.path == "src/copied.sh") | .status == "copied" and .old_path == "src/copy-me.sh"'
grep -q '^diff --git a/src/copy-me.sh b/src/copy-me.sh$' "$tmp/copy/range.patch"
checks=$((checks + 1))

# Labels come from the head commit's attributes, not uncommitted edits to them.
printf '*.sh linguist-generated\n' >>"$w/.gitattributes"
json=$("$script" "$w" --last-reviewed "$copy_base")
assert '.files[] | select(.path == "src/copied.sh") | .label == "code"'
git -C "$w" checkout -q -- .gitattributes

# Uncommitted edits are flagged, not reviewed.
printf 'dirty\n' >>"$w/README.md"
json=$("$script" "$w" --base main)
assert '.dirty == true and (.files[] | select(.path == "README.md") | .insertions == 1)'

printf 'review-diff: %s checks passed\n' "$checks"
