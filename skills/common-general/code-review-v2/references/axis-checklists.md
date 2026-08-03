# Axis Checklists

Deep checklists for each review axis, loaded on demand by the axes activated in `SKILL.md`. Each axis reads only its own section. Every finding carries its axis's name and a severity assigned within that axis.

## Correctness

Inward: is the new code right on its own terms?

- Logic errors, off-by-one, inverted conditions.
- Null / undefined / None handling; empty and boundary inputs.
- Edge cases the happy path skips.
- Concurrency — race conditions, deadlocks, unsafe shared mutable state, missing locks or atomics.
- Error handling — swallowed exceptions, missing context, empty catch blocks, wrong propagation.
- Resource lifecycle — files, handles, connections closed on every path.

See `language-patterns.md` for language-specific correctness patterns.

## Standards

Non-behavioral quality and convention. A documented repo standard always wins; skip anything tooling (linter, formatter) already enforces. Each smell below is a labelled judgement call ("possible Feature Envy"), never a hard violation.

Fowler smell baseline (_Refactoring_, ch.3) — *what it is* → *how to fix*:

- **Mysterious Name** — a name that doesn't reveal what it does or holds. → rename; if no honest name comes, the design is murky.
- **Duplicated Code** — the same logic shape in more than one place in the change. → extract the shape, call it from both.
- **Feature Envy** — a method reaching into another object's data more than its own. → move it onto the data it envies.
- **Data Clumps** — the same few fields or params keep travelling together. → bundle them into one type, pass that.
- **Primitive Obsession** — a primitive or string standing in for a domain concept. → give the concept its own small type.
- **Repeated Switches** — the same `switch`/`if`-cascade on the same type recurs. → polymorphism, or one shared map.
- **Shotgun Surgery** — one logical change forcing scattered edits across many files. → gather what changes together.
- **Divergent Change** — one module edited for several unrelated reasons. → split so each changes for one reason.
- **Speculative Generality** — abstraction or hooks for needs the change doesn't have. → delete; inline until a real need shows.
- **Message Chains** — long `a.b().c().d()` navigation the caller shouldn't depend on. → hide the walk behind one method.
- **Middle Man** — a class or function that mostly delegates onward. → cut it, call the real target direct.
- **Refused Bequest** — a subclass or implementer ignoring most of what it inherits. → drop inheritance, use composition.

Also check naming clarity, function length and complexity, single responsibility, and consistency with 2-3 sibling files (sample them before flagging a deviation).

## Regression

Outward: what existing behavior could this break?

- Callers of every changed function, type, or exported symbol — does the signature, return type, or behavioral change break any? Find them with `rg "<symbol>\b"` across the repo.
- Dependents — files that import the changed module.
- Contracts — public API shape, serialized formats, event or message schemas.
- Migrations and schema — forward and backward compatibility, data already in flight, rollback path.
- Feature flags or config defaults that alter existing behavior.

## Security

Always triage; run the deep pass only when the foundation brief flags a security surface. Categorize with STRIDE (Spoofing, Tampering, Repudiation, Information disclosure, Denial of service, Elevation of privilege).

- Injection — SQL, command, LDAP, XML, template. Use parameterized queries; never string-concatenate untrusted input.
- Authentication and session — login, MFA, session lifecycle, logout.
- Authorization — function-level checks, IDOR, privilege escalation. Verify authentication AND authorization on every protected path.
- Input validation and output encoding — XSS (prefer `textContent` over `innerHTML`), path traversal, deserialization of untrusted data.
- Secrets and sensitive data — no secrets in code or logs; encryption in transit and at rest; careful PII handling.
- Error handling and configuration — fail secure, no information leakage, default-deny, hardened framework config.

## Spec

Runs only when a spec source exists — PR description, commit messages, a linked issue or ticket, or a path provided. Fetch reachable links to read it. Report:

- Requirements the spec asked for that are missing or only partial.
- Behavior in the diff that wasn't asked for (scope creep).
- Requirements that look implemented but where the implementation looks wrong.

Quote the spec line for each finding. If no spec source exists, the axis does not run.

## Performance

Runs when the diff touches hot paths, loops, queries, or allocations.

- N+1 queries — a query inside a loop; batch with an `IN` clause or eager load.
- Algorithmic complexity — nested scans, accidental O(n²), work repeated per iteration.
- Allocations in loops, unbounded growth, missing pagination or streaming for large sets.
- Resource leaks — unbounded caches, unclosed connections.

## Tests

Runs when tests are present or expected for the change.

- New logic and each new branch covered.
- Edge cases and error paths tested, not only the happy path.
- Assertion quality — meaningful checks, not mere existence or snapshot noise.
- Tests fail for the right reason and don't depend on hidden ordering.

## Observability

Runs when the change is operationally significant — services, error paths, external calls.

- Logging at decision points and failures, with enough context to debug and no secrets or PII.
- Metrics for new operations worth monitoring.
- Tracing across service or async boundaries.
