#!/usr/bin/env bash
# Usage: watch-agent.sh <agent> [--quiet <minutes>] [--since <fp>]
# Exit 0 with one line once the agent needs attention:
#   settled: <status>   blocked/error re-checked after 5 s; idle/done confirmed over 30 s
#   quiet <n>m (working) fp=<fp>[: <hint>]   status stayed working, but the screen
#     (minus spinners, timers, rates) and turn did not change for <n> minutes (default 15)
#   gone | terminal <state>
# --since <fp>: restart after a quiet check-in; while the screen still matches <fp>,
# the quiet threshold doubles so the same state does not re-alert at once.
set -euo pipefail

usage() {
	printf 'usage: watch-agent.sh <agent> [--quiet <minutes>] [--since <fp>]\n' >&2
	exit 1
}
[ "$#" -ge 1 ] && [ -n "$1" ] || usage
name="$1"
shift
quiet_min=15 since=""
while [ "$#" -gt 0 ]; do
	case "$1" in
		--quiet) [ "$#" -ge 2 ] && [[ $2 =~ ^[0-9]+$ ]] || usage; quiet_min="$2"; shift 2 ;;
		--since) [ "$#" -ge 2 ] || usage; since="$2"; shift 2 ;;
		*) usage ;;
	esac
done

# Sets state, status, turn; exits for a gone, finished, or unreadable terminal.
snap() {
	local get_status=0 snapshot fields
	snapshot=$(hc get "$name" --json 2>&1) || get_status=$?
	if [ "$get_status" -eq 3 ]; then
		printf 'agent %s: gone\n' "$name"
		exit 0
	fi
	if [ "$get_status" -ne 0 ]; then
		printf '%s\n' "$snapshot" >&2
		exit "$get_status"
	fi
	fields=$(jq -er '[.state, (.status.state // "none"), (.turn // 0)] | @tsv' <<<"$snapshot")
	IFS=$'\t' read -r state status turn <<<"$fields"
	if [ "$state" != live ]; then
		printf 'agent %s: terminal %s\n' "$name" "$state"
		exit 0
	fi
}

screen() { hc read "$name" 2>/dev/null || true; }

# Screen plus turn, without parts that move while nothing progresses:
# spinner glyphs, elapsed timers, token rates, and clock times. Token counts stay.
fingerprint() {
	{ printf '%s\n' "$turn"; screen; } |
		perl -CSD -pe 's/[\x{2800}-\x{28FF}·✢✳✶✻✽*]//g;
			s/\b\d+(?:\.\d+)?\s?tok\/s\b//g;
			s/\b\d{1,2}:\d{2}(?::\d{2})?\b//g;
			s/\b\d+h(?:\s?\d+m)?(?:\s?\d+s)?\b|\b\d+m(?:\s?\d+s)?\b|\b\d+(?:\.\d+)?s\b//g' |
		sha256sum | cut -c1-12
}

last_fp="" changed_at=$(date +%s)
while true; do
	wait_status=0
	out=$(hc wait "$name" --json --timeout 120 2>&1) || wait_status=$?
	snap
	if [ "$wait_status" -ne 0 ]; then
		printf 'agent %s: wait failed; status=%s\n%s\n' "$name" "$status" "$out" >&2
		exit "$wait_status"
	fi
	case "$status" in
		blocked|error)
			sleep 5
			snap
			case "$status" in blocked|error) printf 'agent %s settled: %s (turn %s)\n' "$name" "$status" "$turn"; exit 0 ;; esac
			;;
		idle|done)
			for _ in 1 2 3 4 5 6; do
				sleep 5
				snap
				case "$status" in idle|done) ;; *) continue 2 ;; esac
			done
			# Pi can read done while /compact runs past the confirm window.
			screen | tail -n 15 | grep -q Compacting && continue
			printf 'agent %s settled: %s (turn %s)\n' "$name" "$status" "$turn"
			exit 0
			;;
		working|none)
			fp=$(fingerprint)
			now=$(date +%s)
			if [ "$fp" != "$last_fp" ]; then
				last_fp="$fp" changed_at="$now"
				continue
			fi
			limit=$((quiet_min * 60))
			[ "$fp" != "$since" ] || limit=$((limit * 2))
			[ $((now - changed_at)) -ge "$limit" ] || continue
			hint=$(screen | tail -n 15 | grep -m1 -E 'Goal blocked|❯ *[0-9]+\.' | sed 's/^[[:space:]]*//' || true)
			printf 'agent %s: quiet %sm (working) fp=%s%s\n' "$name" "$(((now - changed_at) / 60))" "$fp" "${hint:+: $hint}"
			exit 0
			;;
		*) printf 'agent %s: unexpected status %s\n' "$name" "$status" >&2; exit 1 ;;
	esac
done
