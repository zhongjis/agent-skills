# Code Smells — Full Reference

When any of these smells is detected, **STOP and re-examine your design.** A code smell is not a syntax error — it signals that the current structure deserves a second look. Fix the smell or document a SPECIFIC justification for carrying it. "It's fine" is not a justification.

To remove AI-generated slop across an entire diff or file list as a bounded, test-locked cleanup — rather than judging one smell in place — use the [`remove-ai-slops`](../../remove-ai-slops/SKILL.md) skill. This reference owns the smell definitions; that skill owns the removal workflow.

To execute a restructuring safely — map the blast radius, plan atomic steps, and verify after every change — use the [`refactor`](../../refactor/SKILL.md) skill. This reference owns the smell definitions; that skill owns the restructuring workflow.

---

## Smell 1 — Function with more than 3 parameters

### Why 3

A function's parameters are its contract with every caller. More than 3 independent inputs overwhelm the caller's working memory and signal one of two design problems:

1. **The function does too much.** It should be two functions.
2. **Related parameters belong together.** They should be a typed struct/object — a domain concept, not a parameter bag.

### Workaround detection — THESE COUNT AS THE SAME SMELL

Disguising parameter count does not fix the design. The following patterns are the same smell wearing a different hat:

**Dict/map smuggling:**
```python
# SMELL — hiding 6 args in a dict
def create_order(params: dict[str, Any]) -> Order: ...
```
```typescript
// SMELL — untyped options bag
function createOrder(opts: Record<string, unknown>): Order { ... }
```
```go
// SMELL — map instead of typed params
func CreateOrder(params map[string]any) (*Order, error) { ... }
```

**Variadic/kwargs catch-all:**
```python
# SMELL — hiding real params behind kwargs
def send_notification(recipient: str, **kwargs) -> None: ...
```
```typescript
// SMELL — rest params to avoid naming args
function sendNotification(recipient: string, ...args: unknown[]): void { ... }
```

**Config object that wraps positional args:**
```python
# SMELL — "options" object that exists only to bundle what would be positional args
@dataclass
class CreateUserOptions:
    name: str
    email: str
    password: str
    role: str
    department: str
    manager_id: int
    # 6 fields, used by exactly one function, no defaults

def create_user(opts: CreateUserOptions) -> User: ...
```

**When the options object is NOT a smell:** when it represents a genuine domain concept reused across multiple call sites with sensible defaults for most fields (e.g., `HttpClientConfig`, `DatabaseConnectionOptions`, `RetryPolicy`).

### The fix

Group related parameters into typed value objects with domain names:

```python
# CLEAN — grouped by domain concept
@dataclass(frozen=True)
class UserIdentity:
    name: str
    email: str

@dataclass(frozen=True)
class OrgPlacement:
    role: str
    department: str
    manager_id: int

def create_user(identity: UserIdentity, placement: OrgPlacement, password: str) -> User: ...
# 3 params, each a meaningful concept
```

```typescript
// CLEAN — typed grouping
interface ShippingDetails {
  readonly address: string;
  readonly city: string;
  readonly zip: string;
  readonly country: string;
}

function createOrder(customer: CustomerId, items: readonly LineItem[], shipping: ShippingDetails): Order { ... }
// 3 params, shipping is a reusable domain type
```

```go
// CLEAN — struct with domain meaning
type Placement struct {
    Role       string
    Department string
    ManagerID  UserID
}

func CreateUser(identity UserIdentity, placement Placement, password string) (*User, error) { ... }
```

If 4+ truly independent inputs are required, justify it — the justification must name WHY these inputs cannot be grouped, not just "the function needs them all."

---

## Smell 2 — Redundant verification after a destructive action

### Why this is slop

The contract of a destructive operation (delete, remove, clear, drop) IS the verification. If the operation returns without error, the thing is gone. Re-querying to "confirm" is:

1. **Dead code.** The check can never fail unless the operation itself is broken — in which case fix the operation, not the caller.
2. **Misleading.** It teaches the next reader (human or AI) that the operation is unreliable.
3. **Performance waste.** An unnecessary round-trip to the database, filesystem, or data structure.

This pattern is the hallmark of AI-generated defensive bloat. LLMs produce it because they optimize for "looking thorough" over "being correct." **Recognize it. Delete it.**

### Examples

```python
# SLOP — delete then verify deletion
db.delete(user)
db.commit()
remaining = db.query(User).filter_by(id=user.id).first()
assert remaining is None  # the ORM already guaranteed this

# CLEAN
db.delete(user)
db.commit()
```

```typescript
// SLOP — remove from array then check it's gone
items = items.filter(i => i.id !== targetId);
if (items.find(i => i.id === targetId)) {
  throw new Error("removal failed");  // impossible by construction
}

// CLEAN
items = items.filter(i => i.id !== targetId);
```

```go
// SLOP — delete row then SELECT to confirm
_, err := db.ExecContext(ctx, "DELETE FROM users WHERE id = $1", id)
if err != nil { return err }
row := db.QueryRowContext(ctx, "SELECT id FROM users WHERE id = $1", id)
if err := row.Scan(&check); err != sql.ErrNoRows {
    return fmt.Errorf("delete verification failed")
}

// CLEAN
_, err := db.ExecContext(ctx, "DELETE FROM users WHERE id = $1", id)
if err != nil { return err }
```

```rust
// SLOP — remove from HashMap then check absence
map.remove(&key);
if map.contains_key(&key) {
    panic!("removal failed");  // HashMap::remove is not broken
}

// CLEAN
map.remove(&key);
```

### Broader pattern — same smell, different disguise

Any of these are the same defect:

- Calling a **setter** then immediately calling the **getter** to "confirm" the value changed.
- **Writing** a file then **reading** it back to "verify" the write.
- **Inserting** a row then **SELECT-ing** it to "confirm" the insert.
- **Pushing** to an array then checking `.length` increased by 1.
- **Assigning** a variable then asserting the variable equals the assigned value.

**The contract of the operation IS the verification.** If you cannot trust the operation's return, the defect is in the operation — fix it there, not at the call site.

---

## Smell 3 — Negative-form names and conditions

### Why positive form wins

Every negation forces the reader to mentally invert. One negation is tolerable. Two (`if !isNotReady`) is a logic puzzle. Codebases that default to negative naming accumulate double and triple negations that nobody can review confidently.

Positive form reads in the direction of intent: "is this ready?" rather than "is this not-not-ready?"

### Naming

| Negative (SMELL) | Positive (CLEAN) |
|---|---|
| `isNotValid` | `isValid` (invert branch) |
| `isDisabled` | `isEnabled` |
| `noErrors` | `isClean` / `errorsResolved` |
| `notFound` | `found` (invert branch) |
| `isNotEmpty` | `hasItems` / `isPopulated` |
| `missingAuth` | `hasAuth` / `isAuthenticated` |
| `cannotProceed` | `canProceed` (invert branch) |

Name the **presence** of the quality you care about, not the absence of its opposite.

### Conditions

```python
# SMELL — double negative
if not is_invalid(token):
    proceed()

# CLEAN — single positive check
if is_valid(token):
    proceed()
```

```typescript
// SMELL — negated boolean in branch
if (!user.isNotVerified) {
  grantAccess();
}

// CLEAN — positive name, direct check
if (user.isVerified) {
  grantAccess();
}
```

```go
// SMELL — inverted negative
if !config.DisableLogging {
    log.Info("starting")
}

// CLEAN — positive flag
if config.LoggingEnabled {
    log.Info("starting")
}
```

```rust
// SMELL — negated negative
if !skip_validation {
    validate(&input)?;
}

// CLEAN — positive gate
if should_validate {
    validate(&input)?;
}
```

### When negation IS appropriate

- **Early returns / guard clauses:** `if !authorized { return Err(...) }` — the negative form IS the intent (reject the bad case).
- **Filtering out:** `items.filter(|x| !x.is_expired())` — the negation describes the keep/discard decision directly.
- **Error state names:** `Error`, `Failed`, `Timeout` are negative concepts by nature — do not force them into positive wrappers like `isSuccessAbsent`.

The rule is not "never use negation." The rule is: **when you have a choice between naming the presence and naming the absence, name the presence.** The branch logic follows from the name, not the other way around.
