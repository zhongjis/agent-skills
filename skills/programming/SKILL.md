---
name: programming
description: "Use for writing, editing, reviewing, testing, debugging, or upgrading dependencies in Python, Rust, TypeScript, or Go projects; for logging or code-smell review in those projects; and for unsafe Rust, FFI, Miri, gin, sqlc, *.sql beside sqlc.yaml, openapi.yaml beside oapi-codegen.yaml, pgx, Connect-Go, Bubble Tea, CJK IME, exhaustive matching, arenas, allocators, const evaluation, zero-allocation, bitfields, packed layouts, or deterministic cleanup. Covers .py, .pyi, .rs, .ts, .tsx, .mts, .cts, .go, and their project manifests."
---

# Programming

Route work to strict shared policy plus language-owned instructions. Load references before writing or editing code.

## Language gate

Identify every language touched, then read its README:

- Python (`.py`, `.pyi`, `pyproject.toml`) → [`references/python/README.md`](references/python/README.md)
- Rust (`.rs`, `Cargo.toml`) → [`references/rust/README.md`](references/rust/README.md)
- TypeScript (`.ts`, `.tsx`, `.mts`, `.cts`, `package.json`, `tsconfig.json`, `biome.json`) → [`references/typescript/README.md`](references/typescript/README.md)
- Go (`.go`, `go.mod`, `go.sum`, `.golangci.yml`, Go-adjacent `.proto`, `Taskfile.yml`, `buf.yaml`, `sqlc.yaml`, `*.sql` beside `sqlc.yaml`, `oapi-codegen.yaml`, `openapi.yaml` beside `oapi-codegen.yaml`) → [`references/go/README.md`](references/go/README.md)
- Rust touching `unsafe`, raw pointers, `MaybeUninit`, FFI, `unsafe impl Send/Sync`, or custom lock-free primitives → also [`references/rust-ub/README.md`](references/rust-ub/README.md)

Follow each README's on-demand pointers. Existing project manifests, lockfiles, conventions, and stricter local rules win.

## Shared references

- Always apply [`references/shared-policy.md`](references/shared-policy.md): universal type, boundary, TDD, review, and dependency-upgrade rules.
- When adding or changing logs, logger setup, service entrypoints, or boundary error handling, read [`references/logging.md`](references/logging.md). It alone owns cross-language logging policy.
- During design and post-write review, apply [`references/code-smells.md`](references/code-smells.md). It alone owns smell definitions, thresholds, exceptions, and remedies.
