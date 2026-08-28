# programming

## Purpose

- Route Python, Rust, TypeScript, and Go work to strict shared policy and focused language references.

## Ownership

- `SKILL.md` owns model invocation and top-level routing.
- `references/shared-policy.md`, `references/testing.md`, `references/logging.md`, and `references/code-smells.md` own cross-language rules; `shared-policy.md` is the policy summary and `testing.md` owns TDD depth (pyramid, mocking ladder, test anti-patterns, prompt-test).
- Each language `README.md` owns its local index; focused sibling references own branch-specific recipes.
- `scripts/<language>/` owns one canonical no-excuse checker per language and its focused tests.
- `evals/evals.json` owns behavior-focused prompts for language and tooling routing.

## Local Contracts

- Keep `SKILL.md` concise; disclose recipes through branch-specific references.
- Keep one source of truth per policy. Examples must satisfy the owning checker and strict config.
- Preserve existing project conventions before fallback stack defaults.
- Keep high-churn version, date, popularity, and “latest” facts out of durable instructions unless required by a compatibility contract.
- Remove stale files when splitting or replacing a reference; keep every relative link valid.

## Work Guidance

- Split long references at topic boundaries; leave the original path as a concise index when existing pointers depend on it.
- Update the language README whenever adding, removing, or renaming a focused reference.
- Change checker behavior test-first; documentation-only changes use link, fence, and policy-consistency checks.

## Verification

- Run focused checker tests and syntax checks for touched scripts.
- Validate Markdown fences and relative links under `skills/programming/`.
- Validate `evals/evals.json` syntax and preserve routing coverage when changing language or tooling defaults.
- Run `nix eval --file tests/selector.nix` and the full checks listed in `tests/AGENTS.md`.

## Child DOX Index

- No child AGENTS.md files.
