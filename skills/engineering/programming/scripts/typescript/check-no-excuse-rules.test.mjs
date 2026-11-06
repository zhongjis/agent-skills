import assert from "node:assert/strict"
import { spawnSync } from "node:child_process"
import { copyFileSync, mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from "node:fs"
import { createRequire } from "node:module"
import { tmpdir } from "node:os"
import { dirname, join } from "node:path"
import { after, before, describe, test } from "node:test"

// Regression for lazycodex#111: the script must resolve `typescript` from the
// caller project (cwd), not from the script's own location, so it works when
// executed from an installed `~/.codex/...` skill cache.

const scriptSource = join(import.meta.dirname, "check-no-excuse-rules.mjs")
const repoRequire = createRequire(import.meta.url)
const typescriptPackageDir = dirname(repoRequire.resolve("typescript/package.json"))

let tempRoot = ""
let cachedScript = ""
let callerDir = ""
let callerWithoutTypescriptDir = ""

function runNoExcuse(cwd, target) {
  const env = { ...process.env }
  delete env.NODE_PATH
  return spawnSync(process.execPath, [cachedScript, target], {
    cwd,
    encoding: "utf8",
    env,
    timeout: 60_000,
  })
}

describe("#given the no-excuse script is executed from an installed ~/.codex-style skill cache", () => {
  before(() => {
    // given a cache copy of the script outside any project, and two caller projects:
    // one providing node_modules/typescript, one without typescript at all
    tempRoot = mkdtempSync(join(tmpdir(), "no-excuse-cache-repro-"))
    const cacheDir = join(tempRoot, ".codex", "skills", "programming", "scripts", "typescript")
    mkdirSync(cacheDir, { recursive: true })
    cachedScript = join(cacheDir, "check-no-excuse-rules.mjs")
    copyFileSync(scriptSource, cachedScript)

    callerDir = join(tempRoot, "caller-project")
    mkdirSync(join(callerDir, "node_modules"), { recursive: true })
    symlinkSync(typescriptPackageDir, join(callerDir, "node_modules", "typescript"), "junction")
    writeFileSync(join(callerDir, "clean.ts"), "export const answer: number = 42\n")
    writeFileSync(join(callerDir, "violating.ts"), [
      "declare const value: unknown",
      "const anyAssertion = value as any",
      "const unknownAssertion = value as unknown",
      "// @ts-ignore",
      "const ignored = value",
      "// @ts-expect-error",
      "const expected = value",
      "enum Color { Red }",
      "declare const maybe: { value?: string }",
      "maybe.value!",
      "throw \"failure\"",
      "export let mutable = 1",
      "const annotated: any = value",
      "function returnsAny(): any { return value }",
      "try { returnsAny() } catch {}",
      "try { returnsAny() } catch (error) { console.error(error) }",
    ].join("\n"))

    callerWithoutTypescriptDir = join(tempRoot, "caller-without-typescript")
    mkdirSync(callerWithoutTypescriptDir, { recursive: true })
    writeFileSync(join(callerWithoutTypescriptDir, "clean.ts"), "export const answer: number = 42\n")
  })

  after(() => {
    rmSync(tempRoot, { recursive: true, force: true })
  })

  test("#when the caller project provides typescript #then it resolves the caller's typescript and exits 0", { timeout: 60_000 }, () => {
    const result = runNoExcuse(callerDir, "clean.ts")

    assert.equal(result.error, undefined)
    assert.equal(result.status, 0)
    assert.match(result.stdout, /No violations in 1 file\(s\)\./)
  })

  test("#when a checked file violates every rule #then all 12 rule IDs are reported with exit 1", { timeout: 60_000 }, () => {
    const result = runNoExcuse(callerDir, "violating.ts")

    assert.equal(result.error, undefined)
    assert.equal(result.status, 1)
    for (const ruleId of [
      "no-any-assertion",
      "no-unknown-assertion",
      "no-ts-ignore",
      "no-ts-expect-error",
      "no-enum",
      "no-non-null-assertion",
      "no-throw-literal",
      "no-mutable-export",
      "no-any-annotation",
      "no-explicit-any-return",
      "empty-catch",
      "catch-without-narrowing",
    ]) {
      assert.match(result.stderr, new RegExp(`\\[${ruleId}\\]`))
    }
    assert.match(result.stderr, /12 violation\(s\) in 1 file\(s\)\./)
  })

  test("#when the caller project genuinely lacks typescript #then it fails with a clear error and exit 2", { timeout: 60_000 }, () => {
    const result = runNoExcuse(callerWithoutTypescriptDir, "clean.ts")

    assert.equal(result.error, undefined)
    assert.equal(result.status, 2)
    assert.match(result.stderr, /cannot resolve "typescript" from the caller project/)
  })
})
