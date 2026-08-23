# Rust Library Decision Tree

Part of [libraries.md](libraries.md).

## Decision tree

```
Need to ship the thing?
├── HTTP server         → axum + sqlx + tracing + jiff + tokio
├── HTTP client         → reqwest (+ tokio)
├── CLI                 → clap + color-eyre + tracing + indicatif (progress) + dialoguer (prompts)
├── TUI                 → ratatui + crossterm
├── Background worker   → tokio + ETL → polars + duckdb
├── Game / graphics     → wgpu + winit + euclid (or bevy if you want the engine)
├── WASM front-end      → leptos (or dioxus / yew) + wasm-bindgen + gloo
├── Embedded            → embassy (async on bare metal)
├── FFI to C / Python   → cxx (C++) / pyo3 (Python) / cbindgen (header gen)
└── Just a script       → rust-script (see one-liners.md)
```

When in doubt, choose a compatible release from crates.io, then check:
1. Is it maintained? (`cargo deny check` will scream if it's yanked or unmaintained)
2. Does it have `serde` feature? (boundary types should always serde)
3. Does it have `tokio` integration? (avoid runtime mixing)
4. Is it on `tokio::io::AsyncRead`/`AsyncWrite` (the std for async I/O)?
5. Are there safety-critical `unsafe` regions? If yes, has the author shipped miri proofs?
