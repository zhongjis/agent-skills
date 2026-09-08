# Conventions & gotchas

Durable, non-versioned facts that the version-matched `flue docs` pages don't always surface at the top. For any actual API, signature, flag, or config value, still read the page — `npx @flue/cli docs read <path>`. These are the conventions and traps *around* that reference.

## CLI & the `flue` binary

- **Scope the binary.** `@flue/cli` provides a `flue` bin, but an unrelated 2022 npm package is *also* named `flue` (a Firebase/Elasticsearch daemon). `flue …` / `npx flue …` reach the framework only **inside a project where `@flue/cli` is installed** (the local `node_modules/.bin/flue` wins). Standalone, spell out `npx @flue/cli …`. A scaffolded `package.json`'s `scripts` run the local bin, so they're fine in-project.
- **`flue init` writes files, never installs.** Run `npm install` yourself afterward. `--force` overwrites *every* skeleton file (not just config) — don't use it where the user has files to keep; scaffold into a subdir and fold in by hand instead. → `cli/init`, `guide/project-layout`.
- **`flue run` runs one module locally and never loads `app.ts`.** A module importing `cloudflare:*` fails under it (use `vite dev` for that). → `cli/run`, `guide/workflows`.
- **There is no `flue dev` / `flue build`.** Vite owns the server pipeline: `vite dev` (local, hot-reload) and `vite build` (production). → `guide/deploy`, `reference/configuration`.

## Agents

- **The `'use agent';` directive** (a plain string literal at the top of the file, before imports) only matters for the Vite deployable build, which scans marked files and registers their exported, capitalized functions. `flue run` takes a module path directly and does not need it. → `guide/building-agents`.
- **The exported function name is the agent's durable identity** — it keys conversation storage. Rename it and storage migrates, unless you pin `MyAgent.agentName = 'my-agent'`. → `reference/agent-api`.
- **No `defineWorkflow` primitive.** Model a bounded job as a *tool*; make it durable with a durable tool's `step.do(...)`. "Workflows" in Flue means *driving* agents from programs (CLI runs, scripts, the SDK), not a workflow-definition API. → `guide/workflows`, `guide/tools`, `guide/durability`.
- **Changing the *set* of tools / skills / sandbox between renders invalidates the provider's prompt cache.** Gate optional capabilities on rarely-changing persisted state, not per-turn conditions. → `guide/agent-hooks`, `guide/tools`.

## Deploy — Cloudflare

- **Adding an agent is a triple:** the `'use agent'` module, its `app.route(...)` mount, and a tagged Durable Object migration. The build emits one DO class per agent named `Flue<Name>Agent` with binding `FLUE_<NAME>_AGENT`; use `new_sqlite_classes` (not `new_classes`). Look up the current `compatibility_date` / `compatibility_flags` requirements from the docs rather than hardcoding from memory. → `ecosystem/deploy/cloudflare`, `guide/cloudflare-target`.

## Don't copy version-specific values from memory

- **Model specifiers, `compatibility_date`, Node version floors, and package versions are version-specific.** Look them up — don't paste a specific `anthropic/claude-…` / `openai/gpt-…` id from memory or an old snapshot. Get current specifiers from `npx @flue/cli docs read guide/models` or `https://flueframework.com/models.json`; config requirements from `reference/configuration`.
- **Never invent API keys or secrets.** `flue init` writes an empty `.env` placeholder; ask the user for real values.
