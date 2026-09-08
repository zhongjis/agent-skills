# Axum Routing and Runtime

Part of [axum-stack.md](axum-stack.md).

## Route handler

```rust
// src/routes/users.rs
use axum::{
    extract::{Path, State},
    Json,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use validator::Validate;

use crate::{error::{AppError, AppResult}, state::AppState};

#[derive(Debug, Deserialize, Validate)]
pub struct CreateUser {
    #[validate(email)]
    pub email: String,
    #[validate(length(min = 1, max = 100))]
    pub name: String,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct User {
    pub id: Uuid,
    pub email: String,
    pub name: String,
    pub created_at: jiff::Timestamp,
}

#[tracing::instrument(skip(state, body))]
pub async fn create_user(
    State(state): State<AppState>,
    Json(body): Json<CreateUser>,
) -> AppResult<(axum::http::StatusCode, Json<User>)> {
    body.validate().map_err(|e| AppError::Validation(e.to_string()))?;

    let id = Uuid::now_v7();
    let user = sqlx::query_as!(
        User,
        r#"INSERT INTO users (id, email, name, created_at)
           VALUES ($1, $2, $3, NOW())
           RETURNING id, email, name, created_at as "created_at: jiff::Timestamp""#,
        id, body.email, body.name
    )
    .fetch_one(&state.db)
    .await
    .map_err(|e| match &e {
        sqlx::Error::Database(db) if db.code().as_deref() == Some("23505") =>
            AppError::Conflict("email already exists".into()),
        _ => AppError::Database(e),
    })?;

    Ok((axum::http::StatusCode::CREATED, Json(user)))
}

#[tracing::instrument(skip(state))]
pub async fn get_user(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> AppResult<Json<User>> {
    sqlx::query_as!(
        User,
        r#"SELECT id, email, name, created_at as "created_at: jiff::Timestamp"
           FROM users WHERE id = $1"#,
        id
    )
    .fetch_optional(&state.db)
    .await?
    .map(Json)
    .ok_or(AppError::NotFound)
}
```

## Router assembly

```rust
// src/routes/mod.rs
use axum::{routing::{get, post}, Router};
use tower_http::{
    compression::CompressionLayer,
    cors::CorsLayer,
    request_id::{MakeRequestUuid, PropagateRequestIdLayer, SetRequestIdLayer},
    sensitive_headers::SetSensitiveHeadersLayer,
    timeout::TimeoutLayer,
    trace::{DefaultMakeSpan, DefaultOnResponse, TraceLayer},
};
use std::time::Duration;
use crate::state::AppState;

mod health;
mod users;

pub fn router(state: AppState) -> Router {
    let api = Router::new()
        .route("/health", get(health::handler))
        .route("/users", post(users::create_user))
        .route("/users/:id", get(users::get_user))
        .with_state(state);

    Router::new()
        .nest("/api/v1", api)
        .layer(
            tower::ServiceBuilder::new()
                .layer(SetSensitiveHeadersLayer::new([
                    axum::http::header::AUTHORIZATION,
                    axum::http::header::COOKIE,
                ]))
                .layer(SetRequestIdLayer::x_request_id(MakeRequestUuid))
                .layer(
                    TraceLayer::new_for_http()
                        .make_span_with(DefaultMakeSpan::new().include_headers(false))
                        .on_response(DefaultOnResponse::new().latency_unit(tower_http::LatencyUnit::Millis)),
                )
                .layer(PropagateRequestIdLayer::x_request_id())
                .layer(TimeoutLayer::new(Duration::from_secs(30)))
                .layer(CompressionLayer::new())
                .layer(CorsLayer::permissive()), // tighten in production
        )
}
```

Order matters: outermost layer wraps the request first. Trace before timeout so timeouts get logged. Compression after trace so trace sees the original body size.

## Main + graceful shutdown

```rust
// src/main.rs
use my_app::{config::Settings, routes, state::AppState};

#[tokio::main]
async fn main() -> color_eyre::Result<()> {
    color_eyre::install()?;
    init_tracing();

    let config = Settings::load()?;
    let state = AppState::new(config.clone()).await?;
    let app = routes::router(state);

    let listener = tokio::net::TcpListener::bind(&config.bind).await?;
    tracing::info!(addr = %config.bind, "listening");

    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await?;
    Ok(())
}

fn init_tracing() {
    use tracing_subscriber::{fmt, EnvFilter};
    let filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new("info,sqlx=warn,hyper=warn,tower_http=info"));
    fmt().with_env_filter(filter).with_target(false).json().init();
}

async fn shutdown_signal() {
    let ctrl_c = async { tokio::signal::ctrl_c().await.expect("ctrl_c handler"); };
    #[cfg(unix)]
    let terminate = async {
        tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
            .expect("signal handler").recv().await;
    };
    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! { _ = ctrl_c => {}, _ = terminate => {} }
    tracing::info!("shutting down");
}
```
