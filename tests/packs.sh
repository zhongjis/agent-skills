#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_status() {
  local label="$1"
  local expected="$2"

  [[ "$runStatus" -eq "$expected" ]] \
    || fail "$label: expected status $expected, got $runStatus: $runOutput"
}

assert_no_calls() {
  local label="$1"

  [[ ! -s "$callsFile" ]] || fail "$label: fake Skills CLI was invoked"
}

assert_calls() {
  local label="$1"
  local expected="$2"
  local actual

  actual="$(cat -- "$callsFile")"
  [[ "$actual" == "$expected" ]] \
    || fail "$label: unexpected Skills CLI calls
expected:
$expected
actual:
$actual"
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

write_manifest() {
  local pack="$1"
  shift

  {
    printf '{"schema":1,"skills":['
    local separator=""
    local tuple source name
    for tuple in "$@"; do
      source="${tuple%%:*}"
      name="${tuple#*:}"
      printf '%s{"source":"%s","name":"%s"}' "$separator" "$source" "$name"
      separator=,
    done
    printf ']}\n'
  } >"$packsDir/$pack.json"
}

reset_fixture() {
  rm -rf -- "$packsDir" "$callerDir"
  mkdir -p -- "$packsDir" "$callerDir"
  : >"$callsFile"
  runPacksDir=""

  write_manifest typescript \
    '0xBigBoss/claude-code:typescript-best-practices' \
    'bobmatnyc/claude-mpm-skills:biome' \
    'antfu/skills:pnpm' \
    'vercel/turborepo:turborepo' \
    'antfu/skills:vitest'
  write_manifest vercel \
    'vercel-labs/agent-skills:deploy-to-vercel' \
    'vercel-labs/agent-skills:vercel-react-best-practices' \
    'vercel-labs/agent-skills:vercel-composition-patterns' \
    'vercel-labs/agent-skills:vercel-optimize'
  write_manifest collision \
    'owner/one:shared-skill' \
    'owner/two:shared-skill'
  write_manifest failfirst \
    'owner/failing:first-skill' \
    'owner/later:later-skill'
  printf '{not-json\n' >"$packsDir/malformed-json.json"
  printf '{"schema":2,"skills":[]}\n' >"$packsDir/malformed-schema.json"
}

run_packs() {
  set +e
  runOutput="$({
    cd -- "$callerDir"
    PACKS_DIR="${runPacksDir:-$packsDir}" \
      PACKS_SKILLS_BIN="$fakeSkills" \
      FAKE_SKILLS_CALLS="$callsFile" \
      FAKE_SKILLS_LOCK_BYTES_FILE="${lockBytesFile:-}" \
      FAKE_SKILLS_FAIL_SOURCE="${failSource:-}" \
      FAKE_SKILLS_FAIL_STATUS="${failStatus:-37}" \
      "$runner" "$@"
  } 2>&1)"
  runStatus=$?
  set -e
}

packs_multi_source_install() {
  reset_fixture
  run_packs typescript vercel --agent pi
  assert_status packs_multi_source_install 0

  local expected
  expected="${callerDir}"$'\t''add'$'\t''0xBigBoss/claude-code'$'\t''--skill'$'\t''typescript-best-practices'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'$'\n'
  expected+="${callerDir}"$'\t''add'$'\t''bobmatnyc/claude-mpm-skills'$'\t''--skill'$'\t''biome'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'$'\n'
  expected+="${callerDir}"$'\t''add'$'\t''antfu/skills'$'\t''--skill'$'\t''pnpm'$'\t''--skill'$'\t''vitest'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'$'\n'
  expected+="${callerDir}"$'\t''add'$'\t''vercel/turborepo'$'\t''--skill'$'\t''turborepo'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'$'\n'
  expected+="${callerDir}"$'\t''add'$'\t''vercel-labs/agent-skills'$'\t''--skill'$'\t''deploy-to-vercel'$'\t''--skill'$'\t''vercel-react-best-practices'$'\t''--skill'$'\t''vercel-composition-patterns'$'\t''--skill'$'\t''vercel-optimize'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'
  assert_calls packs_multi_source_install "$expected"
}

packs_exact_tuple_dedupe() {
  reset_fixture
  run_packs typescript typescript --agent pi
  assert_status packs_exact_tuple_dedupe 0

  local expected
  expected="${callerDir}"$'\t''add'$'\t''0xBigBoss/claude-code'$'\t''--skill'$'\t''typescript-best-practices'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'$'\n'
  expected+="${callerDir}"$'\t''add'$'\t''bobmatnyc/claude-mpm-skills'$'\t''--skill'$'\t''biome'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'$'\n'
  expected+="${callerDir}"$'\t''add'$'\t''antfu/skills'$'\t''--skill'$'\t''pnpm'$'\t''--skill'$'\t''vitest'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'$'\n'
  expected+="${callerDir}"$'\t''add'$'\t''vercel/turborepo'$'\t''--skill'$'\t''turborepo'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'
  assert_calls packs_exact_tuple_dedupe "$expected"
}

packs_repository_typescript_catalog() {
  reset_fixture
  runPacksDir="$repoRoot/packs"
  run_packs typescript --agent pi
  assert_status packs_repository_typescript_catalog 0

  local expected
  expected="${callerDir}"$'\t''add'$'\t''0xBigBoss/claude-code'$'\t''--skill'$'\t''typescript-best-practices'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'$'\n'
  expected+="${callerDir}"$'\t''add'$'\t''bobmatnyc/claude-mpm-skills'$'\t''--skill'$'\t''biome'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'$'\n'
  expected+="${callerDir}"$'\t''add'$'\t''antfu/skills'$'\t''--skill'$'\t''pnpm'$'\t''--skill'$'\t''vitest'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'$'\n'
  expected+="${callerDir}"$'\t''add'$'\t''vercel/turborepo'$'\t''--skill'$'\t''turborepo'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'
  assert_calls packs_repository_typescript_catalog "$expected"
}

packs_invalid_catalogs_fail_before_cli() {
  local pack
  for pack in unknown malformed-json malformed-schema collision; do
    reset_fixture
    run_packs "$pack" --agent pi
    [[ "$runStatus" -ne 0 ]] || fail "$pack: expected failure"
    assert_no_calls "$pack"
  done
}

packs_invalid_arguments_and_help() {
  reset_fixture
  run_packs --agent pi
  [[ "$runStatus" -ne 0 ]] || fail "missing pack: expected failure"
  assert_no_calls "missing pack"

  reset_fixture
  run_packs typescript
  [[ "$runStatus" -ne 0 ]] || fail "missing --agent: expected failure"
  assert_no_calls "missing --agent"

  reset_fixture
  run_packs typescript --agent pi --unknown
  [[ "$runStatus" -ne 0 ]] || fail "unknown option: expected failure"
  assert_no_calls "unknown option"

  reset_fixture
  run_packs --help
  assert_status help 0
  assert_no_calls help
}

packs_preserves_cli_lock_bytes() {
  reset_fixture
  lockBytesFile="$tempDir/fake-lock-bytes"
  printf 'fake-written lock bytes\nsecond line without newline' >"$lockBytesFile"
  run_packs typescript --agent pi
  assert_status packs_preserves_cli_lock_bytes 0
  cmp -s -- "$lockBytesFile" "$callerDir/skills-lock.json" \
    || fail "packs_preserves_cli_lock_bytes: caller lock bytes changed"
  lockBytesFile=""
}

packs_cli_failure_stops_later_sources() {
  reset_fixture
  failSource='owner/failing'
  failStatus=37
  run_packs failfirst --agent pi
  assert_status packs_cli_failure_stops_later_sources 37

  local expected
  expected="${callerDir}"$'\t''add'$'\t''owner/failing'$'\t''--skill'$'\t''first-skill'$'\t''--agent'$'\t''pi'$'\t''--copy'$'\t''-y'
  assert_calls packs_cli_failure_stops_later_sources "$expected"
  failSource=""
  failStatus=""
}

run_test() {
  local name="$1"
  printf 'TEST: %s\n' "$name"
  "$name"
}

scriptDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repoRoot="$(cd -- "$scriptDir/.." && pwd -P)"
runner="$repoRoot/packs.sh"
tempDir="$(mktemp -d)"
[[ -n "$tempDir" && -d "$tempDir" && "$tempDir" == /*/tmp.* ]] \
  || fail "unsafe temp directory: $tempDir"
trap cleanup EXIT
trap handle_signal HUP INT TERM

packsDir="$tempDir/packs"
callerDir="$tempDir/caller"
callsFile="$tempDir/calls"
fakeSkills="$tempDir/skills"
lockBytesFile=""
failSource=""
failStatus=""
runOutput=""
runStatus=0
runPacksDir=""

cat >"$fakeSkills" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail

: "${FAKE_SKILLS_CALLS:?}"
{
  printf '%s' "$PWD"
  printf '\t%s' "$@"
  printf '\n'
} >>"$FAKE_SKILLS_CALLS"

if [[ -n "${FAKE_SKILLS_LOCK_BYTES_FILE:-}" ]]; then
  cat -- "$FAKE_SKILLS_LOCK_BYTES_FILE" >skills-lock.json
fi

if [[ "${1:-}" == add && "${2:-}" == "${FAKE_SKILLS_FAIL_SOURCE:-}" ]]; then
  exit "${FAKE_SKILLS_FAIL_STATUS:-37}"
fi
FAKE
chmod +x "$fakeSkills"

run_test packs_multi_source_install
run_test packs_exact_tuple_dedupe
run_test packs_repository_typescript_catalog
run_test packs_invalid_catalogs_fail_before_cli
run_test packs_invalid_arguments_and_help
run_test packs_preserves_cli_lock_bytes
run_test packs_cli_failure_stops_later_sources
printf 'PASS: packs public seam\n'
