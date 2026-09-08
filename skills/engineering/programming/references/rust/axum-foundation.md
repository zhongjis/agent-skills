# Axum Service Foundation

Part of [axum-stack.md](axum-stack.md).

## Cargo.toml dependencies

```toml
[dependencies]
axum = { version = "0.8", features = ["macros", "tracing", "ws", "multipart"] }
tokio = { version = "1", features = ["full"] }
tower = "0.5"
tower-http = { version = "0.6", features = [
    "trace", "compression-gzip", "compression-br",
    "timeout", "cors", "request-id", "sensitive-headers",
    "limit", "set-header",
] }

# Errors / observability
anyhow = "1"
thiserror = "2"
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter", "json"] }
color-eyre = "0.6"

# Database
sqlx = { version = "0.8", features = [
    "runtime-tokio-rustls", "postgres", "uuid", "macros",
    "migrate", "json",
] }

# Serialization / validation
serde = { version = "1", features = ["derive"] }
serde_json = "1"
validator = { version = "0.18", features = ["derive"] }

# Types
uuid = { version = "1", features = ["v4", "v7", "serde"] }
jiff = { version = "0.1", features = ["serde"] }

# Config
config = { version = "0.14", features = ["toml", "yaml"] }
secrecy = { version = "0.10", features = ["serde"] }

# OpenAPI (optional but recommended)
utoipa = { version = "5", features = ["axum_extras", "uuid", "chrono"] }
utoipa-axum = "0.1"
utoipa-swagger-ui = { version = "8", features = ["axum"] }
```

## Project structure

```
src/
  main.rs            # binary entry
  lib.rs             # re-exports + app builder
  config.rs          # Settings type + loader
  state.rs           # AppState (shared via Arc)
  routes/
    mod.rs           # Router::new() composition
    health.rs
    users.rs
  middleware/
    mod.rs
    auth.rs
    request_id.rs
  models/
    mod.rs
    user.rs
  error.rs           # AppError + IntoResponse impl
  db/
    mod.rs
    migrations/
migrations/          # sqlx migrations
```

## Error type

```rust
// src/error.rs
use axum::{http::StatusCode, response::{IntoResponse, Response}, Json};
use serde_json::json;

#[derive(Debug, thiserror::Error)]
pub enum AppError {
    #[error("not found")]
    NotFound,
    #[error("unauthorized")]
    Unauthorized,
    #[error("validation: {0}")]
    Validation(String),
    #[error("conflict: {0}")]
    Conflict(String),
    #[error("internal")]
    Internal(#[from] anyhow::Error),
    #[error("database")]
    Database(#[from] sqlx::Error),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, code, message) = match &self {
            AppError::NotFound => (StatusCode::NOT_FOUND, "not_found", self.to_string()),
            AppError::Unauthorized => (StatusCode::UNAUTHORIZED, "unauthorized", "unauthorized".into()),
            AppError::Validation(m) => (StatusCode::UNPROCESSABLE_ENTITY, "validation", m.clone()),
            AppError::Conflict(m) => (StatusCode::CONFLICT, "conflict", m.clone()),
            AppError::Database(e) => {
                tracing::error!(error = ?e, "database error");
                (StatusCode::INTERNAL_SERVER_ERROR, "database", "internal".into())
            }
            AppError::Internal(e) => {
                tracing::error!(error = ?e, "internal error");
                (StatusCode::INTERNAL_SERVER_ERROR, "internal", "internal".into())
            }
        };
        (status, Json(json!({"error": {"code": code, "message": message}}))).into_response()
    }
}

pub type AppResult<T> = std::result::Result<T, AppError>;
```

Pattern: business errors return `AppResult<T>`; the `IntoResponse` impl translates them to HTTP. `sqlx::Error` and `anyhow::Error` auto-convert via `From`. Internal-bucket errors are logged but never leak their `Debug` representation to clients.

## AppState

```rust
// src/state.rs
use std::sync::Arc;
use sqlx::PgPool;

#[derive(Clone)]
pub struct AppState {
    pub db: PgPool,
    pub config: Arc<crate::config::Settings>,
    pub http: reqwest::Client,
}

impl AppState {
    pub async fn new(config: crate::config::Settings) -> anyhow::Result<Self> {
        let db = sqlx::postgres::PgPoolOptions::new()
            .max_connections(config.db.max_connections)
            .acquire_timeout(std::time::Duration::from_secs(3))
            .connect(config.db.url.expose_secret())
            .await?;
        sqlx::migrate!("./migrations").run(&db).await?;
        let http = reqwest::Client::builder()
            .timeout(std::time::Duration::from_secs(15))
            .user_agent(concat!(env!("CARGO_PKG_NAME"), "/", env!("CARGO_PKG_VERSION")))
            .build()?;
        Ok(Self { db, config: Arc::new(config), http })
    }
}
```
