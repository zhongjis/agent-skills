# Slop Categories — What Counts, KEEP vs REFACTOR

The ten categories the cleanup pass evaluates. The first three are stylistic, the next three structural, the next two about hidden cost, then behavior coverage, then module size. Each category lists what to remove, what to KEEP, and how to REFACTOR. The [detector table](#concrete-slop-patterns-detector-reference) at the end maps concrete, per-language tells to these categories.

## Stylistic

### 1. Obvious comments

Comments restating code, trivial docstrings, section dividers, commented-out code, vague TODOs/Notes.

- KEEP: comments explaining WHY (business logic, edge cases, workarounds), ticket links, regex/algorithm explanations, BDD markers (`# given`, `# when`, `# then`).

### 2. Over-defensive code

Null checks for guaranteed values, try/except around code that cannot raise, isinstance checks for statically typed params, defaults for required params, backward-compat shims, validation duplicated at multiple layers, and **broad exception catching** (`except Exception`/`except BaseException`; empty `catch {}` or `catch (e) { log(e) }` without narrowing).

- KEEP: validation at system boundaries (user input, external APIs), I/O error handling, nullable DB fields. A top-level boundary catch-all (CLI `main()`, HTTP handler) with explicit logging + re-raise is acceptable.
- REFACTOR: `except Exception` → the specific exception you expect. Empty `catch {}` → narrow with `instanceof` or re-throw. `catch (e) { log(e) }` → narrow, handle known cases, re-throw unknown.
- PROOF REQUIRED: before deleting any guard at a trust boundary, Phase 2 must include an **adversarial** regression (malformed or hostile input) that fails if the guard is removed. No adversarial test → the guard stays. A guard with no proof of redundancy is load-bearing.

### 3. Excessive complexity

Deep nesting (>3 levels), nested ternaries, boolean expressions combining 4+ predicates, long parameter lists, god functions (>50 lines doing many things), overly clever one-liners, `if/elif/else` chains for type/enum/literal discrimination (want `match/case` + `assert_never`), `object` used as a type annotation (want `Protocol`, `TypeVar`, or an explicit union).

- KEEP: established complexity patterns in this codebase; performance-critical hot paths that intentionally use a complex idiom; `if/else` for boolean conditions and range checks (not variant discrimination).
- REFACTOR: nested if-chains → guard clauses / early returns. Complex ternaries → explicit if/else. isinstance/enum if/elif chains → `match/case` with `assert_never` on the wildcard. `object` annotations → `Protocol`, `TypeVar`, or a union. Long parameter lists → group 4+ independent args into a typed struct/dataclass/object with a domain name.

## Structural

### 4. Needless abstraction

Pass-through wrappers, single-use helpers, speculative indirection ("we might need this later"), interfaces with one implementer that adds no testability win, factory functions that only call a constructor.

- KEEP: abstractions that provide a real seam (testability, multiple implementers, framework-required boundaries).

### 5. Boundary violations

Wrong-layer imports (UI importing a DB driver), leaky responsibilities (a handler doing service-layer business logic), hidden coupling (module A reads module B's private state), side effects in pure-named functions.

- KEEP: pragmatic short-circuits already established as a pattern here. Flag for human judgment if unsure.

### 6. Dead code

Unused imports, unused private functions/methods, unreachable branches, stale feature flags, debug leftovers (`console.log`, `print(...)`, `dbg!`), removed-but-still-referenced code.

- KEEP: code referenced via reflection, dynamic dispatch, or string lookup; a feature-flag rollback path (verify with the user).

## Hidden cost

### 7. Duplication

Copy-pasted branches with trivial differences, redundant helpers doing the same thing in two places, repeated literal/magic-number sequences.

- KEEP: incidental duplication (two pieces that look similar but serve intents that could diverge). Prefer leaving them separate over forcing a premature shared abstraction.

### 8. Performance equivalences

Behavior-preserving optimizations that are provably equivalent but cheaper:

- O(n²) → O(n) when correctness is preserved (set lookup vs list scan).
- Repeated computation inside a loop → hoist outside.
- Eager intermediate collection iterated once → generator.
- String concatenation in a loop → `join` / builder.
- Redundant DB/API calls in a loop → batch.
- `.length` / `len()` recomputed inside a loop → cache.

**Hard rule:** apply only when equivalence is obvious. Do NOT change algorithms with subtle correctness implications, and do NOT micro-optimize hot paths without a benchmark. In doubt, SKIP.

## Behavior coverage

### 9. Missing tests

Behavior in changed files not locked by any regression test. The fix is not to remove code but to ADD the narrowest test that pins the behavior. EXCEPTION: a PROSE file has no behavioral seam — do not add a text/word-count pin; cover only a machine-consumed value (a parsed field, a sentinel a runtime greps, a doc JSON sample through its real validator) or leave it to review.

## Module size

### 10. Oversized modules

Any source file exceeding **250 pure LOC** (non-blank, non-comment). An architectural defect, not a style preference. Measure:

```bash
awk '!/^[[:space:]]*$/ && !/^[[:space:]]*(#|\/\/)/' <file> | wc -l
```

When found, execute a full modular refactoring:

1. Measure pure LOC across scope with the one-liner above to list every violation.
2. For each oversized file, identify distinct responsibilities (single-responsibility principle).
3. Plan the split: name each new file after the concept it owns (never `utils.py`, `helpers.py`, `common.py`, `part_1.py`).
4. Present the split plan to the user before executing.
5. Extract into clean modules with re-exports ONLY in the barrel (`__init__.py`, `mod.rs`, `index.ts`) — no logic there.
6. Verify: re-measure — every file ≤250 pure LOC. Run tests, typecheck, lint.

**Forbidden escapes:** counting blanks/comments toward budget; splitting by token count (`foo_1.py`); catch-all dump files; "it's generated" (valid only in a build-output directory); "230 LOC, close enough" (a file about to grow is already over).

KEEP: a genuinely self-contained single-responsibility script. Opt out with `// allow: SIZE_OK — <reason>` in the first five lines; the marker without a justifying reason is itself slop.

## Overlap with the programming skill's code smells

When this skill runs inside a repository that also uses the `programming` skill, its `references/code-smells.md` is the canonical owner of the structural-smell thresholds (file size, parameter count, redundant verification after a destructive action, negative-form names). Defer to it there; the numbers above are the standalone defaults and are chosen to match it (250 pure LOC; group parameters at 4+).

## Concrete slop patterns (detector reference)

Per-language tells that map to the categories above, adapted from the `aislop` scanner's rule set. Use them as a checklist of what to look for; the category's KEEP/REFACTOR rules still govern whether a given hit is real slop or an intentional pattern.

| Pattern / tell | Category |
|---|---|
| Comment restating code (`// Import React`, `// Return the value`) | 1 Obvious comments |
| Decorative separators, phase/section headers, JSDoc preamble without meaningful tags, prose restatement | 1 Obvious comments |
| Comment about implementation phase, agent behavior, or generated-code process | 1 Obvious comments |
| Empty catch, or catch that only logs (JS/TS/Python/Go/Ruby/Java/C#) | 2 Over-defensive |
| Catch that logs without the caught error, then continues | 2 Over-defensive |
| Catch that only rethrows the same error without context/cleanup/recovery | 2 Over-defensive |
| Python `except:` / broad `except Exception` with pass-style body | 2 Over-defensive |
| C# `catch (Exception)` (non-empty, non-rethrow); `#pragma warning disable` / `[SuppressMessage]` without justification | 2 Over-defensive |
| TS `as any`; `as unknown as X`; `@ts-ignore` / `@ts-expect-error`; C# null-forgiving `!` | 2 Over-defensive |
| JS/TS fallback turning missing counts / failed diagnostics / impossible states into safe-looking values | 2 Over-defensive |
| TS primitive param re-coerced with `String()`/`Number()`/`Boolean()` | 2 / 6 |
| Python `for i in range(len(items))` (want `enumerate`) | 3 Excessive complexity |
| Repeated equality/`isinstance` ladders (want a table/handler map) | 3 Excessive complexity |
| C# chain of 4+ if/else-if against constants (a `switch` in disguise); index `for` over `.Length`/`.Count` (want `foreach`) | 3 Excessive complexity |
| Function that only forwards its own parameters unchanged | 4 Needless abstraction |
| Generic AI names (`helper_1`, `data2`, `temp1`) | 4 Needless abstraction |
| Unused import; duplicate import from the same module; unused CSS class; unused top-level declaration | 6 Dead code |
| `console.log`/`debug`/`info`, Python `print(...)`, C# `Console.*`/`Debug.*`/`Trace.*`, C++ `std::cout`/`std::cerr` left in library code | 6 Dead code |
| Code after `return`/`throw`; `if (true)` / `if (false)` / `if (0)`; empty function body | 6 Dead code |
| Untracked TODO/FIXME/HACK (a TODO linking a tracking issue is spared) | 6 Dead code |
| Stub bodies: C# `throw new NotImplementedException()`, C++ `logic_error("not implemented")` / `assert(false ...)`, Rust `todo!()` | 6 Dead code |
| Rust `.unwrap()` in production; Go `panic(...)` in non-main library code | 6 Dead code |
| Python mutable default arg (`[]`, `{}`, `set()`) shared across calls | 6 Dead code |
| Duplicated implementation block; repeated long call chain on the same receiver; exported TS type repeated with same name/shape across files | 7 Duplication |
| C# string built with `+=` in a loop (want `StringBuilder`); C++ `<< std::endl` per call (want `'\n'`) | 8 Performance |
| C# `.Count() > 0` / `== 0` enumerating a whole sequence (want `.Any()`) | 8 Performance |
| Hardcoded environment-specific URL or provider/project ID (want env/config) | 5 Boundary violations |
| Import of a JS/TS package not declared in the manifest (hallucinated import) | 6 Dead code |
| Assertion comparing equal fixed literals; standalone Python `assert True` | 9 Missing tests (tautological) |

### Optional deterministic pre-pass

If the project already ships the `aislop` CLI (or you can run it), a deterministic scan (`aislop`) is a fast way to surface the mechanical tells above before the judgment pass; it also auto-fixes purely mechanical findings (formatting, unused imports/dead code) with `aislop fix`. It never replaces Phase 2 behavior locking or the KEEP-rule judgment — it only narrows where to look. To keep an intentional pattern from re-flagging, use its inline suppression `// aislop-ignore-next-line <rule> -- reason` or per-rule severity in `.aislop/config.yml`.
