# Language-Specific Patterns

Consult when the diff includes code in these languages. Referenced from the Code Review skill (`SKILL.md`). Apply alongside the Phase 3 review dimensions.

## Python

Bad — no types, no resource management, no error handling:

```python
def get_user_data(id):
    f = open("data.json")
    data = json.load(f)
    return data[id]
```

Good — typed, safe resource management, defensive:

```python
def get_user_data(user_id: str) -> dict:
    try:
        with open("data.json", "r") as f:
            data = json.load(f)
            return data.get(user_id, {})
    except (FileNotFoundError, json.JSONDecodeError) as e:
        logger.error("Failed to load user data for %s: %s", user_id, e)
        return {}
```

Key patterns to check:

- Type hints on function signatures and return types
- Context managers (`with`) for file/resource handling
- List comprehensions over loop-and-append
- Specific exceptions, never bare `except:`

## TypeScript

Bad — `any` types, no error handling:

```typescript
async function update(data: any) {
  const result = await api.post("/update", data);
  return result.data;
}
```

Good — typed interface, proper error handling:

```typescript
interface UpdatePayload {
  name: string;
  value: number;
}
interface UpdateResponse {
  success: boolean;
  id: string;
}

async function update(data: UpdatePayload): Promise<UpdateResponse> {
  const response = await api.post<UpdateResponse>("/update", data);
  return response.data;
}
```

Key patterns to check:

- Strict null checks and proper type narrowing (no `as any`)
- Typed error handling (not `catch(e: any)`)
- Async/await with proper cleanup (AbortController for cancellation)
- Guard clauses over deeply nested conditionals

## General (Any Language)

**N+1 Query Detection:**

- Bad: `SELECT * FROM posts WHERE user_id = ?` inside a user loop
- Good: `SELECT * FROM posts WHERE user_id IN (?)` before the loop with eager loading

**Security:**

- XSS: Use `textContent` over `innerHTML` for user-provided strings
- SQL Injection: Always use parameterized queries; never concatenate user input into SQL
- Auth: Verify authentication AND authorization on every protected endpoint
