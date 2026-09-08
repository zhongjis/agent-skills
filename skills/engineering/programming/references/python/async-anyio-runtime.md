# AnyIO Reference: Runtime and Integration

## Backend Selection

AnyIO is backend-agnostic. Code written against AnyIO APIs runs on both asyncio and Trio.

```python
import anyio

async def main() -> None:
    print("running on", anyio.current_async_library())
    await anyio.sleep(1)

# Default backend (asyncio)
anyio.run(main)

# Explicit backend
anyio.run(main, backend="trio")
anyio.run(main, backend="asyncio", backend_options={"debug": True})
```

**Library design rule**: Never hardcode a backend. Let the application choose via `anyio.run()`. Libraries should only import `anyio` and avoid backend-specific APIs.

---

## Compatibility with asyncio-only libraries

### Using asyncio libraries under the asyncio backend

If a third-party library exposes only an asyncio interface (returns asyncio coroutine objects), it works directly under the asyncio backend because AnyIO runs on top of asyncio's event loop:

```python
import anyio
import some_asyncio_only_lib  # returns asyncio.Future/coroutine objects

async def main() -> None:
    # This works because under the asyncio backend, await passes through
    result = await some_asyncio_only_lib.fetch_data()

anyio.run(main, backend="asyncio")
```

**Important**: This only works on the `asyncio` backend. On the `trio` backend, asyncio-native objects will not work.

### When you MUST use asyncio APIs

Some APIs have no AnyIO equivalent and require direct event loop access:

| Scenario | asyncio API | AnyIO approach |
|----------|-------------|----------------|
| Signal handlers | `loop.add_signal_handler()` | `anyio.open_signal_receiver()` |
| Custom protocols | `asyncio.Protocol` | Use AnyIO streams / sockets |
| Direct Future manipulation | `asyncio.Future` | Avoid; use AnyIO primitives |
| Eager task factories | `asyncio.eager_task_factory` | Experimental in AnyIO; avoid |

If you absolutely need the running loop:

```python
import asyncio

async def main() -> None:
    loop = asyncio.get_running_loop()
    # ... do something loop-specific ...
    # WARNING: this breaks backend-agnosticism

anyio.run(main, backend="asyncio")
```

**Best practice**: Wrap asyncio-only code in a backend-agnostic facade, and document that the feature requires the asyncio backend.

---

## Idiomatic Code Snippets

### Snippet 1: Parallel HTTP requests with timeout and cleanup

```python
import anyio

async def fetch(url: str) -> bytes:
    await anyio.sleep(0.5)  # simulate
    return b"data"

async def main() -> None:
    urls = ["a", "b", "c"]
    async with anyio.create_task_group() as tg:
        with anyio.move_on_after(5):
            for url in urls:
                tg.start_soon(fetch, url)
        # All tasks are cancelled on timeout; task group waits for cleanup

anyio.run(main)
```

### Snippet 2: Producer-consumer with memory object stream

```python
import anyio
from anyio.streams.memory import MemoryObjectReceiveStream

async def producer(send_stream: anyio.streams.memory.MemoryObjectSendStream[int]) -> None:
    async with send_stream:
        for i in range(100):
            await send_stream.send(i)

async def consumer(receive_stream: MemoryObjectReceiveStream[int]) -> None:
    async with receive_stream:
        async for item in receive_stream:
            print(f"consumed {item}")

async def main() -> None:
    send, receive = anyio.create_memory_object_stream[int](max_buffer_size=5)
    async with anyio.create_task_group() as tg:
        tg.start_soon(producer, send)
        tg.start_soon(consumer, receive)

anyio.run(main)
```

### Snippet 3: Calling sync code from async

```python
import time
import anyio

async def main() -> None:
    # Run blocking function in worker thread
    result = await anyio.to_thread.run_sync(time.sleep, 2)
    print("done")

anyio.run(main)
```

### Snippet 4: Calling async code from a worker thread

```python
import anyio

def blocking_callback() -> None:
    # Inside a worker thread, call back into the event loop
    anyio.from_thread.run(anyio.sleep, 1)
    anyio.from_thread.run_sync(print, "hello from thread")

async def main() -> None:
    await anyio.to_thread.run_sync(blocking_callback)

anyio.run(main)
```

### Snippet 5: Graceful shutdown with shielded cleanup

```python
import anyio

async def worker() -> None:
    try:
        await anyio.sleep_forever()
    except anyio.get_cancelled_exc_class():
        with anyio.CancelScope(shield=True):
            await anyio.sleep(0.5)  # cleanup
            print("cleaned up")
        raise

async def main() -> None:
    async with anyio.create_task_group() as tg:
        tg.start_soon(worker)
        await anyio.sleep(1)
        tg.cancel_scope.cancel()

anyio.run(main)
```

---

## Sources

- AnyIO documentation: https://anyio.readthedocs.io/
- AnyIO GitHub: https://github.com/agronholm/anyio
- Task Groups: https://anyio.readthedocs.io/en/stable/tasks.html
- Cancellation & Timeouts: https://anyio.readthedocs.io/en/stable/cancellation.html
- Streams: https://anyio.readthedocs.io/en/stable/streams.html
- Synchronization: https://anyio.readthedocs.io/en/stable/synchronization.html
- Threads: https://anyio.readthedocs.io/en/stable/threads.html
- Basics / Backends: https://anyio.readthedocs.io/en/stable/basics.html
- Design Rationale (why asyncio is problematic): https://anyio.readthedocs.io/en/stable/why.html
