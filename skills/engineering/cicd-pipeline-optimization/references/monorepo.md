# Monorepo CI

Without affected-only logic, every PR runs CI for every package. Pick the lightest tool that captures the repo's dependency graph:

| Strategy | Fits | Setup | Gap |
| --- | --- | --- | --- |
| `dorny/paths-filter` per package, jobs gated by `if:` | under ~10 packages, shallow dependencies | hours | misses transitive dependents unless each filter lists its dependencies' paths |
| Turborepo `turbo run build test --filter='...[origin/main]'` + remote cache | JS/TS monorepos | days | JS-ecosystem focus |
| Nx `nx affected -t build test` + Nx Cloud | JS/TS and polyglot via plugins; large repos gain from distributed execution | days | Nx Cloud is a paid service |
| Bazel + remote cache | 100+ engineers, polyglot (C++/Java/Python), file-level precision | months, plus ongoing build-engineering staff | below ~100 engineers, Turborepo or Nx usually return more per engineering hour |

Affected-only and remote caching compound: affected logic skips untouched packages, and the remote cache skips unchanged tasks inside touched ones.

Affected detection needs the base commit. Fetch it without blobs (`fetch-depth: 0` with `filter: blob:none`) or fetch only the base ref; for Nx, `nrwl/nx-set-shas` sets the base and head. Without the base, detection silently runs everything.

Use `sparse-checkout` so each job checks out only its package and shared config.

Test selection inside a package: [tests](tests.md).
