# Core Rust Library Defaults

Part of [libraries.md](libraries.md).

## Async runtime — `tokio`

The default. Use `tokio` for new work. Multi-thread runtime unless you have a measured reason to go single-thread.

```rust
#[tokio::main(flavor = "multi_thread", worker_threads = 8)]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt::init();
    run().await
}
```

Avoid:
- `async-std` — adds a second runtime ecosystem when this stack standardizes on tokio.
- `smol` — fine for embedded-ish niches; outside that, the ecosystem is on tokio.
- Mixing runtimes in one binary. Pick one and stay.

## Errors — `anyhow` (apps) + `thiserror` (libs)

Application boundaries get `anyhow::Error` with `.context("...")` at every layer that adds meaning. Libraries expose `#[derive(thiserror::Error)]` enums with `#[non_exhaustive]`.

```rust
// Application code
use anyhow::Context as _;

pub async fn load_config(path: &Path) -> anyhow::Result<Config> {
    let text = tokio::fs::read_to_string(path)
        .await
        .with_context(|| format!("reading config from {}", path.display()))?;
    let cfg: Config = toml::from_str(&text)
        .with_context(|| format!("parsing config at {}", path.display()))?;
    Ok(cfg)
}

// Library code
#[derive(Debug, thiserror::Error)]
#[non_exhaustive]
pub enum ParseError {
    #[error("expected {expected}, found {found} at position {position}")]
    Mismatch { expected: &'static str, found: String, position: usize },
    #[error("unexpected end of input after {context}")]
    UnexpectedEof { context: &'static str },
    #[error(transparent)]
    Io(#[from] std::io::Error),
}
```

`#[non_exhaustive]` on enums prevents downstream `match` from breaking when you add variants. `#[error(transparent)]` on a wrapper variant forwards Display + cause to the inner error.

## CLI — `clap` with derive

```rust
use clap::{Parser, Subcommand};

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Cli {
    /// Path to the config file
    #[arg(short, long, env = "MYAPP_CONFIG", default_value = "config.toml")]
    config: PathBuf,

    /// Enable verbose output (-v, -vv, -vvv)
    #[arg(short, long, action = clap::ArgAction::Count)]
    verbose: u8,

    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand, Debug)]
enum Command {
    /// Run the server
    Serve {
        #[arg(short, long, default_value_t = 8080)]
        port: u16,
    },
    /// Migrate the database
    Migrate {
        #[arg(long)]
        dry_run: bool,
    },
}
```

Avoid `structopt` (deprecated, merged into clap), `argh` (less ergonomic), `pico-args` (only when binary size matters more than DX).

## Logging — `tracing` + `tracing-subscriber`

Not `log` + `env_logger`. `tracing` supports spans (structured context that follows async tasks) and structured fields - `log` cannot.

```rust
use tracing::{info, instrument, warn, Level};
use tracing_subscriber::{fmt, EnvFilter};

fn init_tracing() {
    let filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new("info,sqlx=warn,hyper=warn"));
    fmt()
        .with_env_filter(filter)
        .with_target(false)
        .with_thread_ids(true)
        .with_line_number(true)
        .compact()
        .init();
}

#[instrument(skip(db), fields(user_id = %user.id))]
async fn process_user(db: &Pool, user: &User) -> anyhow::Result<()> {
    info!("processing user");
    if user.is_banned() {
        warn!(reason = "banned", "skipping");
        return Ok(());
    }
    // ... body ...
    Ok(())
}
```

Replace `println!` with `info!`/`warn!`/`error!`. Replace `eprintln!` with `tracing::error!`.

## Error reporting (binaries) — `color-eyre`

For binary `main()`, hook `color-eyre` to give pretty panics + nice `Result` printing:

```rust
fn main() -> color_eyre::Result<()> {
    color_eyre::install()?;
    tracing_subscriber::fmt::init();
    real_main()
}
```

Library code stays on `anyhow`/`thiserror`. `color-eyre` is purely a display layer for the binary.

## Serialization — `serde` + `serde_json`

The default for any data crossing a process boundary (file, network, IPC, database column).

```rust
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(deny_unknown_fields, rename_all = "snake_case")]
pub struct ApiResponse {
    pub user_id: UserId,
    pub created_at: jiff::Timestamp,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub display_name: Option<String>,
    #[serde(flatten)]
    pub extra: HashMap<String, serde_json::Value>,
}
```

`deny_unknown_fields` catches typos in inputs. `rename_all = "snake_case"` aligns with REST/JSON conventions while keeping idiomatic Rust field names. `#[serde(flatten)]` for forward-compatible extra fields.

Alternatives:
- `serde_yaml` (YAML — note: YAML's "deserialize anything" surface is a security trap; prefer JSON/TOML where possible)
- `toml` (config files)
- `rmp-serde` (MessagePack — binary, fast)
- `ciborium` (CBOR)
- `bincode 2` (binary, smaller; no serde required in v2 but interop fine)

## HTTP client — `reqwest`

```rust
let client = reqwest::Client::builder()
    .timeout(std::time::Duration::from_secs(30))
    .user_agent(concat!(env!("CARGO_PKG_NAME"), "/", env!("CARGO_PKG_VERSION")))
    .https_only(true)
    .pool_max_idle_per_host(8)
    .build()?;

#[derive(serde::Deserialize)]
struct Repo { full_name: String, stargazers_count: u64 }

let repo: Repo = client
    .get("https://api.github.com/repos/rust-lang/rust")
    .send().await?
    .error_for_status()?
    .json().await?;
```

`error_for_status()?` turns 4xx/5xx into `Err`. Always include a User-Agent. `https_only(true)` is a soundness toggle - prevents accidental http:// downgrade.

## Web framework — `axum`

```rust
use axum::{Router, routing::get, extract::State, response::Json};
use std::sync::Arc;

#[derive(Clone)]
struct AppState { db: sqlx::PgPool }

async fn health(State(state): State<Arc<AppState>>) -> Json<serde_json::Value> {
    let ok = sqlx::query_scalar!("SELECT 1::int4").fetch_one(&state.db).await.is_ok();
    Json(serde_json::json!({ "ok": ok }))
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt::init();
    let state = Arc::new(AppState { db: sqlx::PgPool::connect(&env_db()).await? });
    let app = Router::new()
        .route("/health", get(health))
        .with_state(state)
        .layer(tower_http::trace::TraceLayer::new_for_http())
        .layer(tower_http::compression::CompressionLayer::new());
    let listener = tokio::net::TcpListener::bind("0.0.0.0:8080").await?;
    axum::serve(listener, app).await?;
    Ok(())
}
```

Pair `axum` with `tower-http` for middleware (trace, compression, CORS, timeout, request-id). Choose another framework only when project constraints require its runtime or API model.

## Database — `sqlx` (compile-time checked SQL)

```rust
use sqlx::PgPool;

#[derive(Debug, sqlx::FromRow)]
pub struct User { pub id: uuid::Uuid, pub email: String, pub created_at: jiff::Timestamp }

pub async fn find_user(pool: &PgPool, email: &str) -> Result<Option<User>, sqlx::Error> {
    sqlx::query_as!(
        User,
        r#"SELECT id, email, created_at as "created_at: jiff::Timestamp"
           FROM users WHERE email = $1"#,
        email
    )
    .fetch_optional(pool)
    .await
}
```

`query_as!` checks the SQL against the live database at compile time. To work without a live DB during builds, generate offline metadata: `cargo sqlx prepare`. Commit the resulting `.sqlx/` directory.

Avoid `diesel` (sync-first, heavy DSL), raw `tokio-postgres` (loses type checks), `sea-orm` (more magic, less control).

For migrations: `sqlx migrate add <name>` + `sqlx::migrate!("./migrations").run(&pool).await?`.
