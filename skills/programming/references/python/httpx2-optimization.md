# httpx2 — Production Defaults

> **Source**: [pydantic/httpx2](https://github.com/pydantic/httpx2).
>
> Preserve an existing project's HTTP client and factory. Use this `httpx2` baseline only when the project has no established client. Original `httpx` remains a narrow exception for framework test or transport APIs that require its types.

---

## 1. Installation for a new httpx2 client

```toml
# pyproject.toml
dependencies = [
    "httpx2[http2,brotli,zstd]",
]
```

| Extra | What it enables | Why it's mandatory |
|-------|----------------|--------------------|
| `http2` | HTTP/2 multiplexing via `h2` | Single TCP connection handles concurrent requests; eliminates head-of-line blocking |
| `brotli` | Brotli content decoding (`br`) | ~20% smaller payloads than gzip for text/JSON |
| `zstd` | Zstandard content decoding | Faster decompression than brotli at similar ratios; stdlib in Python ≥ 3.14 |
| `socks` | SOCKS5 proxy support via `socksio` | Install only if you route through SOCKS proxies |

For a new `httpx2` client, install all three core extras. Preserve an existing project's dependency choices.

---

## 2. Fallback defaults

These are baseline values for a new project. Tune them from measured workload needs; do not replace an existing project's settings without evidence.

```python
import socket
import httpx2

# ── These are the STANDARD values. Use them verbatim. ──

LIMITS = httpx2.Limits(
    max_connections=200,           # library default 100 is too conservative
    max_keepalive_connections=40,  # library default 20 wastes reconnects
    keepalive_expiry=30.0,         # library default 5s kills warm connections too fast
)

TIMEOUT = httpx2.Timeout(
    connect=5.0,    # TCP + TLS handshake budget
    read=30.0,      # time to receive a response chunk
    write=10.0,     # time to send a request chunk
    pool=10.0,      # time to acquire a connection from pool
)

SOCKET_OPTIONS: list[tuple[int, int, int]] = [
    (socket.IPPROTO_TCP, socket.TCP_NODELAY, 1),   # disable Nagle — no 40ms delay
]
```

### Why each knob is set this way

| Setting | Library default | Our default | Why |
|---------|----------------|-------------|-----|
| `http2` | `False` | **`True`** | HTTP/2 multiplexing is strictly superior for any modern API |
| `max_connections` | `100` | `200` | Headroom for fan-out; prevents pool exhaustion under load |
| `max_keepalive_connections` | `20` | `40` | Keeps warm connections alive; fewer TLS handshakes |
| `keepalive_expiry` | `5.0s` | `30.0s` | 5s is too aggressive — kills connections between burst requests |
| `Timeout(5.0)` uniform | `5.0` all | Split | Uniform 5s is too tight for reads, too loose for connects |
| `read` timeout | `5.0` | `30.0` | Slow APIs and streaming need breathing room |
| `pool` timeout | `5.0` | `10.0` | Explicit — hitting this means `max_connections` needs raising |
| `TCP_NODELAY` | off | **on** | Eliminates Nagle's 40ms coalescing delay for small payloads |
| `retries` | `0` | `3` | Retries on `ConnectError`/`ConnectTimeout` only — safe and resilient |
| `follow_redirects` | `False` | **`True`** | Most APIs redirect; failing on 3xx is wrong default behavior |

---

## 3. Factory functions

Copy this into a new project that has no HTTP factory. Keep client construction centralized.

```python
"""Central httpx2 client factory."""

from __future__ import annotations

import socket

import httpx2

_LIMITS = httpx2.Limits(
    max_connections=200,
    max_keepalive_connections=40,
    keepalive_expiry=30.0,
)

_TIMEOUT = httpx2.Timeout(
    connect=5.0,
    read=30.0,
    write=10.0,
    pool=10.0,
)

_SOCKET_OPTIONS: list[tuple[int, int, int]] = [
    (socket.IPPROTO_TCP, socket.TCP_NODELAY, 1),
]


def create_async_client(
    *,
    base_url: str = "",
    http2: bool = True,
    retries: int = 3,
    limits: httpx2.Limits = _LIMITS,
    timeout: httpx2.Timeout = _TIMEOUT,
    headers: dict[str, str] | None = None,
) -> httpx2.AsyncClient:
    transport = httpx2.AsyncHTTPTransport(
        http2=http2,
        retries=retries,
        limits=limits,
        socket_options=_SOCKET_OPTIONS,
    )
    return httpx2.AsyncClient(
        transport=transport,
        timeout=timeout,
        base_url=base_url,
        headers=headers or {},
        follow_redirects=True,
    )


def create_client(
    *,
    base_url: str = "",
    http2: bool = True,
    retries: int = 3,
    limits: httpx2.Limits = _LIMITS,
    timeout: httpx2.Timeout = _TIMEOUT,
    headers: dict[str, str] | None = None,
) -> httpx2.Client:
    transport = httpx2.HTTPTransport(
        http2=http2,
        retries=retries,
        limits=limits,
        socket_options=_SOCKET_OPTIONS,
    )
    return httpx2.Client(
        transport=transport,
        timeout=timeout,
        base_url=base_url,
        headers=headers or {},
        follow_redirects=True,
    )
```

Usage:

```python
# Async — the common case
async with create_async_client(base_url="https://api.example.com") as client:
    r = await client.get("/users")

# Sync
with create_client() as client:
    r = client.get("https://api.example.com/health")
```

Route project-owned `httpx2` construction through this factory. Framework-owned original-`httpx` clients stay confined to documented interop boundaries.

---

## 4. Special case overrides

The factory defaults cover 95% of use cases. Override only when you have a specific reason:

| Scenario | Override |
|----------|----------|
| LLM streaming endpoints | `timeout=httpx2.Timeout(connect=10.0, read=None, write=10.0, pool=10.0)` — no read timeout on streaming |
| Single-host API with low concurrency | `limits=httpx2.Limits(max_connections=50, max_keepalive_connections=20, keepalive_expiry=60.0)` |
| Ephemeral short-lived requests | `keepalive_expiry=5.0` — don't hold connections |
| Unix domain sockets | `httpx2.AsyncHTTPTransport(uds="/path/to/socket", ...)` |
| mTLS / client certs | Pass `verify=ssl_ctx` with `ctx.load_cert_chain(certfile=...)` |
| SOCKS proxy | `httpx2[socks]`, `proxy="socks5://..."` |

---

## 5. Conditional event hooks

Add hooks to the local factory only when they match the project's logging and observability practice. Projects without request logging should leave `event_hooks` unset. Example hooks for a project using stdlib logging:

```python
import time
import logging

logger = logging.getLogger(__name__)

async def log_request(request: httpx2.Request) -> None:
    request.extensions["request_start"] = time.perf_counter()

async def log_response(response: httpx2.Response) -> None:
    start = response.request.extensions.get("request_start", 0)
    elapsed = time.perf_counter() - start
    logger.info(
        "HTTP %s %s → %d (%.3fs, %s)",
        response.request.method,
        response.request.url,
        response.status_code,
        elapsed,
        response.http_version,
    )

# Sync versions for Client
def log_request_sync(request: httpx2.Request) -> None:
    request.extensions["request_start"] = time.perf_counter()

def log_response_sync(response: httpx2.Response) -> None:
    start = response.request.extensions.get("request_start", 0)
    elapsed = time.perf_counter() - start
    logger.info(
        "HTTP %s %s → %d (%.3fs, %s)",
        response.request.method,
        response.request.url,
        response.status_code,
        elapsed,
        response.http_version,
    )
```

For auto `raise_for_status()`:

```python
async def raise_on_error(response: httpx2.Response) -> None:
    response.raise_for_status()
```

---

## 6. Quick reference — fallback knobs

### `httpx2.AsyncClient` / `httpx2.Client`

| Parameter | Type | Library Default | **Our Default** |
|-----------|------|-----------------|-----------------|
| `http1` | `bool` | `True` | `True` |
| `http2` | `bool` | `False` | **`True`** |
| `verify` | `ssl.SSLContext \| str \| bool` | `True` | `True` |
| `cert` | `CertTypes \| None` | `None` | `None` |
| `proxy` | `str \| Proxy \| None` | `None` | `None` |
| `mounts` | `dict[str, Transport]` | `None` | `None` |
| `timeout` | `Timeout \| float \| None` | `Timeout(5.0)` | **Split: 5/30/10/10** |
| `limits` | `Limits` | `Limits(100, 20, 5.0)` | **`Limits(200, 40, 30.0)`** |
| `follow_redirects` | `bool` | `False` | **`True`** |
| `max_redirects` | `int` | `20` | `20` |
| `event_hooks` | `dict` | `{}` | Follow project logging practice |
| `base_url` | `str` | `""` | Set for single-API clients |
| `trust_env` | `bool` | `True` | `True` |
| `default_encoding` | `str \| Callable` | `"utf-8"` | `"utf-8"` |

### `httpx2.AsyncHTTPTransport` / `httpx2.HTTPTransport`

| Parameter | Type | Library Default | **Our Default** |
|-----------|------|-----------------|-----------------|
| `http1` | `bool` | `True` | `True` |
| `http2` | `bool` | `False` | **`True`** |
| `retries` | `int` | `0` | **`3`** |
| `limits` | `Limits` | `Limits(100, 20, 5.0)` | **`Limits(200, 40, 30.0)`** |
| `uds` | `str \| None` | `None` | `None` |
| `local_address` | `str \| None` | `None` | `None` |
| `socket_options` | `Iterable[SOCKET_OPTION]` | `None` | **`[TCP_NODELAY]`** |
| `proxy` | `str \| Proxy \| None` | `None` | `None` |

### `httpx2.Timeout`

| Parameter | Library Default | **Our Default** |
|-----------|-----------------|-----------------|
| `connect` | `5.0` | `5.0` |
| `read` | `5.0` | **`30.0`** |
| `write` | `5.0` | **`10.0`** |
| `pool` | `5.0` | **`10.0`** |

### `httpx2.Limits`

| Parameter | Library Default | **Our Default** |
|-----------|-----------------|-----------------|
| `max_connections` | `100` | **`200`** |
| `max_keepalive_connections` | `20` | **`40`** |
| `keepalive_expiry` | `5.0` | **`30.0`** |

### Async backend (httpcore2)

httpcore2 uses `anyio` by default (works with both asyncio and trio). No extra config needed if you're already on the anyio stack. For trio, install `httpcore2[trio]`.
