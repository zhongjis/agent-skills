These upstream defaults apply only when a project has no established choice. Project configuration and language README rules win. TypeScript defaults to pnpm for runtime-neutral greenfield projects and chooses Vitest unless Bun is selected. Rust runs Miri when unsafe, FFI, MaybeUninit, or lock-free code is involved.

## Modern toolchain - the only acceptable setup

| Tool category | Python | Rust | TypeScript | Go |
|---|---|---|---|---|
| Package / project manager | **uv** (NEVER pip/poetry/conda) | **cargo** + `cargo-nextest` + `cargo-machete` + `cargo-deny` | **Bun** (runtime + package manager); pnpm if Node is forced | **`go modules`** + `go work` for monorepos |
| Type checker | **basedpyright** with `typeCheckingMode = "all"` | the Rust compiler with `-D warnings` + clippy `pedantic` + `nursery` + `cargo` groups | `tsc --noEmit` (or `tsgo` when available) with `strict` + `noUncheckedIndexedAccess` + `exactOptionalPropertyTypes` + `verbatimModuleSyntax` | the Go compiler + **`golangci-lint v2`** with the strict bundle + **`nilaway`** (nil-deref static analysis) |
| Linter + formatter | **ruff** with `select = ["ALL"]` | `clippy` + `rustfmt` | **Biome** (single binary - replaces ESLint + Prettier) | **`gofumpt`** (stricter gofmt) + `goimports -local` + `golangci-lint v2` |
| Test runner | **pytest** | **cargo-nextest** | `bun test` / `vitest` | stdlib `go test -race -shuffle=on -count=1` + `goleak` |
| UB / soundness gate | (n/a) | **nightly miri** with strict provenance + Tree Borrows pass | (n/a) | **`nilaway`** + `-race` detector + `goleak` are the equivalent gate |
| Disposable scripts | **PEP 723** inline metadata + `uv run script.py` | **rust-script** with inline `Cargo.toml` block | `bun run script.ts` | `//go:build ignore` + `go run script.go` |
| Bootstrap a new project | `scripts/python/new-project.py` | `scripts/rust/new-project.py` | `scripts/typescript/new-project.ts` | `scripts/go/new-project.py` |
| Pre-commit / CI gate | `ruff check . && basedpyright && pytest` | `cargo clippy --all-targets -- -D warnings && cargo nextest run && cargo test --doc && cargo +nightly miri nextest run` | `bunx biome check . && bunx tsc --noEmit && bun test` | `gofumpt -l . && golangci-lint run ./... && nilaway ./... && go test -race -shuffle=on -count=1 ./...` |

A `tsconfig.json` with `"strict": true` alone is **not** strict. The reference enumerates the additional flags. Same for `pyproject.toml` and `Cargo.toml` - the references contain the canonical full configuration.
