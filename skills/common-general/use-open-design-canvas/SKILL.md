---
name: use-open-design-canvas
description: Commission, inspect, supervise, and refine Open Design canvas work through its MCP server.
argument-hint: "[what to generate, inspect, or refine]"
disable-model-invocation: true
adaptedFrom:
  - "https://github.com/nexu-io/open-design/blob/main/apps/daemon/src/mcp.ts#L530-L604"
  - "https://github.com/nexu-io/open-design/pull/3141"
---

# Use Open Design Canvas

Treat Open Design as a commissioned design engine. Ground the brief outside Open Design, then let its run pipeline generate or refine the artifact.

## Commissioning loop

### 1. Resolve the branch

Choose one branch:

- **Generate** — create a new canvas artifact.
- **Refine** — change an artifact in an existing Open Design project.
- **Inspect** — read an existing artifact without changing it.

Resolve the active context first with `open-design.get_active_context({})`. After resolving a project, pass its explicit ID as `project` to later project-scoped calls; the MCP argument is `project`, not `projectId`. If a request for a deck, document, or PDF could mean either browser-viewable output or a binary file, ask which deliverable the user wants before commissioning work.

For Inspect or Refine, if active context is absent, expired, or not the requested project, call `open-design.list_projects({})` once. Resolve an exact project ID; when multiple candidates remain, ask the user to choose before continuing.

Completion: branch and explicit project ID are known, or Generate is confirmed to need a new project.

### 2. Ground the evidence

Before Generate or Refine, inspect the real source of truth available to the outer agent: live UI, repository, screenshots, existing artifact, design tokens, and user constraints. Distill only facts that affect the canvas:

- exact copy, fields, controls, states, and behaviors
- target viewport and responsive behavior
- design-system or component constraints
- regions that may change and explicit exclusions
- reference evidence versus inferred assumptions

Ask one focused question when missing evidence would change the artifact. Label unavoidable assumptions. Keep credentials at the outer-agent boundary: use an existing authenticated browser session or ask the user to log in, and exclude passwords, API tokens, cookies, session values, and private keys from prompts and plugin inputs.

Completion: the brief can be executed without inventing product facts.

### 3. Resolve the recipe

Keep Open Design namespaces separate:

| Value | Where it belongs |
|---|---|
| design-system ID | `open-design.create_project` → `designSystem` |
| skill ID | `open-design.create_project` → `skill`, or `open-design.start_run` → `skill` |
| plugin ID | `open-design.start_run` → `plugin` |
| plugin inputs | `open-design.start_run` → `inputs` |
| agent/model override | `open-design.start_run` → `agent` / `model` |

Use a user-specified plugin or skill directly. If its ID is rejected or no recipe was specified, make one namespace-specific discovery call: `open-design.list_plugins({})` or `open-design.list_skills({})`. Do not dump both catalogs. Omit agent and model by default; when the user requests an override, call `open-design.list_agents({})` and choose only an available returned value. If plugin input fields are unknown, omit `inputs` and put grounded evidence in `prompt` rather than inventing an input schema.

Completion: each selected ID has one namespace and no catalog call remains necessary.

### 4. Establish the project

For Inspect and Refine, reuse the resolved project. For Generate, call `open-design.create_project({ name, id?, designSystem?, skill? })` only when no suitable project exists. A plugin ID is not a design-system ID; attach only explicitly resolved design-system or skill IDs during project creation.

If project resolution used a name substring, verify the returned project ID and name before continuing.

Completion: one explicit project exists; no duplicate project was created.

### 5. Execute the branch

**Inspect**

1. Call `open-design.get_artifact({ project: "<id>" })`.
2. Use `open-design.search_files({ project: "<id>", query })` or `open-design.get_file({ project: "<id>", path })` only for a narrow follow-up.
3. Report findings without starting a run.

**Generate or Refine**

1. Compose one evidence-grounded prompt. Put locked scope and exact product facts before visual preferences.
2. For Refine, name the existing artifact and require an in-place correction in the same project.
3. Call `open-design.start_run({ project: "<id>", prompt, skill?, plugin?, inputs? })` with the resolved skill or plugin. Pass plugin inputs only when their fields are known and useful.
4. Surface `studioUrl` immediately as a clickable Markdown link when returned.

Completion: Inspect has the requested artifact bundle, or Generate/Refine has a `runId` tied to the intended project.

### 6. Supervise the run

Poll `open-design.get_run({ runId })` every 30–60 seconds until status is terminal. `get_run` takes only `runId`. Five to thirty minutes can be normal. A running status with unchanged file timestamps means the inner agent may still be thinking. Use `eventsLogPath` for progress evidence when returned.

Continue waiting while status is `queued` or `running`. Call `open-design.cancel_run` only when the user explicitly asks to abort. If the inner agent asks a clarifying question, relay it to the user and continue in the same project after the answer.

Completion: status is `succeeded`, `failed`, or `canceled`.

### 7. Verify and deliver

On success:

1. Call `open-design.get_artifact({ project: "<id>" })`.
2. Compare the artifact against every locked scope item and exact product fact from Step 2.
3. If correction is needed, commission another Refine run in the same project; design changes stay inside the Open Design run pipeline.
4. Return the project ID, terminal status, clickable `studioUrl`, `previewUrl` when present, concise `agentMessage`, and any verification gap.

On failure or cancellation, report terminal status, exact error, and `agentMessage`. Preserve the project for diagnosis; do not create a replacement project or substitute a direct file write.

Completion: an artifact exists and satisfies the grounded brief, or the user has an exact terminal failure report.

## Failure routing

- Open Design MCP unavailable: stop with the exact connection/tool error; do not silently switch to CLI or HTTP.
- Invalid plugin, skill, or design-system ID: keep the namespace fixed, discover that namespace once, then retry with the corrected ID.
- Missing artifact during Inspect: report absence and offer Generate.
- Unexpected resolved project: stop before mutation and confirm the project with the user.
