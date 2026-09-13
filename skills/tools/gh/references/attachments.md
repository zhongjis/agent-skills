# PR and comment attachments

## Prerequisites

- Native `--attach` requires gh 2.99.0 or later; no extension is needed. [1]
- Use GitHub.com or GitHub Enterprise Cloud, not GitHub Enterprise Server. Uploading requires repository push/write access and documented OAuth authentication (`gh auth login`) or a classic PAT. [6]
- Attach images or videos, not arbitrary files. Consult the official [attachment guide](https://docs.github.com/en/github-cli/github-cli/attaching-files-with-github-cli) for current supported types and size limits. [2]

## Placement and alt text

`gh pr create`, `gh pr edit`, and `gh pr comment` accept repeated `--attach` flags (up to 50 files); the same file cannot be attached twice in one command. Quote `'file.png#Image alt text'`; the filename is the default alt text, and existing Markdown alt text takes precedence over the flag. [3][4][5]

A matching local image path in the body is rewritten to its uploaded URL. Attachments without a matching body reference are appended in flag order. `--body-file` preserves your supplied Markdown layout, but on edit it **replaces the existing body**. To preserve the current PR body and append media, pass only `--attach`, with no body option. [3][4][5]

Videos cannot use `#alt text`. A standalone `![](clip.mp4)` paragraph renders a player; a video referenced inline in a sentence renders as a link. [2]

## Create with before/after images

Prepare `body.md` with local paths matching the attachments: [2][3]

```markdown
## Before

![Original settings panel](before.png)

## After

![Updated settings panel](after.png)
```

Create the PR; the uploaded URLs replace the local paths without moving the sections: [3]

```bash
gh pr create --title "Update settings panel" --body-file body.md \
  --attach before.png --attach after.png
```

## Append or comment

Append an image while keeping the existing PR body: [4]

```bash
gh pr edit 123 --attach 'after.png#Updated settings panel'
```

Post a comment with an image: [5]

```bash
gh pr comment 123 --body "Verified the updated layout." \
  --attach 'after.png#Updated settings panel'
```

## Recover before retrying

Create/edit may partially succeed despite a nonzero exit status: some uploads can succeed, and the PR URL is printed to stdout. [3][4] Inspect the existing PR before retrying; inspect comments when the attempted upload was a comment:

```bash
gh pr view 123 --json body,url
gh pr view 123 --comments
```

Retry only missing attachments on the existing PR. For a partially posted comment, identify and edit that comment rather than posting another. If the target is unclear, stop and inspect it in the browser. Never recreate a PR or comment merely because the upload command failed; this is a recovery guardrail, not an idempotency guarantee.

## Sources:

[1] GitHub CLI v2.99.0 release (https://github.com/cli/cli/releases/tag/v2.99.0)
[2] Attaching files with GitHub CLI (https://docs.github.com/en/github-cli/github-cli/attaching-files-with-github-cli)
[3] gh pr create manual (https://cli.github.com/manual/gh_pr_create)
[4] gh pr edit manual (https://cli.github.com/manual/gh_pr_edit)
[5] gh pr comment manual (https://cli.github.com/manual/gh_pr_comment)
[6] GitHub CLI media announcement (https://github.blog/changelog/2026-09-01-github-cli-media-in-issues-pull-requests-and-comments/)
