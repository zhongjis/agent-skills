#!/usr/bin/env bash
# Usage: review-diff.sh <worktree> (--base <ref> | --last-reviewed <commit>) [--head <sha>] [--out <dir>]
# Pin a committed review scope, write its plain patch, and print JSON scope metadata.
# Full: --base reviews merge-base(<base>, head)..head (same as <base>...head).
# Incremental: --last-reviewed reviews <commit>..head and requires <commit> to be an ancestor of head.
# Every changed file is listed and labelled (code, doc, test, lockfile, generated); none is dropped.
# Exit 1: usage. Exit 3: not a git worktree, head mismatch, unresolved ref, non-ancestor last-reviewed,
# empty scope, --out inside the worktree or not writable, or a failed git diff.
set -euo pipefail

usage() {
	printf 'usage: review-diff.sh <worktree> (--base <ref> | --last-reviewed <commit>) [--head <sha>] [--out <dir>]\n' >&2
	exit 1
}
fail() { printf '%s\n' "$1" >&2; exit 3; }

[ "$#" -ge 3 ] || usage
worktree="$1"
shift
base="" last="" head_arg="" out=""
while [ "$#" -gt 0 ]; do
	case "$1" in
		--base) [ "$#" -ge 2 ] && [ -n "$2" ] || usage; base="$2"; shift 2 ;;
		--last-reviewed) [ "$#" -ge 2 ] && [ -n "$2" ] || usage; last="$2"; shift 2 ;;
		--head) [ "$#" -ge 2 ] && [ -n "$2" ] || usage; head_arg="$2"; shift 2 ;;
		--out) [ "$#" -ge 2 ] && [ -n "$2" ] || usage; out="$2"; shift 2 ;;
		*) usage ;;
	esac
done
if { [ -n "$base" ] && [ -n "$last" ]; } || { [ -z "$base" ] && [ -z "$last" ]; }; then usage; fi
git -C "$worktree" rev-parse --git-dir >/dev/null 2>&1 || fail "not a git worktree: $worktree"

g() { git -C "$worktree" "$@"; }
commit() { g rev-parse --verify --quiet "$1^{commit}" || fail "not a commit: $1"; }

head=$(commit HEAD)
if [ -n "$head_arg" ]; then
	pinned=$(commit "$head_arg")
	[ "$pinned" = "$head" ] || fail "worktree HEAD $head is not the pinned head $pinned; check the worktree and branch"
fi
if [ -n "$base" ]; then
	mode=full input="$base"
	base_sha=$(commit "$base")
	from=$(g merge-base "$base_sha" "$head") || fail "no merge-base between $base and $head"
else
	mode=incremental input="$last"
	from=$(commit "$last")
	g merge-base --is-ancestor "$from" "$head" || fail "last-reviewed $from is not an ancestor of $head; the incremental scope is undefined"
fi

[ -n "$out" ] || out=$(mktemp -d "${TMPDIR:-/tmp}/review-diff.XXXXXX")
top=$(g rev-parse --show-toplevel)
out=$(realpath -m -- "$out")
case "$out/" in "$top"/*) fail "--out $out is inside the worktree; it would show up as an untracked change" ;; esac
mkdir -p -- "$out" 2>/dev/null && [ -w "$out" ] || fail "--out $out is not writable"
patch="$out/range.patch"

# Fixed prefixes keep the patch stable under user diff config such as diff.noprefix.
diff_opts=(-M -C --no-ext-diff --no-textconv --no-color --src-prefix=a/ --dst-prefix=b/)
g diff "${diff_opts[@]}" --name-status -z "$from" "$head" >"$out/name-status" || fail "git diff --name-status failed"
g diff "${diff_opts[@]}" --numstat -z "$from" "$head" >"$out/numstat" || fail "git diff --numstat failed"
mapfile -d '' -t status <"$out/name-status"
mapfile -d '' -t numstat <"$out/numstat"
rm -f -- "$out/name-status" "$out/numstat"
[ "${#status[@]}" -gt 0 ] || fail "empty scope: no committed changes in $from..$head"

# Parse both NUL streams in step; they share git's diff order.
paths=() olds=() kinds=() adds=() dels=()
i=0 j=0
while [ "$i" -lt "${#status[@]}" ]; do
	code="${status[i]}"
	case "$code" in
		R* | C*) olds+=("${status[i + 1]}"); paths+=("${status[i + 2]}"); i=$((i + 3)) ;;
		*) olds+=(""); paths+=("${status[i + 1]}"); i=$((i + 2)) ;;
	esac
	case "$code" in
		A) kinds+=(added) ;; D) kinds+=(deleted) ;; R*) kinds+=(renamed) ;; C*) kinds+=(copied) ;;
		T) kinds+=(typechange) ;; *) kinds+=(modified) ;;
	esac
	IFS=$'\t' read -r a d rest <<<"${numstat[j]}"
	adds+=("$a") dels+=("$d")
	# A rename or copy numstat record leaves the path empty and adds old and new paths.
	if [ -z "$rest" ]; then j=$((j + 3)); else j=$((j + 1)); fi
done

declare -A generated=()
while IFS= read -r -d '' p && IFS= read -r -d '' _ && IFS= read -r -d '' v; do
	[ "$v" = unspecified ] || [ "$v" = unset ] || [ "$v" = false ] || generated["$p"]=1
done < <(printf '%s\0' "${paths[@]}" | g check-attr --source "$head" -z --stdin linguist-generated)

label() {
	local p="$1" name="${1##*/}"
	[ -z "${generated[$p]:-}" ] || { printf generated; return; }
	case "$name" in
		package-lock.json | npm-shrinkwrap.json | pnpm-lock.yaml | yarn.lock | bun.lock | bun.lockb | Cargo.lock | \
			flake.lock | go.sum | poetry.lock | uv.lock | Pipfile.lock | Gemfile.lock | composer.lock | *.lock)
			printf lockfile; return ;;
		*.min.js | *.min.css | *.pb.go | *_generated.* | *.generated.* | *.snap) printf generated; return ;;
		*.test.* | *.spec.* | *_test.* | test_*.py) printf test; return ;;
	esac
	case "/$p" in
		*/test/* | */tests/* | */__tests__/* | */testdata/* | */fixtures/*) printf test ;;
		*.md | *.mdx | *.rst | *.adoc | */docs/*) printf doc ;;
		*) printf code ;;
	esac
}

g diff "${diff_opts[@]}" --output="$patch" "$from" "$head" || fail "git diff failed writing $patch"
dirty=false
[ -z "$(g status --porcelain)" ] || dirty=true

fields=()
for k in "${!paths[@]}"; do
	fields+=("${paths[k]}" "${olds[k]}" "${kinds[k]}" "${adds[k]}" "${dels[k]}" "$(label "${paths[k]}")")
done
jq -n --arg mode "$mode" --arg input "$input" --arg from "$from" --arg head "$head" --arg patch "$patch" \
	--argjson dirty "$dirty" '
	[$ARGS.positional as $f | range(0; $f | length; 6) | {path: $f[.]}
		+ (if $f[. + 1] == "" then {} else {old_path: $f[. + 1]} end)
		+ {status: $f[. + 2], binary: ($f[. + 3] == "-"),
			insertions: ($f[. + 3] | tonumber? // 0), deletions: ($f[. + 4] | tonumber? // 0),
			label: $f[. + 5]}
	] as $files
	| ($files | map(select(.label != "lockfile" and .label != "generated"))) as $sized
	| ($sized | map(.insertions + .deletions) | add // 0) as $lines
	| {mode: $mode, (if $mode == "full" then "base" else "last_reviewed" end): $input,
		from: $from, head: $head, range: "\($from)..\($head)", patch: $patch, dirty: $dirty,
		size: {files: ($sized | length), lines: $lines,
			level: (if ($sized | length) <= 5 and $lines <= 150 then "low" else "high" end)},
		files: $files}' --args ${fields[@]+"${fields[@]}"}
