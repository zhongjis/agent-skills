# Axum Service Operations

Part of [axum-stack.md](axum-stack.md).

## Middleware: bearer auth example

```rust
// src/middleware/auth.rs
use axum::{
    extract::{Request, State},
    http::header::AUTHORIZATION,
    middleware::Next,
    response::Response,
};
use crate::{error::AppError, state::AppState};

#[derive(Clone, Debug)]
pub struct AuthUser { pub id: uuid::Uuid }

pub async fn require_auth(
    State(state): State<AppState>,
    mut request: Request,
    next: Next,
) -> Result<Response, AppError> {
    let token = request.headers()
        .get(AUTHORIZATION)
        .and_then(|v| v.to_str().ok())
        .and_then(|s| s.strip_prefix("Bearer "))
        .ok_or(AppError::Unauthorized)?;

    let claims = verify_jwt(token, &state.config.jwt_secret)?;
    request.extensions_mut().insert(AuthUser { id: claims.sub });
    Ok(next.run(request).await)
}
```

Apply with `.route_layer(middleware::from_fn_with_state(state.clone(), require_auth))` on the subroutes that need it.

## Testing handlers

```rust
// tests/users.rs
#[tokio::test]
async fn creates_user() {
    let pool = test_db().await;          // helper that spins up a transactional DB
    let state = AppState::new_test(pool).await.unwrap();
    let app = my_app::routes::router(state);

    let request = axum::http::Request::builder()
        .uri("/api/v1/users")
        .method("POST")
        .header("content-type", "application/json")
        .body(axum::body::Body::from(
            serde_json::to_vec(&serde_json::json!({"email": "a@b.com", "name": "A"})).unwrap()
        )).unwrap();

    let response = tower::ServiceExt::oneshot(app, request).await.unwrap();
    assert_eq!(response.status(), 201);
    let bytes = axum::body::to_bytes(response.into_body(), 1 << 20).await.unwrap();
    let user: serde_json::Value = serde_json::from_slice(&bytes).unwrap();
    assert_eq!(user["email"], "a@b.com");
}
```

`tower::ServiceExt::oneshot` calls the router directly without binding a socket. Tests run in parallel without port collisions.

## Config

```rust
// src/config.rs
use secrecy::{Secret, ExposeSecret};

#[derive(Debug, Clone, serde::Deserialize)]
pub struct Settings {
    pub bind: String,
    pub db: Database,
    pub jwt_secret: Secret<String>,
}

#[derive(Debug, Clone, serde::Deserialize)]
pub struct Database {
    pub url: Secret<String>,
    pub max_connections: u32,
}

impl Settings {
    pub fn load() -> anyhow::Result<Self> {
        let cfg = config::Config::builder()
            .add_source(config::File::with_name("config/default").required(false))
            .add_source(config::File::with_name(&format!(
                "config/{}", std::env::var("APP_ENV").unwrap_or_else(|_| "dev".into())
            )).required(false))
            .add_source(config::Environment::with_prefix("APP").separator("__"))
            .build()?;
        Ok(cfg.try_deserialize()?)
    }
}
```

`Secret<T>` from the `secrecy` crate hides the value in `Debug`/`Display` to prevent accidental log leakage. Access via `.expose_secret()` only where needed.

## OpenAPI (optional)

Add `utoipa` derive macros on your DTOs and handlers, mount Swagger UI at `/swagger-ui`:

```rust
use utoipa::OpenApi;
use utoipa_axum::router::OpenApiRouter;
use utoipa_swagger_ui::SwaggerUi;

#[derive(OpenApi)]
#[openapi(
    paths(routes::users::create_user, routes::users::get_user),
    components(schemas(routes::users::User, routes::users::CreateUser))
)]
struct ApiDoc;

let (router, api) = OpenApiRouter::with_openapi(ApiDoc::openapi())
    .routes(utoipa_axum::routes!(routes::users::create_user, routes::users::get_user))
    .split_for_parts();

let app = router.merge(SwaggerUi::new("/swagger-ui").url("/api-docs/openapi.json", api));
```

## Production checklist

- Bind to `0.0.0.0` in containers, `127.0.0.1` for local-only services.
- Set `RUST_LOG=info,sqlx=warn` (or use `EnvFilter` defaults as shown).
- Send logs to stdout in JSON. Ingest via Vector / Fluent Bit / Loki.
- Run migrations on startup (`sqlx::migrate!` block). Fail fast on schema mismatch.
- Health endpoint **must hit the DB** (so load balancers know if the pool is dead).
- Add `tower::limit::RateLimitLayer` or token-bucket middleware for public endpoints.
- Set `tower_http::limit::RequestBodyLimitLayer` to bound request size.
- Compress with brotli + gzip via `CompressionLayer`.
- Tighten CORS, do not ship `CorsLayer::permissive()` to production.
- Strip sensitive headers from traces via `SetSensitiveHeadersLayer`.
- Set up SIGTERM-driven `with_graceful_shutdown` so deploys roll without dropping requests.
- Containerize with `cargo chef` for incremental Docker builds.

## Common mistakes

1. **Forgetting `error_for_status()?` on outbound `reqwest`** — 4xx silently succeeds.
2. **Returning `Result<T, sqlx::Error>` from handlers** — leak DB details to clients. Always go through `AppError`.
3. **`Json<T>` extractor before validation** — invalid JSON returns axum's default 422 with no body shape. Wrap in a `ValidatedJson<T>` extractor that runs `validator` and returns `AppError`.
4. **Holding DB connections across `.await` on slow external calls** — exhausts the pool. Acquire late, release early.
5. **Skipping `tracing::instrument`** on handlers — losing per-request span correlation.
6. **No `RequestBodyLimitLayer`** — DoS surface. Default axum has no limit.
