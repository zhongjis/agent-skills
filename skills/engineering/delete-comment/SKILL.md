---
name: delete-comment
description: Delete code comments in a repository path, file an issue for each hack a comment excused, and move still-true decisions into ADRs. Use for /delete-comment, when a comment ratchet baseline should shrink, or when a comment check rejects a new comment.
---

# Delete comments

Code carries no comments. A decision lives in an ADR, a hack lives in an issue, and everything else is visible in the code. A **comment ratchet** keeps it that way: a check that fails when a file holds more comments than its count in a checked-in baseline, or fewer until the baseline is lowered, so the baseline only shrinks.

The argument is a repository path. With no argument, use every file the baseline lists.

## Find the ratchet

Look for the repository's comment check in its lint scripts and enforced-rules docs. The check owns which files are exempt and which comments are directives a tool reads (`biome-ignore`, `@ts-expect-error`, test-environment pragmas, required marker notes). It needs three modes: list comments as records with file, line and text; delete them and lower the baseline; lower the baseline alone. Xiangxi's is `scripts/check-comments.mjs` with `--list`, `--delete` and `--update`.

When the repository has no ratchet, stop and ask whether to add one. A ratchet finds comments with the language parser, not a regex, so comment-like text in strings, regular expressions and markup is safe.

## Steps

1. **List.** List the comments in the path and save the records to a scratch file. They are the only copy once the comments are gone.
2. **Classify.** Read each comment with its surrounding code and put it in one category:
   - **Tautology**: it repeats what the code already shows.
   - **Stale**: it describes code or behavior that no longer matches. Check the code before choosing this.
   - **Excuse**: it justifies a hack, workaround, known gap or TODO that the code should fix.
   - **Decision record**: it explains a non-obvious, still-true choice whose loss would plausibly lead someone to break the code.

   A plain description of what code does is a tautology. For more than about 100 comments, split the records by workspace and give each part to a subagent with these definitions; it reads the original code from `HEAD` and writes its verdicts to a file.
3. **Delete.** Run the ratchet's delete mode, then the formatter on the path. Review every line the deletion rewrote rather than removed: a trailing or inline comment shares its line with code.
4. **Excuses.** Group excuses that share a root cause. Draft one issue per group with the problem at `file:line` on the commit before deletion, the proper fix and acceptance criteria. Follow the repository's issue-tracker guide.
5. **Decisions.** Group decision records by topic and area. Add each one to the ADR that owns the topic, or draft a new ADR in the repository's ADR format.
6. **Verify.** Run the ratchet, its own tests, the linter and the type checker for each touched workspace, then the focused tests of those workspaces.

## Decision boundary

- Inside: deleting comments in the requested path, lowering the baseline, formatting and running checks. These change no behavior.
- Outside: filing issues, writing ADR text and adding exemptions to the ratchet. Show the drafts and wait for the user on each one.
- Keep every baseline count at or below its current value. When a change seems to need a new comment, record the reason in an ADR, an issue or a clearer name.

## Done

The run is done when the ratchet passes, every touched workspace type-checks and lints, and the handoff lists the comments deleted per category, the issue and ADR drafts with their approval state, and the comments left in the baseline with the reason each one stays.
