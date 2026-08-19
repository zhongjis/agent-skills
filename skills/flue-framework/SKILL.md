---
name: flue-framework
description: |
  Develop applications on the Flue framework — the Astro team's open agent framework (built on Pi) for building TypeScript AI agents with a React-like hooks API. Use when creating, building, running, or deploying Flue agents; when a repo has `@flue/runtime`, `@flue/cli`, `@flue/vite`, `flue.config.ts`, a `'use agent'` module, or `src/agents/`; when writing `useModel` / `useTool` / `useSkill` / `useSandbox` / `createAgentRouter`; when using `flue init` / `flue run`; or when deploying a Flue agent to Node, Cloudflare Workers, or GitHub Actions.
---

# Developing on Flue

Flue is the Astro team's open agent framework, built on [Pi](https://pi.dev). You write AI agents as **TypeScript functions with a React-like hooks API**, run them locally with `flue run`, and deploy them anywhere — Node.js, Cloudflare Workers, or CI (GitHub Actions / GitLab CI). Requires **Node.js >= 22.19.0** and an LLM provider API key.

## When to use this skill

Building, running, or deploying a Flue agent, or working in any repo that imports `@flue/runtime` / `@flue/cli` / `@flue/vite`, has a `flue.config.ts`, or has a module beginning with `'use agent';`.

## Prefer the CLI docs over this snapshot

This skill is a thin guide, not a copy of the docs: it teaches Flue's mental model and CLI, then routes you to the **version-matched documentation bundled in the CLI** for every authoritative detail. Once `@flue/cli` is installed, browse the docs offline — they always match the installed packages, so prefer them over web URLs or any snapshot:

- `npx @flue/cli docs` — list every documentation page
- `npx @flue/cli docs search <query>` — search the docs (JSON results)
- `npx @flue/cli docs read <path>` — print one page as Markdown

> **Use the scoped `@flue/cli`, not a bare `flue`.** An unrelated 2022 npm package named `flue` (a Firebase/Elasticsearch daemon) also ships a `flue` binary. `flue …` / `npx flue …` only reach the framework CLI **inside a project where `@flue/cli` is a dependency** (npx and the package `scripts` resolve the local `node_modules/.bin/flue` first). In any other directory `npx flue …` downloads and runs the wrong package. Standalone, always spell out `npx @flue/cli …`.

Confirm any API, hook signature, flag, config field, model specifier, or version requirement with `docs search` / `docs read` before writing code — don't copy those from memory or a snapshot, which drift from the installed version.

## Mental model (read once, then build)

- The one primitive is an **agent**: an *exported, capitalized* function whose returned string becomes the agent's system instructions. It **re-renders every turn**, like a React component.
- A module becomes an agent module with the **`'use agent';` directive** — a plain string literal at the very top of the file, before imports.
- **Hooks** (all named `use*`, called at the top of the agent function) attach capabilities: `useModel` (required), `useTool`, `useSkill`, `useSandbox`, `usePersistentState`, `useSubagent`, and more.
- The agent function's **name is its durable identity** — it keys conversation storage. Rename the function and you migrate its storage, unless you pin `MyAgent.agentName = 'my-agent'`.
- A **bounded job is a tool** the agent calls — not a separate primitive. Flue has **no workflow primitive**; `defineWorkflow` does not exist. A **durable conversation** is the only durable unit; continue one by reusing its id.
- `flue run` (local / CI) and an HTTP server are **equally first-class** ways to ship an agent. `flue run` is complete for personal tools, cron, and CI — not a lesser fallback for a "real" server.

## The minimal agent (every agent follows this shape)

```ts
// The `'use agent'` directive marks this module's exported functions as Flue agents.
'use agent';
import { useModel } from '@flue/runtime';

export function Assistant() {
	useModel('anthropic/claude-haiku-4-5'); // example specifier — look up current ones: docs read guide/models
	return 'You are a helpful assistant. Keep replies short.';
}
```

`flue.config.ts` at the project root selects the runtime target:

```ts
import { defineConfig } from '@flue/runtime/config';

export default defineConfig({
	target: 'node', // or 'cloudflare'
});
```

## Golden path: scaffold, don't hand-write

Let `flue init` write the project shell; then customize the generated starter. **Do not hand-author** `flue.config.ts`, `package.json`, `tsconfig.json`, `vite.config.ts`, or `src/app.ts` — hand-writing is only for folding Flue into files that already existed before `init`.

1. **Scaffold.** An agent shell has no TTY, so always pass `--target` explicitly (omitting it errors with "cannot prompt here"):
   ```
   npx @flue/cli init <directory> --target <node|cloudflare> [--deploy]
   ```
   Writes `flue.config.ts`, `package.json`, `tsconfig.json`, `.gitignore`, `.env`, `src/agents/hello.ts`, `AGENTS.md`, `README.md` — plus `vite.config.ts` + `src/app.ts` for `--deploy`/Cloudflare, and `src/db.ts` (Node) or `src/cloudflare.ts` + `wrangler.jsonc` (Cloudflare). It **writes files only — never installs dependencies**. Into a non-empty dir it refuses without `--force`, and `--force` overwrites *every* skeleton file — never pass it where the user has files to keep (scaffold into a subdir and fold in by hand instead).
2. **Install & set secrets.** `npm install` (or the detected package manager). Put real API keys in `.env` (e.g. `ANTHROPIC_API_KEY="..."`). **Never invent keys** — `init` writes an empty placeholder; ask the user for the value.
3. **Customize the starter.** Rename `src/agents/hello.ts` and its exported `Hello` function to the agent's purpose (function name = durable identity). Replace the `useModel(...)` specifier and the returned instruction. Add hooks/tools as needed. For `--deploy`, update `src/app.ts`'s import + `app.route(...)`; for Cloudflare, update `wrangler.jsonc`'s `new_sqlite_classes` entry to `Flue<NewName>Agent`.
4. **Run locally (primary smoke test)** — inside the scaffolded project the local `flue` bin resolves, so `npx flue …` works here:
   ```
   npx flue run src/agents/<name>.ts --message "Say hello in five words or fewer."
   ```
   Add `--id <conversation-id>` to continue the same conversation across invocations. Loads `.env` automatically.
5. **Verify.** Run the generated `check:types` script; for `--deploy`, `vite build`. Full deploy path: `npx @flue/cli docs read guide/deploy` (then `ecosystem/deploy/<target>`).

## Requirements & guardrails

- **Node.js >= 22.19.0.** LLM provider API key(s) in `.env`.
- There is **no `flue dev` and no `flue build`** — deployed servers use **Vite**: `npx vite dev` (local, hot-reload) and `npx vite build` (production). `flue run` is CLI-only, one module, no HTTP server, and never loads `app.ts`.
- Never invent API keys or secrets; keep `.env` a placeholder until the user fills it.
- **The `flue` binary is project-local.** `npx flue …` / the `scripts` in a scaffolded `package.json` only work because `@flue/cli` is installed in that project. Outside a Flue project, `npx flue …` resolves an unrelated 2022 npm package (a Firebase daemon) — spell out `npx @flue/cli …` instead.

## Pattern → doc page

Reach for the docs (`docs search` / `docs read`, above) for any API or detail; this maps common tasks to the page to read:

| To… | `docs read` |
|---|---|
| Understand the agent model & hooks | `guide/building-agents`, `guide/agent-hooks`, `reference/agent-hooks-api` |
| Pick / tune / connect a model (current specifiers) | `guide/models`, `reference/provider-api` |
| Give the agent a tool (incl. `harness` / `durable`) | `guide/tools` |
| Mount a reusable skill | `guide/skills` |
| Give the agent a filesystem / shell | `guide/sandboxes`, `ecosystem/sandboxes/<provider>` |
| Delegate to a child agent | `guide/subagents` |
| Serve agents over HTTP (`app.ts`) | `guide/routing`, `reference/streaming-protocol` |
| Build a chat UI / call a deployed agent | `guide/react`, `sdk/overview`, `sdk/flue-client` |
| Persist conversations | `guide/database`, `guide/durability` |
| Run on a schedule / from a webhook | `guide/schedules`, `guide/channels` |
| Deploy | `guide/deploy`, `ecosystem/deploy/<node\|cloudflare\|github-actions\|…>` |
| CLI flags & exit codes | `cli/overview`, `cli/init`, `cli/run` |

## Conventions & gotchas the docs won't shout

See **`references/gotchas.md`** — the structural conventions and copy-paste traps that page-level docs don't surface prominently (binary-name collision, deploy = Vite not `flue`, `flue run` never loads `app.ts`, Cloudflare's per-agent migration triple, prompt-cache invalidation, and "look up model IDs / version pins, don't copy them from memory").
