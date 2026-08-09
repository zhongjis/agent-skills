---
name: splunk
description: >
  Operate a live Splunk instance from the terminal via the `splunk-as` CLI, and
  author efficient SPL. Use this skill whenever the user mentions Splunk, SPL,
  searching or analyzing logs, debugging production issues through logs, search
  jobs/SIDs, exporting search results, indexes/sourcetypes, saved searches or
  scheduled reports, alerts, lookups/CSV enrichment, KV Store, metrics
  (mstats/mcatalog), dashboards, ITSI, or Splunk license/cost — even when they
  don't say "Splunk" explicitly but clearly mean "find X in the logs", "why is
  service Y erroring", "build a report on Z", or "what's eating our license".
  Covers running searches, writing/optimizing SPL, managing jobs and exports,
  and Splunk architecture/cost guidance.
compatibility: >
  Requires the `splunk-as` CLI (PyPI: `splunk-as`) and connection env vars
  (`SPLUNK_SITE_URL` plus `SPLUNK_TOKEN`, or `SPLUNK_USERNAME`/`SPLUNK_PASSWORD`).
  Talks to a real Splunk instance over the management API (port 8089).
adaptedFrom:
  - https://github.com/grandcamel/Splunk-Assistant-Skills
  - https://github.com/chrishuffman5/domain-expert/tree/main/skills/monitoring/splunk
---

# Splunk

Drive a live Splunk Enterprise or Splunk Cloud instance through the `splunk-as`
command-line tool, and write SPL (Search Processing Language) that is correct,
cheap, and fast. The CLI handles authentication, the REST API, paging, and
output formatting so you can focus on the query and the answer.

This skill bundles two things:

- **Operations** — one `splunk-as` command group per task (search, jobs, export,
  metadata, lookups, saved searches, alerts, metrics, KV Store, apps, security,
  admin, tags). Detailed in `references/`.
- **Knowledge** — deep SPL reference, distributed architecture, and license/cost
  optimization, so the SPL you run is the right SPL.

## Setup (required)

`splunk-as` is the required tool. Verify it is installed and connected before
running anything else:

```bash
splunk-as --version
splunk-as admin info        # confirms connection + auth + deployment type
```

If the CLI is missing, install it. This repo runs on Nix, so prefer an
ephemeral invocation over a global install:

```bash
uvx splunk-as admin info    # ephemeral (no global install) — preferred here
# or, if you want it on PATH:  pip install splunk-as
```

Connection is configured entirely through environment variables — never ask the
user to paste tokens into a command, and never hardcode credentials:

| Variable | Required | Purpose |
|----------|----------|---------|
| `SPLUNK_SITE_URL` | yes | Splunk server URL, e.g. `https://splunk.example.com` |
| `SPLUNK_TOKEN` | auth* | JWT bearer token (preferred) |
| `SPLUNK_USERNAME` / `SPLUNK_PASSWORD` | auth* | Basic-auth alternative to a token |
| `SPLUNK_MANAGEMENT_PORT` | no | Defaults to `8089` |
| `SPLUNK_VERIFY_SSL` | no | Defaults to `true` |
| `SPLUNK_DEFAULT_APP` | no | Defaults to `search` |
| `SPLUNK_DEFAULT_INDEX` | no | Defaults to `main` |

\*Provide either `SPLUNK_TOKEN`, or both `SPLUNK_USERNAME` and `SPLUNK_PASSWORD`.

Add `--output json` (or `-o json`) to most commands for machine-readable output
when you need to parse the result.

## How to approach a task

1. **Classify the request** and load the matching reference (see the map below).
   When in doubt, run a read-only discovery command first (`splunk-as metadata
   indexes`, `splunk-as admin info`) rather than guessing index or sourcetype
   names.
2. **Think SPL-first.** Splunk's power is in SPL. For any data question, write
   the SPL, validate it (`splunk-as search validate "<spl>"`), then run it. Start
   from the most selective filters (indexed fields, then `tstats`) before falling
   back to raw `search`.
3. **Always bound time.** Every search needs `--earliest`/`--latest` (or
   `earliest=`/`latest=` in the SPL). An unbounded search scans the full index,
   wastes the indexers, and can take minutes — this is the single most common
   way to cause a problem on a shared instance.
4. **Pick the right execution mode** (table below) so you don't hold an indexer
   open longer than necessary, and cancel jobs you no longer need.
5. **Respect the safety tiers.** Read-only commands run freely; anything that
   creates, modifies, or deletes needs care and often user confirmation. See
   "Safety" below and `references/safeguards.md`.

## Search execution modes

Choosing the mode is about resource cost and how you'll consume the results.

| Mode | Use for | Returns SID | Waits | Max results |
|------|---------|-------------|-------|-------------|
| `oneshot` | Ad-hoc queries, < 50K rows — the default | No | Inline | 50,000 |
| `normal` | Long-running searches; poll the SID for progress | Yes | Async | No limit |
| `blocking` | Simple queries where you want to wait synchronously | Yes | Sync | No limit |
| `export` | Large extracts / ETL (> 50K rows), streamed to a file | Yes | Stream | No limit |

```bash
# Ad-hoc: inline results, last hour
splunk-as search oneshot "index=main | stats count by sourcetype" -e -1h -l now

# Long search: create + poll
splunk-as search normal "index=main | stats count by host" --wait

# Big extract: stream to disk instead of buffering in memory
splunk-as export stream "index=main | head 1000000" -o results.csv
```

## SPL-first authoring principles

These keep queries correct, cheap, and fast. The "why" matters more than the
rule — apply judgment.

- **Filter early and narrowly.** The cheapest event to process is one the search
  never has to touch. Put index/sourcetype/host filters first; let `where` /
  `eval` run on the already-reduced set.
- **Reduce fields before transport.** Insert `| fields a, b, c` early on wide
  events to cut the data shipped from indexers to the search head.
- **Prefer `stats` over `join`.** SPL `join` is expensive and silently truncates
  (subsearch limit: 10,000 results, 60s). Reach for `stats`/`eventstats` with a
  shared key, or `lookup`, before `join`.
- **Use `tstats` on accelerated data models** for counts/aggregations — often
  10–100× faster than raw search, at no extra license cost.
- **Search-time over index-time.** Field extractions at search time are flexible
  and free; index-time `TRANSFORMS` permanently inflate the index and can't be
  changed retroactively.
- **Be license-aware.** Splunk Enterprise is billed by GB/day indexed. Before
  recommending new data sources or verbose logging, consider the volume impact;
  see `references/cost.md`.

Common pitfalls: unbounded time ranges; real-time searches on high-volume
indexes (use scheduled 5-minute windows); over-using `join`; assuming a
sourcetype was auto-detected correctly.

## Safety

`splunk-as` operations are tiered by blast radius. Treat them accordingly:

| Tier | Meaning | Action |
|------|---------|--------|
| Read-only | search, list, get, metadata, export | Run freely |
| Caution | create/update/enable/disable, lookup upload, tag, insert | Reversible — proceed, note what changed |
| Warning | delete job / saved search / lookup / token / alert / kvstore record | Confirm target; back up first |
| Danger | `app uninstall`, drop a KV Store collection | **Irreversible** — require explicit user confirmation |

Before any destructive action: confirm you're on the intended instance, confirm
the exact resource name, and export a backup where possible (e.g.
`splunk-as savedsearch get "X" -o json > backup.json`). Full recovery
procedures and the per-command risk map are in `references/safeguards.md`.

## Reference map

Load the one reference that matches the task — don't read them all up front.

### Operations (`splunk-as` command groups)

| Read when the task is about… | Reference |
|------------------------------|-----------|
| Running/validating SPL, search modes, results | `references/search.md` |
| Search-job lifecycle: status, poll, pause, cancel, finalize, TTL | `references/jobs.md` |
| Exporting large result sets / streaming to file | `references/export.md` |
| Discovering indexes, sources, sourcetypes, fields | `references/metadata.md` |
| CSV lookups: upload, download, enrichment tables | `references/lookup.md` |
| Saved searches & scheduled reports (CRUD, run, history) | `references/savedsearch.md` |
| Alerts: create, list, triggered, acknowledge | `references/alert.md` |
| Metrics via `mstats` / `mcatalog` | `references/metrics.md` |
| Tags on field/value pairs | `references/tag.md` |
| App install/enable/disable/uninstall | `references/app.md` |
| KV Store collections & records | `references/kvstore.md` |
| Tokens, RBAC, capabilities, ACLs | `references/security.md` |
| Raw REST calls, server info/health/status, users/roles | `references/rest-admin.md` |

### Knowledge

| Read when you need… | Reference |
|---------------------|-----------|
| SPL command reference, subsearch, macros, 15+ worked examples | `references/spl-reference.md` |
| Distributed architecture, forwarders, indexers, buckets, SmartStore | `references/architecture.md` |
| License model, forwarder filtering, summary indexing, cost cuts | `references/cost.md` |
| Ingestion (HEC, syslog, props/transforms), dashboards, alerting, ITSI | `references/platform-config.md` |

### Support

| Read when you need… | Reference |
|---------------------|-----------|
| Risk tiers, pre-op checklists, recovery & emergency procedures | `references/safeguards.md` |
| One-page CLI + SPL + time-modifier + error-code cheat sheet | `references/quick-reference.md` |
