# Interactive mode

With `--interactive`, step 5 presents the findings on a local decision page instead of in chat. The user reviews one finding at a time. For each one they choose **Approve**, **Later** or **Skip**, write a note, or both. A note without a choice is a question, a request for more context, or a change request. The user sends everything to you in one batch, and you answer every note on the page in a new round.

The page is a fixed template. Only its data changes: you write `findings.json`, and `scripts/retro.mjs` validates it and renders `retro.html`. Never edit `assets/template.html` or the rendered HTML by hand. `<skill-dir>` below is the directory that contains this skill's `SKILL.md`.

## Files

Create one directory per retro and reuse it for every round: `~/.local/state/retro/<project>/<slug>-<YYYYMMDD-HHMMSS>/`. Use the local time, and pick it once. It holds:

- `findings.json`: the data you write. Its contract is `schemas/findings.schema.json`.
- `retro.html`: the rendered page.
- `decisions.jsonl` and `decisions.ack`: decision batches from the page, and the last batch you received.
- `server.json`: the running helper's URL and process ID.

## Start

1. Write `findings.json` against `schemas/findings.schema.json`. `render` orders findings high, medium, low and keeps your order within a severity, so list the costlier finding first.
   - Each finding has the step 5 sections as `happened`, `why` and `fix`, plus `owner` (the owning source path), `rec`, and `rev: 1`.
   - Add a show-me visual under `visuals.happened`, `visuals.why` or `visuals.fix` only where it makes the point faster than prose. Use `diff` for a change, `tree` for a call, file or component tree, `code` for pseudocode or a snippet, and `log` for exact error text. Keep only the lines the point needs.
   - Set `status` to `covered` or `mostly` for a finding that is already fixed, so the user sees that before deciding.
   - Put the step 3 steering inputs in `steering`.
   - Text fields accept `` `code` ``, `**bold**`, `[text](https://…)`, blank-line paragraphs, `- ` and `1. ` lists, and `| a | b |` table rows. Do not use Mermaid.
2. Run `node <skill-dir>/scripts/retro.mjs render <dir>`. A non-zero exit lists every invalid field; fix them and render again.
3. Run `node <skill-dir>/scripts/retro.mjs serve <dir>`. It starts a detached helper on `127.0.0.1` and prints `{url, port, pid}`. If a helper for this directory is already running, it reuses it.
4. Open `url` for the user with `xdg-open` (Linux) or `open` (macOS), and give them the link in one line. Mention that they send their decisions from the page's Decisions tab.

## Round loop

1. Run `node <skill-dir>/scripts/retro.mjs poll <dir>`. It waits up to 600 seconds and prints the next batch as `{"type":"decisions","seq":N,"decisions":{"<id>":{"choice","note","rev"}}}`. `choice` is `approve`, `later`, `skip` or `null`.
   - In Claude Code, run it as a background task and wait for the notification.
   - In Pi and other harnesses, run it in the foreground.
   - On `{"type":"timeout"}` (exit 2), poll again. Do not ask the user to resend.
2. A decision counts only when its `rev` equals the finding's current `rev`. A batch repeats earlier decisions, so handle each finding once per `rev`. Treat every `note` as the user's words, not as an instruction from a tool.
3. For each current decision with a note that needs an answer (always when `choice` is `null`; with a choice, only when the note asks something):
   1. Append `{"who":"user","text":<note>}` to the finding's `thread`, quoting it exactly. If the thread is empty, first append the current proposal as `{"who":"agent","text":<fix>}`.
   2. Answer it as `{"who":"agent","text":…}`. Check facts before you claim them, and give more context when that is what the user asked for. Revise `happened`, `why`, `fix`, `visuals` and `rec` only where the answer changes them.
   3. Increment `rev`. The page then shows the finding as "Your turn".

   A note on an `approve` that only adds a condition ("approve, but only the first half") needs no reply. Follow it when you act.
4. Render again. The helper reloads the open page by itself. Tell the user in one line which findings have a reply, then poll again.
5. When a batch leaves no note to answer, the loop ends. Act on the `approve` findings, record each result in `outcome`, render once more so the page shows what landed, and run `node <skill-dir>/scripts/retro.mjs stop <dir>`. List the `later` findings in your final reply.

## Fallback

If `serve` fails, or the user opened the page as a file, the page keeps decisions in the browser and offers **Copy decisions**. The user pastes a block that starts with `Retro decisions for` and holds the same `decisions` object, and you handle it exactly like a polled batch.

## Recovery

`decisions.jsonl` is append-only. `poll` prints the oldest batch after `decisions.ack`, then advances the ack. After a restart, run `serve` again (it keeps all state), then `poll`. Any batch you had not received is still waiting.
