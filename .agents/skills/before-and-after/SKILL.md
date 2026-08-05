---
name: before-and-after
description: Captures before/after screenshots of web pages or elements for visual comparison. Use when user says "take before and after", "screenshot comparison", "visual diff", "PR screenshots", "compare old and new", or needs to document UI changes. Accepts two URLs (file://, http://, https://) or two image paths.
upstream: "https://github.com/vercel-labs/before-and-after/tree/main/skill"
allowed-tools:
  - Bash(npx @vercel/before-and-after *)
  - Bash(before-and-after *)
  - Bash(which before-and-after)
  - Bash(npm install -g @vercel/before-and-after)
  - Bash(*/upload-and-copy.sh *)
  - Bash(curl -s -o /dev/null -w *)
  - Bash(curl -L *)
  - Bash(git remote get-url *)
  - Bash(gh repo view *)
  - Bash(gh pr view *)
  - Bash(gh pr edit *)
  - Bash(gh api *)
  - Bash(vercel inspect *)
  - Bash(vercel whoami)
  - Bash(which vercel)
  - Bash(which gh)
---

# Before-After Screenshot Skill

> **Package:** `@vercel/before-and-after`
> Never use `before-and-after` (wrong package).

## Agent Behavior Rules

**DO NOT:**
- Switch git branches, stash changes, start dev servers, or assume what "before" is
- Use `--full` unless user explicitly asks for full page / full scroll capture

**DO:**
- Use `--markdown` only when user explicitly allows external image upload for PR integration. It uploads images; it is not the right path when the user wants committed images.
- Before adding image markdown to a GitHub PR, check repo visibility with `gh repo view --json nameWithOwner,visibility,isPrivate,defaultBranchRef`. Private/internal repos need different URL handling than public repos.
- Use `--mobile` / `--tablet` if user mentions phone, mobile, tablet, responsive, etc.
- Assume current state is **After**.
- If user provides only one URL or says "PR screenshots" without URLs, **ASK**: "What URL should I use for the 'before' state? (production URL, preview deployment, or another local port)"

## Execution Order (MUST follow)

1. **Pre-flight** — `which before-and-after || npm install -g @vercel/before-and-after`
2. **Protection check** — if `.vercel.app` URL: `curl -s -o /dev/null -w "%{http_code}" "<url>"` (401/403 = protected)
3. **Capture** — `before-and-after "<before-url>" "<after-url>"`
4. **Repo visibility check** — before PR markdown, run `gh repo view --json nameWithOwner,visibility,isPrivate,defaultBranchRef` for the PR repo.
5. **Publish images** — choose from the decision matrix below: external upload, committed public raw URL, committed private GitHub web/raw URL, or GitHub PR attachment.
6. **PR integration** — `gh pr edit` with image markdown, then verify the PR body and image URL behavior before reporting done.

**Never skip steps 1-2.**

## Quick Reference

```bash
# Basic usage
before-and-after <before-url> <after-url>

# With selector
before-and-after url1 url2 ".hero-section"

# Different selectors for each
before-and-after url1 url2 ".old-card" ".new-card"

# Viewports
before-and-after url1 url2 --mobile    # 375x812
before-and-after url1 url2 --tablet    # 768x1024
before-and-after url1 url2 --full      # full scroll

# From existing images
before-and-after before.png after.png --markdown

# Via npx (use full package name!)
npx @vercel/before-and-after url1 url2
```

| Flag | Description |
|------|-------------|
| `-m, --mobile` | Mobile viewport (375x812) |
| `-t, --tablet` | Tablet viewport (768x1024) |
| `--size <WxH>` | Custom viewport |
| `-f, --full` | Full scrollable page |
| `-s, --selector` | CSS selector to capture |
| `-o, --output` | Output directory (default: ~/Downloads) |
| `--markdown` | Upload images & output markdown table |
| `--upload-url <url>` | Custom upload endpoint (default: 0x0.st) |

## Image Publishing

Choose image publishing based on sensitivity and repository visibility.

```bash
# External upload: only when the user explicitly allows it
./scripts/upload-and-copy.sh before.png after.png --markdown

# GitHub Gist upload: only when the user explicitly allows it
IMAGE_ADAPTER=gist ./scripts/upload-and-copy.sh before.png after.png --markdown
```

### GitHub PR image decision matrix

| Situation | Use | Avoid | Verification |
| --- | --- | --- | --- |
| Public repo, screenshots committed to branch | `https://raw.githubusercontent.com/<owner>/<repo>/<ref>/<path>.png` | local paths, unpushed files | `curl -L -o /tmp/check.png <url>` returns image bytes |
| Private/internal repo, screenshots committed to branch | `https://github.com/<owner>/<repo>/raw/<ref>/<path>.png` or `https://github.com/<owner>/<repo>/blob/<ref>/<path>.png?raw=true` | bare `raw.githubusercontent.com` URLs; they can 404 without a signed token | verify file exists with `gh api repos/<owner>/<repo>/contents/<path>?ref=<ref>` and confirm browser/PR render if possible |
| Private/internal repo, screenshots not committed | GitHub PR/comment attachment flow (paste or drag into PR body), or ask user to approve a private-safe upload path | 0x0.st, public Gist, public blob upload unless user explicitly approves | after upload, reopen/view PR body and confirm attachment renders for an authenticated repo user |
| Public/non-sensitive generated screenshots | External uploader is acceptable if user allowed upload | assuming upload is allowed by default | fetch uploaded URL and confirm image bytes |

Prefer a commit SHA over a branch ref for long-lived public raw URLs. For private repos, GitHub web/raw URLs rely on browser auth; unauthenticated `curl` may still fail even when the PR renders for authorized reviewers.

## Vercel Deployment Protection

If `.vercel.app` URL returns 401/403:

1. Check Vercel CLI: `which vercel && vercel whoami`
2. If available: `vercel inspect <url>` to get bypass token
3. If not: Tell user to provide bypass token, take manual screenshots, or disable protection

## PR Integration

```bash
# Check GitHub CLI
which gh

# Get current PR and repository visibility
gh pr view --json number,body,headRefName,headRepositoryOwner,headRepository
gh repo view <owner>/<repo> --json nameWithOwner,visibility,isPrivate,defaultBranchRef

# Append screenshots to PR body using URL style chosen from the matrix
gh pr edit <number> --body "<existing-body>

## Before and After
| Before | After |
| --- | --- |
| ![Before](<before-image-url>) | ![After](<after-image-url>) |"
```

If using committed images, commit and push them before editing the PR body. Do not use local file paths, relative paths, unpushed screenshots, or private-repo bare `raw.githubusercontent.com` URLs.

Before saying done, report: repo visibility, image publishing method, exact URL pattern used, and verification performed. If you did not verify browser/PR rendering, say so explicitly instead of claiming the image renders.

## Error Reference

| Error | Fix |
|-------|-----|
| `command not found` | `npm install -g @vercel/before-and-after` |
| `could not determine executable` | Use `npx @vercel/before-and-after` (full name) |
| 401/403 on .vercel.app | See Vercel protection section |
| Element not found | Verify selector exists on page |
