# AnyIO Reference: Structured Concurrency

## Task Groups (The Core Primitive)

AnyIO uses **structured concurrency** via task groups. A task group is an async context manager that guarantees all child tasks finish before the block exits.

### `start_soon` — fire-and-forget

```python
import anyio

async def worker(n: int) -> None:
    await anyio.sleep(1)
    print(f"task {n} done")

async def main() -> None:
    async with anyio.create_task_group() as tg:
        for i in range(3):
            tg.start_soon(worker, i)
    print("all tasks finished")

anyio.run(main)
```

**Signature**: `tg.start_soon(func, *args, name=None)`
- `func` must be a **coroutine function** (not a coroutine object).
- `name` is optional, for introspection/debugging.
- No return value; exceptions propagate as `ExceptionGroup` on exit.

### `start` — wait for ready signal

Use when a task must initialize before the caller proceeds (e.g., starting a server and then connecting to it).

```python
from anyio import TASK_STATUS_IGNORED, create_task_group, run
from anyio.abc import TaskStatus

async def start_server(port: int, *, task_status: TaskStatus[None] = TASK_STATUS_IGNORED) -> None:
    listener = await anyio.create_tcp_listener(local_host="127.0.0.1", local_port=port)
    task_status.started()  # unblocks tg.start()
    await listener.serve(handler)

async def main() -> None:
    async with create_task_group() as tg:
        await tg.start(start_server, 8080)  # blocks until task_status.started()
        # server is guaranteed ready here
        async with await anyio.connect_tcp("127.0.0.1", 8080) as client:
            ...

run(main)
```

**Rule of thumb**:
- Use `start_soon` when you don't need to know when the task is ready.
- Use `start` when the task must signal readiness before you continue.

### `create_task` — retrieving return values (AnyIO 4.14+)

```python
async def add(x: int, y: int) -> int:
    return x + y

async def main() -> None:
    async with anyio.create_task_group() as tg:
        handle = tg.create_task(add(2, 4))
        result = await handle  # == 6
        print(handle.return_value)  # also 6

anyio.run(main)
```

**Signature**: `tg.create_task(coro, *, name=None, context=None) -> TaskHandle[T]`
- Returns a `TaskHandle` you can `await` for the result.
- If the task raises, awaiting raises `TaskFailed` (or `TaskCancelled`).
- This is the canonical replacement for `asyncio.gather` when you need results.

---

## asyncio → anyio Cheat Sheet

| asyncio | anyio | Notes |
|---------|-------|-------|
| `asyncio.gather(a, b, c)` | `tg.create_task(a); tg.create_task(b); tg.create_task(c); results = [await h for h in handles]` | No direct gather; structured concurrency requires explicit task group scope. For fire-and-forget, use `tg.start_soon`. |
| `asyncio.create_task(coro)` | `tg.start_soon(func, *args)` or `tg.create_task(coro)` | `start_soon` takes a coroutine **function** + args. `create_task` takes a coroutine **object** and returns a handle. |
| `asyncio.sleep(n)` | `anyio.sleep(n)` | Identical semantics. |
| `asyncio.wait_for(coro, timeout)` | `with anyio.fail_after(timeout): await coro` | Raises `TimeoutError`. Use `move_on_after` for silent timeout. |
| `asyncio.Event()` | `anyio.Event()` | AnyIO events are **not reusable**; create a new one instead of `.clear()`. |
| `asyncio.Lock()` | `anyio.Lock()` | Use `async with lock:`. Pass `fast_acquire=True` if performance-critical. |
| `asyncio.Semaphore(n)` | `anyio.Semaphore(n)` | Same. Pass `fast_acquire=True` if performance-critical. |
| `asyncio.Condition()` | `anyio.Condition()` | Same semantics. |
| `asyncio.run(main())` | `anyio.run(main)` | Backend-agnostic entry point. |
| `asyncio.Queue(maxsize=N)` | `anyio.create_memory_object_stream[T](max_buffer_size=N)` | Returns `(send_stream, receive_stream)`. Supports `async for` on receive end. |
| `asyncio.to_thread(fn, *args)` | `anyio.to_thread.run_sync(fn, *args)` | Supports `abandon_on_cancel=True` and custom `limiter`. |
| `asyncio.run_coroutine_threadsafe(coro, loop)` | `anyio.from_thread.run(func, *args)` | Call async code from a worker thread. |
| `loop.call_soon_threadsafe(callback)` | `anyio.from_thread.run_sync(func, *args)` | Call sync code in event loop thread from worker thread, **with return value**. |
| `asyncio.shield(coro)` | `with anyio.CancelScope(shield=True): ...` | AnyIO shielding does not orphan tasks. |
| `asyncio.timeout(delay)` | `with anyio.fail_after(delay): ...` | AnyIO uses level cancellation, not edge cancellation. |
| `asyncio.CancelledError` | `anyio.get_cancelled_exc_class()` | Use this to catch cancellation portably across backends. |

---

## Cancellation & CancelScope

AnyIO uses **level cancellation** (inspired by Trio), not asyncio's **edge cancellation**.

- **Edge cancellation** (asyncio): A `CancelledError` is injected once. If caught and not re-raised, the task keeps running.
- **Level cancellation** (anyio): As long as a task is inside an effectively cancelled scope, every yield point raises a new cancellation exception.

### Basic CancelScope

```python
from anyio import CancelScope, create_task_group, get_cancelled_exc_class, sleep, run

async def worker() -> None:
    try:
        await sleep(10)
    except get_cancelled_exc_class():
        print("cancelled!")
        raise  # ALWAYS re-raise cancellation exceptions

async def main() -> None:
    async with create_task_group() as tg:
        tg.start_soon(worker)
        await sleep(0.1)
        tg.cancel_scope.cancel()  # cancels all children

run(main)
```

### Shielding

Shield a block from external cancellation. Essential for cleanup.

```python
from anyio import CancelScope, create_task_group, sleep, run

async def main() -> None:
    async with create_task_group() as tg:
        with CancelScope(shield=True):
            tg.start_soon(some_task)
            tg.cancel_scope.cancel()  # shielded block is protected
            await sleep(1)  # this still runs

run(main)
```

**Combine with timeouts for graceful shutdown**:

```python
from anyio import CancelScope, move_on_after

async def do_something(resource) -> None:
    try:
        await run_async_stuff()
    except BaseException:
        # Allow up to 10s for cleanup, then move on
        with move_on_after(10, shield=True):
            await resource.aclose()
        raise
```

### Structured Concurrency Guarantee

A task group contains its own `CancelScope`. If any child task raises an exception:
1. The task group's cancel scope is cancelled.
2. All other child tasks receive cancellation.
3. The task group waits for all children to finish.
4. The original exception (wrapped in `ExceptionGroup` if multiple) is re-raised.

---

## Timeouts

Two context managers. Both create a `CancelScope` internally.

### `fail_after` — raises on timeout

```python
from anyio import fail_after, sleep, run

async def main() -> None:
    try:
        with fail_after(5) as scope:
            await sleep(10)
    except TimeoutError:
        print("timed out")
        print(scope.cancelled_caught)  # True

run(main)
```

### `move_on_after` — silent timeout

```python
from anyio import move_on_after, sleep, run

async def main() -> None:
    with move_on_after(5) as scope:
        await sleep(10)
        print("this never prints")

    print("exited scope, cancelled =", scope.cancelled_caught)

run(main)
```

### Combined with shielding

```python
from anyio import move_on_after

# Give cleanup 10 seconds, but don't let outer cancellation interrupt it
with move_on_after(10, shield=True):
    await resource.aclose()
```

---

## Memory Object Streams (Queue Replacement)

Replaces `asyncio.Queue` with a safer, typed, structured-concurrency-friendly construct.

```python
from anyio import create_task_group, create_memory_object_stream, run
from anyio.streams.memory import MemoryObjectReceiveStream

async def consumer(stream: MemoryObjectReceiveStream[str]) -> None:
    async with stream:  # closes receive end on exit
        async for item in stream:
            print("received", item)

async def main() -> None:
    # Type-annotated stream creation (AnyIO 4+ syntax)
    send_stream, receive_stream = create_memory_object_stream[str](max_buffer_size=10)

    async with create_task_group() as tg:
        tg.start_soon(consumer, receive_stream)
        async with send_stream:
            for i in range(5):
                await send_stream.send(f"item {i}")
        # send_stream closed → consumer's async for loop exits naturally

run(main)
```

**Key differences from `asyncio.Queue`**:
- **Bounded by default**: `max_buffer_size=0` means send blocks until a receiver is ready.
- **Cloneable**: Each producer/consumer can close its own clone. The stream only ends when **all** clones of one end are closed.
- **Async iterable**: `async for item in receive_stream:` works out of the box.
- **Type-safe**: Generic `create_memory_object_stream[T]()`.
- **Synchronous close**: Both `close()` and `async with` work.

---
