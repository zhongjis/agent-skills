# Database Stack — sqlc + pgx + goose + testcontainers

Canonical PostgreSQL patterns, split by topic:

- [Schema and queries](sqlc-schema.md) — toolchain, layout, sqlc config, SQL, and generated code.
- [Store and transactions](sqlc-store.md) — pgx pools, domain mapping, and transaction boundaries.
- [Operations and integration tests](sqlc-operations.md) — migrations, testcontainers, and ORM tradeoffs.

Keep generated contracts explicit and inject pools into store constructors.
