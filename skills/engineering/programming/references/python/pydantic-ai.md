# PydanticAI Reference

Production patterns for the current `output_type` and `result.output` API.
Source: [ai.pydantic.dev](https://ai.pydantic.dev).

---

## 1. Agent Constructor

```python
from pydantic_ai import Agent

agent = Agent(
    'openai:gpt-5.5',               # model (str | Model | None)
    output_type=MyOutputModel,       # structured output type; default=str
    instructions='You are a...',     # static or callable instructions
    system_prompt='Be concise.',     # static system prompt(s)
    deps_type=MyDeps,                # dependency type for type-checking only
    name='my-agent',                 # optional, inferred from var name if omitted
    retries=1,                       # default retries for tools + output validation
    output_retries=None,             # override retries for output validation only
    tools=[my_tool],                 # list of Tool objects or plain functions
    defer_model_check=False,         # set True to skip env-var check at init time
    end_strategy='early',            # 'early' | 'graceful' | 'exhaustive'
)
```


---

## 2. Model Strings

Format: `provider:model-name`. The framework infers the provider from the prefix.

| Provider prefix | Example |
|---|---|
| `openai:` | `'openai:gpt-5.5'`, `'openai:gpt-4o'` |
| `anthropic:` | `'anthropic:claude-sonnet-4-6'`, `'anthropic:claude-opus-4-1'` |
| `google-gla:` | `'google-gla:gemini-3-flash-preview'` |
| `google-vertex:` | `'google-vertex:gemini-3-pro-preview'` |
| `bedrock:` | `'bedrock:anthropic.claude-sonnet-4-6'` |
| `xai:` / `grok:` | `'xai:grok-3'`, `'grok:grok-3-fast'` |
| `deepseek:` | `'deepseek:deepseek-chat'` |
| `cohere:` | `'cohere:command-r-08-2024'` |
| `gateway/...` | `'gateway/openai:gpt-5.5'` (PydanticAI Gateway) |

Model can also be omitted at construction and passed per-run: `agent.run(prompt, model='openai:gpt-5.5')`.

---

## 3. Tools

### Decorator syntax

```python
from pydantic_ai import Agent, RunContext

agent = Agent('openai:gpt-5.5', deps_type=str)

@agent.tool                    # default: receives RunContext as first arg
async def greet(ctx: RunContext[str], name: str) -> str:
    return f"Hello {ctx.deps}, {name}!"

@agent.tool_plain              # no context needed
async def roll_dice(sides: int) -> int:
    import random
    return random.randint(1, sides)
```

### `RunContext[Deps]`

First parameter of `@agent.tool` functions. Carries:

- `ctx.deps` — the dependency instance
- `ctx.model` — the model being used
- `ctx.usage` — token usage so far
- `ctx.messages` — conversation history
- `ctx.retry` / `ctx.max_retries` — current retry count
- `ctx.agent` — the running agent instance

Use `@agent.tool_plain` when the tool does **not** need any of the above.

---

## 4. Structured Output

Pass a Pydantic `BaseModel` (or `bool`, `int`, `list[str]`, etc.) as `output_type`. The result is accessed via `.output`.

```python
from pydantic import BaseModel
from pydantic_ai import Agent

class City(BaseModel):
    name: str
    country: str
    population_millions: float

agent = Agent('openai:gpt-5.5', output_type=City)
result = agent.run_sync('Tell me about Tokyo')
print(result.output)            # City(name='Tokyo', country='Japan', ...)
print(result.output.name)       # 'Tokyo'
```

Use `result.output` for run results.

---

## 5. Async vs Sync

| Method | Mode | Returns |
|---|---|---|
| `await agent.run(prompt, ...)` | async | `AgentRunResult[OutputDataT]` |
| `agent.run_sync(prompt, ...)` | sync | `AgentRunResult[OutputDataT]` |
| `async with agent.run_stream(prompt, ...) as response:` | async streaming | `StreamedRunResult` |

```python
# Sync
result = agent.run_sync('What is the capital of Italy?')
print(result.output)

# Async
result = await agent.run('What is the capital of France?')
print(result.output)

# Streaming
async with agent.run_stream('What is the capital of the UK?') as response:
    async for text in response.stream_text():
        print(text, end='')
    # After streaming finishes:
    print(response.output)
```

`run_sync()` is a convenience wrapper over `loop.run_until_complete(self.run(...))`. Do not use it inside an active async context.

---

## 6. Dependencies

Use a frozen `@dataclass` container, pass the **type** to `deps_type`, and pass an **instance** to `deps` at run time. Follow the existing project's HTTP client. This example uses the default `httpx2` factory for a project with no established client:

```python
from dataclasses import dataclass

import httpx2
from myapp.http_client import create_async_client
from pydantic_ai import Agent, RunContext


@dataclass(frozen=True, slots=True)
class Deps:
    api_key: str
    http_client: httpx2.AsyncClient


agent = Agent(
    'openai:gpt-5.5',
    deps_type=Deps,
)


@agent.tool
async def fetch_data(ctx: RunContext[Deps], endpoint: str) -> str:
    response = await ctx.deps.http_client.get(
        endpoint,
        headers={'Authorization': f'Bearer {ctx.deps.api_key}'},
    )
    response.raise_for_status()
    return response.text


async def main() -> None:
    async with create_async_client() as client:
        deps = Deps(api_key='sk-...', http_client=client)
        result = await agent.run('Get /users', deps=deps)
        print(result.output)
```

PydanticAI itself may expose original-`httpx` transport types. Use original `httpx` only at that framework interop boundary; application-owned tool requests still follow project HTTP policy.

---

## 7. Error Types & Retrying from a Tool

```python
from pydantic_ai import Agent, ModelRetry, UnexpectedModelBehavior, capture_run_messages

agent = Agent('openai:gpt-5.5', retries=3)

@agent.tool_plain
def calc_volume(size: int) -> int:
    if size == 42:
        return size ** 3
    raise ModelRetry('Please try again with size 42.')

with capture_run_messages() as messages:
    try:
        result = agent.run_sync('Get the volume of a box with size 6.')
    except UnexpectedModelBehavior as e:
        print('Error:', e)          # "Tool 'calc_volume' exceeded max retries count of 3"
        print('Cause:', e.__cause__)  # ModelRetry('Please try again...')
        print('Messages:', messages)
```

- **`ModelRetry`** — raise from a tool, output validator, or capability hook to ask the model to retry.
- **`UnexpectedModelBehavior`** — raised when the retry limit is exceeded or the model API returns an unrecoverable error.
- **`capture_run_messages()`** — context manager that records all messages exchanged during a run for debugging.

---

## 8. Logfire Integration

Enable Logfire only when it matches the project's logging and observability practice and the `logfire` extra is installed:

```python
import logfire

logfire.configure()               # reads token from .logfire directory
logfire.instrument_pydantic_ai()  # auto-traces all agent runs
```

Alternatively, set `instrument=True` on the agent:

```python
agent = Agent('openai:gpt-5.5', instrument=True)
```

---

## 9. Minimal Complete Snippets

### (a) Basic agent with structured output

```python
from pydantic import BaseModel
from pydantic_ai import Agent

class City(BaseModel):
    name: str
    country: str

agent = Agent('openai:gpt-5.5', output_type=City)
result = agent.run_sync('Tell me about Paris')
print(result.output)   # City(name='Paris', country='France')
```

### (b) Agent with tools and dependencies

```python
from dataclasses import dataclass
from pydantic_ai import Agent, RunContext

@dataclass
class Deps:
    api_key: str

agent = Agent('openai:gpt-5.5', deps_type=Deps)

@agent.tool
async def get_secret(ctx: RunContext[Deps], code: str) -> str:
    if code == '1234':
        return f'secret-for-{ctx.deps.api_key}'
    return 'wrong code'

result = agent.run_sync('My code is 1234', deps=Deps(api_key='sk-abc'))
print(result.output)
```

### (c) Async streaming

```python
import anyio
from pydantic_ai import Agent

agent = Agent('openai:gpt-5.5')

async def main() -> None:
    async with agent.run_stream('Write a haiku about Python') as response:
        async for text in response.stream_text():
            print(text, end='')
        print('\n---')
        print('Final:', response.output)

anyio.run(main)
```
