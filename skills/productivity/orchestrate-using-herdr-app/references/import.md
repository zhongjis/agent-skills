# Pull-only import and first dispatch

Planning sources remain authoritative. Import only the agreed tickets and their blocking links, never a tracker backlog, unrelated relation, or remote planning parent. No tracker sync, push, Dolt push, or ticket close-out comment.

## Import the agreed set

1. Resolve each ticket's tracker and canonical URL. A bare key is ambiguous between Jira and Linear; use the agreed tracker, never guess. Native Jira pull reads the configured `jira.url`, so the script refuses a Jira URL on any other site. Export `ORCH_EPIC` and `HC_TERMINAL_ID` from init. Run one ticket at a time:

   ```bash
   scripts/import-ticket.sh linear https://linear.app/team/issue/ENG-42 --key eng-42
   scripts/import-ticket.sh jira https://jira.example/browse/ENG-42 --key eng-42
   scripts/import-ticket.sh github https://github.com/owner/repo/issues/42 --key gh-42
   ```

   Keep the returned `bead=<id>`. This script is the only owner of native pulls: `bd <tracker> pull <ticket-id> --json`, plus `--relations` for Linear. GitHub gets `GITHUB_TOKEN` from `gh auth token` and owner/repo from that issue URL for each pull. It looks up `external_ref` before pulling, reconciles a matching key-only local child by assigning that reference before its first pull, and refuses ambiguous or duplicate identities. Do not create a second bead for the same ticket.
2. Read the full ticket and its blocking links through the tracker MCP or `gh`. Native selective pulls do not fetch missing relation endpoints. Import an outside blocker with the same script and `--blocker`: it keeps remote state and stays outside the session epic. Import agreed prerequisites normally. After all endpoints exist, add each blocking edge with `bd dep add <dependent> <prerequisite>`; for Linear, re-import the agreed ticket to resolve native relations against those endpoints. Never import an unrelated relation just to resolve a missing endpoint. For Jira, the pulled description is only an index: read the full ticket through Jira MCP when defining work, and add its blocking edges manually.
3. The session epic remains the agreed task bead's parent, even when Linear supplies another parent. The script removes remote parent edges and adds that planning reference to the epic's `source` metadata, a space-separated set that keeps earlier references. Dependencies and comments are safe before re-pull; task metadata and claims are not.
4. Claimed beads are never pulled; the script re-checks before every pull, including the retry. A claim is an assignee with a local role prefix (`o-`, `h-`, `w-`, `r-`); any other assignee came from the tracker. A bead under another open session epic with a live terminal is a conflict: stop and report. A missing/finished terminal requires the user's yes before rerunning with `--adopt <old-epic>`; adoption records `event=adopted from=<old-epic>`. Never adopt an epic. Only `hc get` state `finished` or exit 3 (not found) counts as gone; any other error or response is uncertain and stops. Do not retry it as a missing terminal.

## Re-pull, then claim

A task bead is dispatchable when it is not `closed` and every `blocks` prerequisite is `closed`; its pulled status may be `open`, `in_progress`, `blocked`, or `deferred` from the tracker map. `bd ready` excludes non-open beads, so list candidates with `bd list --parent "$ORCH_EPIC" --limit 0 --json` (the default limit is 50), check prerequisites with `bd show <bead> --json` (`dependencies[]` with `dependency_type == "blocks"`), and wait for a free worker slot. A queued task receives its re-pull only when it can first dispatch, not when its blocker merely reports a commit. Prerequisites close only on a verified target merge SHA, or successful settlement for non-merge work.

Immediately before first dispatch, run:

```bash
scripts/import-ticket.sh linear https://linear.app/team/issue/ENG-42 --key eng-42 --dispatch w-eng-42
```

The script snapshots title/description, re-pulls, records a changed body in a local comment, checks that every `blocks` prerequisite is closed, then claims. Native `--claim` refuses a non-open or assigned bead, so when the pulled bead is not open and unassigned the script first runs `bd update <bead> --status open --assignee '' --if-status <observed status> --if-assignee <observed assignee>`, then `bd update <bead> --claim --actor w-<key>`. That prep bumps `updated_at`; this is safe because no pull follows a claim. Build the task definition from the new title/body, not the original snapshot; read Jira's full refreshed ticket through MCP. Only after claim write the description, acceptance and design fields and the worktree/branch/base metadata ([delegation-contract.md](delegation-contract.md)), then start the worker with `scripts/start-worker.sh <name> <worktree> <bead>`. The script sets `key` after claim for `status.sh`; add later metadata with `--set-metadata` so it survives. Worker names may append a slug (`w-eng-42-cache`); the claim actor stays `w-eng-42`. Pass `w-eng-42` to the import script, then use the longer name only for worker startup.

A remote done/cancelled ticket maps to `closed`: the script marks the bead `blocked`, records the reason, and stops. Ask the user before doing any work on it. A failed pull, a held pull, a non-ready bead, or a race also stops dispatch. A race is exit 13 on the guarded prep or a failed claim: the script writes nothing more and reports. Never re-pull for a re-instruction or pull a bead already owned by a worker.

`--claim` is already atomic and cannot combine with `--if-status` on bd 1.3.4. Another actor's claim fails with `issue already claimed by <actor>`, exit 1, and writes nothing. Native claims also reject `closed`, `blocked`, `deferred`, and `in_progress` without writes. Prerequisites are checked before claim, but a dependency can still change between that read and the atomic claim; claim does not validate the dependency graph.

Pulled statuses are never normalized: on bd 1.3.4 every status write bumps `updated_at`, and a native pull skips a bead whose `updated_at` is after the tracker's `last_sync`. A pull also reports `skipped` when the content is unchanged. bd shows `last_sync` only in a pull's JSON, so the script pulls once more after a first skip. A second skip whose bead `updated_at` is at or before the first pull's `last_sync` means unchanged, and dispatch proceeds. Otherwise a local write may hide a remote change: the script records `event=blocked reason=pull-skipped`, sets `blocked_reason=pull-skipped` metadata, holds the bead, and stops. Report it; never forge timestamps or `last_sync`. Do not write task metadata before this re-pull.

## Pull a published follow-up

After the user approves publication and the new ticket exists, record its canonical URL as the existing follow-up bead's `external_ref`. Use `scripts/import-ticket.sh <tracker> <url> --blocker` for its parentless, no-dispatch pull. Keep the original ID and verify the returned `bead=` matches it. Only use this path for a new ticket with no remote relations. Native pull may overwrite status, labels, metadata, and assignee: restore `deferred`, label `follow-up`, and the original `repo` and `session` metadata on the same bead, clear any remote assignee, and verify the `discovered-from` links remain. After a failed pull, inspect the bead and leave it deferred before reporting the failure. Do not use this path to adopt or claim the bead.

## Lark and local specs

For a Lark document or `docs/specs` source, import by hand: look up its exact `external_ref` with `bd list --external-ref <source> --all --limit 0 --json`, enforce one matching task bead, then create or update it with that reference. Apply the same conflict/adoption rules before writes. Use the document URL or canonical repository/spec reference consistently across sessions. Read only the agreed work and its blockers, attach the session epic with a dependency edit, and add native blocking edges.

Immediately before first dispatch, reread the source, compare title/body, comment on changes, and update the existing bead. Stop and ask on withdrawn work. Check native status/readiness, then claim with the same native command above; local ad-hoc work follows this claim path without a remote pull. Reports and notes stay local.
