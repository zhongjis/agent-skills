#!/usr/bin/env bash
# Offline check of bot-active.sh against paginated API fixtures; never calls real GitHub.
set -euo pipefail
trap 'printf "FAIL: %s:%s (exit %s): %s\n" "${BASH_SOURCE[0]}" "$LINENO" "$?" "$BASH_COMMAND" >&2' ERR
script="$(cd "$(dirname -- "${BASH_SOURCE[0]}")/../scripts" && pwd)/bot-active.sh"
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/bin"
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
check 1 '' env GH_MODE=ok "$script" 7 --repo owner/repo
for channel in comments reactions reviews inline; do
	# The second page has the bot; the human on the first must not count.
	printf '[[{"user":{"login":"human","type":"User"},"created_at":"2026-01-01T00:00:00Z"}],[{"user":{"login":"review[bot]","type":"Bot"},"created_at":"2026-01-01T01:00:00Z","submitted_at":"2026-01-01T01:00:00Z"}]]\n' > "$tmp/bot-$channel.json"
	check 0 'review[bot]' env GH_MODE=ok "$script" 7 --repo owner/repo --since 2026-01-01T00:30:00Z
	check 1 '' env GH_MODE=ok "$script" 7 --repo owner/repo --since 2026-01-01T02:00:00+01:00
	printf '[[]]\n' > "$tmp/bot-$channel.json"
done
printf '[{"check_runs":[{"app":{"slug":"checker"},"started_at":"2026-01-01T00:00:01Z"}]}]\n' > "$tmp/bot-checks.json"
check 0 'checker[bot]' env GH_MODE=ok "$script" 7 --repo owner/repo --since 2026-01-01T00:00:00.500Z
check 1 '' env GH_MODE=ok "$script" 7 --repo owner/repo --since 2026-01-01T00:00:02Z
printf '[{"check_runs":[]}]\n' > "$tmp/bot-checks.json"
printf '[[{"user":{"login":"ci-bot","type":"User"},"created_at":"2026-01-01T00:00:00Z"},{"user":{"login":"helperbot","type":"User"},"created_at":"2026-01-01T00:00:00Z"}]]\n' > "$tmp/bot-comments.json"
check 0 $'ci-bot\nhelperbot' env GH_MODE=ok "$script" 7 --repo owner/repo
check 2 'API unavailable' env GH_MODE=api-error "$script" 7 --repo owner/repo
check 2 'usage' "$script" 7
printf '%s bot-active checks passed\n' "$checks"
