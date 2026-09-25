These upstream defaults apply only when a project has no established choice. Project configuration and language README rules win. TypeScript defaults to pnpm for runtime-neutral greenfield projects and chooses Vitest unless Bun is selected. Rust runs Miri when unsafe, FFI, MaybeUninit, or lock-free code is involved.

## Modern ecosystem - canonical libraries (2026)

Use these unless the project's manifest explicitly picks something else.

| Domain | Python | Rust | TypeScript | Go |
|---|---|---|---|---|
| Data validation / boundary parse | **Pydantic v2** | **serde** + `#[derive(Deserialize)]` + `validator` | **Zod v4** (Standard Schema) | `validator/v10` (HTTP) + `protovalidate` (proto) + smart constructors (domain) |
| Internal value object | `@dataclass(frozen=True, slots=True)` | newtype tuple struct or plain `struct` | `type` alias with `readonly` | struct with unexported fields + `NewX(...)` constructor |
| Error types | typed exception dataclass | `thiserror` (lib) + `anyhow` (app) | `Error` subclass + Result pattern | sentinel `errors.New` + typed `*XError` struct + `%w` wrap |
| HTTP client | [`httpx2`](https://github.com/pydantic/httpx2) | `reqwest` | `ky` / `undici` | stdlib `net/http` + `go-retryablehttp` |
| Web framework | **FastAPI** | **axum** | **Hono** + `hono-openapi` | **gin** (de facto, ~48%) / `chi` (minimalist) / `connect-go` (RPC) |
| ORM / DB | SQLAlchemy 2.x async + `asyncpg` | `sqlx` (compile-time checked) | **Drizzle** | **sqlc** (codegen from `.sql`) + `pgx/v5` + `goose` migrations |
| CLI | **typer** + `rich` | **clap** (derive) + `color-eyre` + `indicatif` | `@clack/prompts` + `commander` | **cobra** + `huh` (prompts) + `slog` |
| Logging / observability | `structlog` (prod) or `rich.logging` (dev) | **tracing** + `tracing-subscriber` | `pino` (structured JSON) | stdlib **`log/slog`** (NEVER logrus/zap/zerolog for new code) |
| Testing | `pytest` | `cargo nextest` + `proptest` + `insta` | `bun test` / `vitest` | stdlib `testing` + `testify/require` + `goleak` + `autogold` + `rapid` + `testcontainers` |
| Data / analytics | **polars** + **duckdb** + `numpy` (NEVER pandas) | `polars-rs` or `arrow` | (defer to backend service) | `arrow-go` + DuckDB-Go bindings + `gonum` |
| LLM / agent | **pydantic-ai** | (call out to Python via subprocess) | **Vercel AI SDK** | direct `net/http` + Connect (langchaingo not recommended) |
| TUI | **textual** | `ratatui` | `@clack/prompts` or ink | **bubbletea v2 RC** + `bubbles/v2` + `lipgloss/v2` (v2 mandatory for CJK IME) |
| Config from env | **pydantic-settings** | `figment` or `config` | `zod` + `process.env` | `caarlos0/env/v11` (struct-tag env) |

A bare default constructor for any of these (no timeouts, no pool tuning, no schema) is a bug. See the per-language reference for the canonical production defaults.
