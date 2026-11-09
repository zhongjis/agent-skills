# Caching

## Write policy

- Save caches only from trusted default-branch runs (`push`, `schedule`, `workflow_dispatch`). Their entries are readable by every branch and PR.
- PR and merge-queue runs use restore-only (`actions/cache/restore`). Their saves land in a scope only that PR or queue branch reads, and they evict default-branch entries when the repository cache fills.
- Low-trust triggers (`pull_request_target`, `issue_comment`, `workflow_run`) get read-only cache access by default; a write-capable `cache-mode` there reopens cache poisoning. Leave it unset.
- Watch for eviction thrash: when the repository nears its cache limit, caches churn. Delete PR caches on PR close or cut cache size; raising the limit is a billing decision.

## Dependency caches

Key every cache on OS + arch + lockfile hash, with a `restore-keys` prefix fallback. Including `runner.arch` keeps x86 and ARM caches apart.

```yaml
key: ${{ runner.os }}-${{ runner.arch }}-<ecosystem>-${{ hashFiles('**/<lockfile>') }}
restore-keys: |
  ${{ runner.os }}-${{ runner.arch }}-<ecosystem>-
```

Prefer the setup action's built-in cache over hand-rolled `actions/cache`:

| Ecosystem | Built-in cache | Key file |
| --- | --- | --- |
| npm / pnpm / yarn | `actions/setup-node` `cache: npm\|pnpm\|yarn` (pnpm needs `pnpm/action-setup` first) | `package-lock.json` / `pnpm-lock.yaml` / `yarn.lock` |
| pip | `actions/setup-python` `cache: pip` | `requirements*.txt` |
| Poetry | `actions/setup-python` `cache: poetry` (install Poetry first) | `poetry.lock` |
| uv | `astral-sh/setup-uv` `enable-cache: true` | `uv.lock` |
| Maven | `actions/setup-java` `cache: maven` | `**/pom.xml` |
| Gradle | `gradle/actions/setup-gradle` (dependency + configuration cache) | handled by the action |
| Composer | `ramsey/composer-install` | handled by the action |
| Cargo | `Swatinem/rust-cache` (registry + target) | `Cargo.lock` |
| Go | `actions/setup-go` `cache: true` (modules + `GOCACHE`) | `go.sum` |
| Bundler | `ruby/setup-ruby` `bundler-cache: true` | `Gemfile.lock` |

Hash the lockfile where the ecosystem has one; the manifest does not pin what installs.

## Compiler caches

C, C++, and Rust builds that `rust-cache` does not cover: `sccache` or `ccache` with a cache keyed on toolchain + lockfile, or a remote backend for large teams.

## Docker builds

- Use `docker/setup-buildx-action` and `docker/build-push-action` with `cache-from: type=gha` and `cache-to: type=gha,mode=max`. The GHA backend shares the repository cache limit; large images use a registry cache (`type=registry,ref=<image>:buildcache`).
- On read-only triggers keep `cache-from` and omit `cache-to`; a default-branch `push` build populates the cache.
- Copy the lockfile and install dependencies before `COPY . .`, so source edits keep the install layer cached.
- `RUN --mount=type=cache` survives only on a persistent builder. On hosted runners, persist it with `reproducible-containers/buildkit-cache-dance`, or use a runner with a persistent builder.
- Add `.dockerignore` for `.git`, `node_modules`, and build output.
- Use multi-stage builds with a slim or distroless final stage; smaller images pull faster on deploy.
- Flag `--no-cache` in CI builds: it discards every layer cache.

## Remote build caches

Turborepo, Nx, and Bazel cache task outputs keyed by inputs and skip unchanged tasks entirely. See [monorepo](monorepo.md).

## When caching hurts

- Hit rate below ~20% (the lockfile changes on most PRs, small dependency tree): restore + save can exceed a fresh install. Measure before keeping it.
- Keys hashing the whole repository or `github.sha` miss on every run.
