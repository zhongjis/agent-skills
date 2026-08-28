#!/usr/bin/env node
/**
 * Check TypeScript files for no-excuse violations.
 *
 * Rules:
 *   no-any-assertion       - `as any`
 *   no-unknown-assertion   - `as unknown`
 *   no-ts-ignore           - `@ts-ignore` comments
 *   no-ts-expect-error     - `@ts-expect-error` comments
 *   no-enum                - `enum` declarations
 *   no-non-null-assertion  - `x!` postfix operator
 *   no-throw-literal       - `throw "string"` / `throw 123`
 *   no-mutable-export      - `export let` / `export var`
 *   no-any-annotation      - `: any` in annotations (opt out: `// no-excuse-ok: any`)
 *   no-explicit-any-return - `(): any` return types (opt out: `// no-excuse-ok: any`)
 *   empty-catch            - `catch { }` or `catch (e) { }` with empty body
 *   catch-without-narrowing - catch block that uses error without instanceof narrowing
 *
 * Usage:
 *   node scripts/check-no-excuse-rules.mjs <file-or-dir>...
 *
 * The `typescript` package is resolved from the caller project (process.cwd()),
 * not from this script's location, so the script works when executed from an
 * installed skill-cache path (e.g. ~/.codex/...) against a project checkout.
 *
 * Exit codes:
 *   0 - no violations
 *   1 - violations found
 *   2 - input error
 */

import fs from "node:fs"
import { createRequire } from "node:module"
import path from "node:path"
import process from "node:process"

function loadTypescriptFromCaller() {
  const callerRequire = createRequire(path.join(process.cwd(), "no-excuse-anchor.cjs"))
  try {
    const typescript = callerRequire("typescript")
    if (typeof typescript.createSourceFile === "function" && typeof typescript.isAsExpression === "function") {
      return typescript
    }
  } catch { // no-excuse-ok: catch
    // fall through to the clear error below
  }
  console.error(
    `error: cannot resolve "typescript" from the caller project (${process.cwd()}). ` +
      "Install TypeScript as a dev dependency with the selected package manager and re-run.",
  )
  process.exit(2)
}

const ts = loadTypescriptFromCaller()

const INCLUDED_EXTENSIONS = new Set([".ts", ".tsx", ".mts", ".cts"])
const IGNORED_DIRECTORIES = new Set([
  ".git", ".next", ".nuxt", ".turbo", ".yarn",
  "coverage", "dist", "build", "node_modules",
])

const OPT_OUT_RE = /\/\/\s*no-excuse-ok:\s*any/
const CATCH_OK_RE = /\/\/\s*no-excuse-ok:\s*catch/

function isIncludedFile(filePath) {
  return INCLUDED_EXTENSIONS.has(path.extname(filePath).toLowerCase())
}

function isDeclarationFile(filePath) {
  return filePath.endsWith(".d.ts") || filePath.endsWith(".d.mts") || filePath.endsWith(".d.cts")
}

function discoverFiles(inputs) {
  const files = []
  for (const input of inputs) {
    const resolved = path.resolve(input)
    if (!fs.existsSync(resolved)) {
      console.error(`Path does not exist: ${resolved}`)
      process.exit(2)
    }
    if (fs.statSync(resolved).isFile()) {
      if (isIncludedFile(resolved) && !isDeclarationFile(resolved)) files.push(resolved)
      continue
    }
    const walk = (dir) => {
      for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        if (entry.isDirectory()) {
          if (!IGNORED_DIRECTORIES.has(entry.name)) walk(path.join(dir, entry.name))
        } else if (isIncludedFile(entry.name) && !isDeclarationFile(entry.name)) {
          files.push(path.join(dir, entry.name))
        }
      }
    }
    walk(resolved)
  }
  return files
}

function getLineText(sourceFile, line) {
  const lineStarts = sourceFile.getLineStarts()
  const start = lineStarts[line]
  const end = line + 1 < lineStarts.length ? lineStarts[line + 1] : sourceFile.getEnd()
  return sourceFile.text.slice(start, end)
}

function analyzeFile(filePath) {
  const source = fs.readFileSync(filePath, "utf8")
  const sourceFile = ts.createSourceFile(filePath, source, ts.ScriptTarget.Latest, true)
  const violations = []

  function pos(node) {
    const { line, character } = sourceFile.getLineAndCharacterOfPosition(node.getStart(sourceFile))
    return { line: line + 1, column: character + 1 }
  }

  function lineHasOptOut(node) {
    const { line } = sourceFile.getLineAndCharacterOfPosition(node.getStart(sourceFile))
    return OPT_OUT_RE.test(getLineText(sourceFile, line))
  }

  function visit(node) {
    if (ts.isAsExpression(node)) {
      const typeText = node.type.getText(sourceFile)
      if (typeText === "any") {
        violations.push({ ruleId: "no-any-assertion", filePath, ...pos(node), message: "`as any` — narrow with type guards or redesign the types" })
      }
      if (typeText === "unknown") {
        violations.push({ ruleId: "no-unknown-assertion", filePath, ...pos(node), message: "`as unknown` — redesign the types" })
      }
    }

    if (ts.isEnumDeclaration(node)) {
      violations.push({ ruleId: "no-enum", filePath, ...pos(node), message: "`enum` — use `as const` object + literal union type" })
    }

    if (ts.isNonNullExpression(node)) {
      violations.push({ ruleId: "no-non-null-assertion", filePath, ...pos(node), message: "`x!` — use narrowing or optional chaining" })
    }

    if (ts.isThrowStatement(node) && node.expression) {
      const expression = node.expression
      if (ts.isStringLiteral(expression) || ts.isNumericLiteral(expression) || ts.isNoSubstitutionTemplateLiteral(expression)) {
        violations.push({ ruleId: "no-throw-literal", filePath, ...pos(node), message: "`throw literal` — throw an Error subclass" })
      }
      if (ts.isTemplateExpression(expression)) {
        violations.push({ ruleId: "no-throw-literal", filePath, ...pos(node), message: "`throw template` — throw an Error subclass" })
      }
    }

    if (ts.isVariableStatement(node)) {
      const hasExport = node.modifiers?.some((modifier) => modifier.kind === ts.SyntaxKind.ExportKeyword)
      if (hasExport && !(node.declarationList.flags & ts.NodeFlags.Const)) {
        violations.push({ ruleId: "no-mutable-export", filePath, ...pos(node), message: "`export let/var` — use `export const`" })
      }
    }

    if (node.kind === ts.SyntaxKind.AnyKeyword && !lineHasOptOut(node)) {
      const parent = node.parent
      if (parent && ts.isAsExpression(parent)) {
        // already handled by no-any-assertion
      } else if (parent && (
        ts.isParameter(parent) ||
        ts.isVariableDeclaration(parent) ||
        ts.isPropertyDeclaration(parent) ||
        ts.isPropertySignature(parent)
      )) {
        violations.push({ ruleId: "no-any-annotation", filePath, ...pos(node), message: "`: any` annotation — use `unknown` and narrow" })
      } else if (parent && (
        ts.isFunctionDeclaration(parent) ||
        ts.isMethodDeclaration(parent) ||
        ts.isArrowFunction(parent) ||
        ts.isFunctionExpression(parent)
      )) {
        violations.push({ ruleId: "no-explicit-any-return", filePath, ...pos(node), message: "`(): any` return — use a specific type" })
      }
    }

    if (ts.isCatchClause(node)) {
      const catchLine = sourceFile.getLineAndCharacterOfPosition(node.getStart(sourceFile)).line
      if (!CATCH_OK_RE.test(getLineText(sourceFile, catchLine))) {
        const statements = node.block.statements
        if (statements.length === 0) {
          violations.push({ ruleId: "empty-catch", filePath, ...pos(node), message: "empty `catch` block — handle, re-throw, or remove the try/catch" })
        } else if (node.variableDeclaration) {
          const variableName = node.variableDeclaration.name.getText(sourceFile)
          const blockText = node.block.getText(sourceFile)
          const hasInstanceof = blockText.includes("instanceof")
          const hasRethrow = blockText.includes(`throw ${variableName}`) || blockText.includes("throw new")
          if (!hasInstanceof && !hasRethrow) {
            violations.push({ ruleId: "catch-without-narrowing", filePath, ...pos(node), message: "`catch` without `instanceof` narrowing or re-throw — narrow the error type or re-throw" })
          }
        }
      }
    }

    ts.forEachChild(node, visit)
  }

  visit(sourceFile)

  const commentRegex = /\/\/\s*@ts-(ignore|expect-error)/g
  let match
  while ((match = commentRegex.exec(source)) !== null) {
    const { line, character } = sourceFile.getLineAndCharacterOfPosition(match.index)
    const kind = match[1]
    violations.push({
      ruleId: kind === "ignore" ? "no-ts-ignore" : "no-ts-expect-error",
      filePath,
      line: line + 1,
      column: character + 1,
      message: `\`@ts-${kind}\` — fix the underlying type`,
    })
  }

  return violations
}

function formatViolation(violation) {
  return `${violation.filePath}:${violation.line}:${violation.column}: [${violation.ruleId}] ${violation.message}`
}

function main() {
  const args = process.argv.slice(2)
  if (args.length === 0) {
    console.error("usage: check-no-excuse-rules.mjs <file-or-dir>...")
    process.exit(2)
  }

  const files = discoverFiles(args)
  if (files.length === 0) {
    console.error("No TypeScript files found.")
    process.exit(2)
  }

  const violations = files.flatMap(analyzeFile)
  if (violations.length === 0) {
    console.log(`No violations in ${files.length} file(s).`)
    return
  }

  for (const violation of violations) {
    console.error(formatViolation(violation))
  }
  console.error(`\n${violations.length} violation(s) in ${files.length} file(s).`)
  process.exit(1)
}

main()
