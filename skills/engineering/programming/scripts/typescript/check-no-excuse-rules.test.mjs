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
      "// allow: SIZE_OK — All syntax-rule fixtures belong to one diagnostic sample.",
      ...Array.from({ length: 251 }, () => "void 0"),
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

  const codeLines = (count) => Array.from({ length: count }, () => "void 0").join("\n")
  for (const [name, source, status, diagnostic] of [
    ["250 code lines", codeLines(250), 0, /warning:.*250 pure LOC/],
    ["251 code lines", codeLines(251), 1, /\[file-too-large\].*251 pure LOC/],
    ["blank and comment lines", `${codeLines(250)}\n\n// comment\n/* block\nbody\n*/\n`, 0, /warning:.*250 pure LOC/],
    ["inline block comments", `${codeLines(249)}\n/* before */ void 0 /* after */`, 0, /warning:.*250 pure LOC/],
    ["JSDoc comments", `/**\n${" * documentation\n".repeat(251)} */\n${codeLines(250)}`, 0, /warning:.*250 pure LOC/],
    ["comment-like strings", `${codeLines(250)}\nconst text = "/* not a comment */ // text"`, 1, /\[file-too-large\].*251 pure LOC/],
    ["multiline template text", `${codeLines(247)}\nconst text = \`\n/* literal\n// literal\n*/\n\``, 1, /\[file-too-large\].*252 pure LOC/],
    ["template interpolation", `${codeLines(249)}\nconst text = \`\${1 /* comment\ncomment */}\``, 1, /\[file-too-large\].*251 pure LOC/],
    ["justified size exception", `// allow: SIZE_OK — One indivisible state-machine closure.\n${codeLines(251)}`, 0, /No violations/],
    ["bare size marker", `// allow: SIZE_OK\n${codeLines(251)}`, 1, /\[file-too-large\]/],
    ["empty justification", `// allow: SIZE_OK —   \n${codeLines(251)}`, 1, /\[file-too-large\]/],
    ["marker inside a string", `const text = "// allow: SIZE_OK — not a comment"\n${codeLines(250)}`, 1, /\[file-too-large\]/],
    ["pure literal data", `export const table = {\n${Array.from({ length: 251 }, (_, i) => `key${i}: ["value", -1, true, null],`).join("\n")}\n} as const`, 0, /No violations/],
    ["data with executable value", `const table = [\n${Array.from({ length: 250 }, () => '"value",').join("\n")}\nrun()]`, 1, /\[file-too-large\]/],
    ["data with executable binding", `const { value = run() } = {\n${Array.from({ length: 251 }, (_, i) => `key${i}: null,`).join("\n")}\n}`, 1, /\[file-too-large\]/],
  ]) {
    test(`#when checking ${name} #then size policy determines the CLI result`, () => {
      const target = `${name.replaceAll(" ", "-")}.ts`
      writeFileSync(join(callerDir, target), source)
      const result = runNoExcuse(callerDir, target)
      assert.equal(result.error, undefined)
      assert.equal(result.status, status, result.stderr)
      assert.match(result.stdout + result.stderr, diagnostic)
    })
  }

  test("#when the caller project genuinely lacks typescript #then it fails with a clear error and exit 2", { timeout: 60_000 }, () => {
    const result = runNoExcuse(callerWithoutTypescriptDir, "clean.ts")

    assert.equal(result.error, undefined)
    assert.equal(result.status, 2)
    assert.match(result.stderr, /cannot resolve "typescript" from the caller project/)
  })
})
