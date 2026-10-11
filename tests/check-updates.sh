#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  if [[ -n "${tempDir:-}" && -d "$tempDir" && "$tempDir" == /*/tmp.* ]]; then
    rm -rf -- "$tempDir"
    [[ ! -e "$tempDir" ]] || fail "temp cleanup failed: $tempDir"
  fi
}

handle_signal() {
  trap - HUP INT TERM
  exit 130
}

assert_contains() {
  local label="$1"
  local needle="$2"

  [[ "$runOutput" == *"$needle"* ]] \
    || fail "$label: missing '$needle' in: $runOutput"
}

assert_status() {
  local label="$1"
  local expected="$2"

  [[ "$runStatus" -eq "$expected" ]] \
    || fail "$label: expected status $expected, got $runStatus: $runOutput"
}

run_check() {
  : >"$callsFile"
  runStatus=0
  runOutput="$(cd "$workDir" && "$scriptPath" "$@" 2>&1)" || runStatus=$?
}

fingerprint() {
  (cd "$rootDir" && find . -type f | sort | xargs cksum)
}

scriptPath="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)/check-updates.sh"
tempDir="$(mktemp -d)"
trap cleanup EXIT
trap handle_signal HUP INT TERM

rootDir="$tempDir/root"
workDir="$tempDir/work"
ownTmp="$tempDir/tmp"
callsFile="$tempDir/calls"
fakeBin="$tempDir/fake-skills"
mkdir -p "$rootDir/.agents/skills" "$workDir" "$ownTmp"
export TMPDIR="$ownTmp"
export CHECK_UPDATES_ROOT="$rootDir"
export CHECK_UPDATES_SKILLS_BIN="$fakeBin"
export CALLS_FILE="$callsFile"

cat >"$fakeBin" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail

printf '%s' "$PWD" >>"$CALLS_FILE"
printf '\t%s' "$@" >>"$CALLS_FILE"
printf '\n' >>"$CALLS_FILE"

name=""
while (($#)); do
  [[ "$1" == --skill ]] && name="$2"
  shift
done

if [[ "$name" == broken ]]; then
  printf '\033[2K\033[1G\033[31m■\033[39m  No matching skills found for: %s\n' "$name"
  exit 1
fi

mkdir -p ".agents/skills/$name"
case "$name" in
  newer) printf 'new line\n' ;;
  *) printf 'same\n' ;;
esac >".agents/skills/$name/SKILL.md"
FAKE
chmod +x "$fakeBin"

cat >"$rootDir/skills-lock.json" <<'JSON'
{"version":1,"skills":{
"zeta":{"source":"o/zeta","sourceType":"github","skillPath":"SKILL.md","computedHash":"x"},
"alpha":{"source":"o/alpha","sourceType":"github","skillPath":"skills/alpha/SKILL.md","computedHash":"x"},
"newer":{"source":"o/newer","sourceType":"github","skillPath":"skills/newer/SKILL.md","computedHash":"x"},
"broken":{"source":"o/broken","sourceType":"github","skillPath":"skills/broken/SKILL.md","computedHash":"x"},
"nested":{"source":"o/nested","sourceType":"github","skillPath":"a/b/SKILL.md","ref":"main","computedHash":"x"},
"gitlabby":{"source":"https://example.com/x.git","sourceType":"git","skillPath":"SKILL.md","computedHash":"x"}
}}
JSON
for name in alpha newer nested zeta; do
  mkdir -p "$rootDir/.agents/skills/$name"
  printf 'same\n' >"$rootDir/.agents/skills/$name/SKILL.md"
done
before="$(fingerprint)"

run_check
assert_status "mixed run" 1
expected="current  alpha
failed   broken: No matching skills found for: broken
failed   gitlabby: unsupported source type git
current  nested
outdated newer
current  zeta

3 current, 1 outdated, 2 failed
Refresh (from repo root):
  skills add o/newer/skills/newer --skill newer --agent universal --copy -y"
[[ "$runOutput" == "$expected" ]] || fail "mixed run: unexpected output:
$runOutput"

expectedCalls=""
for entry in "alpha:o/alpha/skills/alpha" "broken:o/broken/skills/broken" \
  "nested:o/nested/a/b#main" "newer:o/newer/skills/newer" "zeta:o/zeta"; do
  expectedCalls+="add	${entry#*:}	--skill	${entry%%:*}	--agent	universal	--copy	-y"$'\n'
done
actualCalls="$(cut -f2- "$callsFile")"$'\n'
[[ "$actualCalls" == "$expectedCalls" ]] \
  || fail "mixed run: unexpected CLI calls:
$actualCalls"
while IFS=$'\t' read -r callCwd _; do
  [[ "$callCwd" != "$rootDir"* ]] || fail "CLI ran inside root: $callCwd"
done <"$callsFile"

run_check newer --diff
assert_status "diff" 1
assert_contains "diff" "outdated newer"
assert_contains "diff" "--- .agents/skills/newer/SKILL.md"
assert_contains "diff" "+++ upstream/newer/SKILL.md"
assert_contains "diff" "-same"
assert_contains "diff" "+new line"
[[ "$(wc -l <"$callsFile")" -eq 1 ]] || fail "diff: expected one CLI call"

run_check alpha
assert_status "named current" 0
[[ "$runOutput" == "current  alpha

1 current, 0 outdated, 0 failed" ]] || fail "named current: $runOutput"
[[ "$(wc -l <"$callsFile")" -eq 1 ]] || fail "named current: expected one CLI call"

run_check nope
assert_status "unknown skill" 2
[[ ! -s "$callsFile" ]] || fail "unknown skill: CLI was invoked"

run_check alpha nope
assert_status "unknown skill among known" 2
[[ ! -s "$callsFile" ]] || fail "unknown skill among known: CLI was invoked"

run_check --bogus
assert_status "unknown option" 2
[[ ! -s "$callsFile" ]] || fail "unknown option: CLI was invoked"

runStatus=0
runOutput="$(CHECK_UPDATES_ROOT="$tempDir/empty" "$scriptPath" 2>&1)" || runStatus=$?
assert_status "missing lock" 2
[[ ! -s "$callsFile" ]] || fail "missing lock: CLI was invoked"

run_check --help
assert_status "help" 0
assert_contains "help" "Usage: check-updates.sh"

[[ "$(fingerprint)" == "$before" ]] || fail "fixture root was modified"
[[ -z "$(ls -A "$ownTmp")" ]] || fail "script temp root was not cleaned: $(ls -A "$ownTmp")"

printf 'check-updates tests passed\n'
