#!/usr/bin/env python3
"""
Fetch all PR conversation comments + reviews + review threads (inline threads)
for the PR associated with the current git branch, by shelling out to:

  gh api graphql

Requires:
  - `gh auth login` already set up
  - current branch has an associated (open) PR

Usage:
  python fetch_comments.py > pr_comments.json
"""

from __future__ import annotations
# pyright: reportAny=false, reportExplicitAny=false, reportUnknownVariableType=false, reportUnknownMemberType=false, reportUnknownArgumentType=false, reportUnusedCallResult=false

import json
import subprocess
import sys
from typing import Any
from urllib.parse import urlparse

QUERY = """\
query(
  $owner: String!,
  $repo: String!,
  $number: Int!,
  $commentsCursor: String,
  $reviewsCursor: String,
  $threadsCursor: String
) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      number
      url
      title
      state

      # Top-level "Conversation" comments (issue comments on the PR)
      comments(first: 100, after: $commentsCursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          body
          createdAt
          updatedAt
          author { login }
        }
      }

      # Review submissions (Approve / Request changes / Comment), with body if present
      reviews(first: 100, after: $reviewsCursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          state
          body
          submittedAt
          author { login }
        }
      }

      # Inline review threads (grouped), includes resolved state
      reviewThreads(first: 100, after: $threadsCursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          diffSide
          startLine
          startDiffSide
          originalLine
          originalStartLine
          resolvedBy { login }
          comments(first: 100) {
            pageInfo { hasNextPage endCursor }
            nodes {
              id
              body
              createdAt
              updatedAt
              author { login }
            }
          }
        }
      }
    }
  }
}
"""

THREAD_COMMENTS_QUERY = """\
query(
  $threadId: ID!,
  $commentsCursor: String
) {
  node(id: $threadId) {
    ... on PullRequestReviewThread {
      comments(first: 100, after: $commentsCursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          body
          createdAt
          updatedAt
          author { login }
        }
      }
    }
  }
}
"""


def _run(cmd: list[str], stdin: str | None = None) -> str:
    p = subprocess.run(cmd, input=stdin, capture_output=True, text=True)
    if p.returncode != 0:
        raise RuntimeError(f"Command failed: {' '.join(cmd)}\n{p.stderr}")
    return p.stdout


def _run_json(cmd: list[str], stdin: str | None = None) -> dict[str, Any]:
    out = _run(cmd, stdin=stdin)
    try:
        return json.loads(out)
    except json.JSONDecodeError as e:
        raise RuntimeError(f"Failed to parse JSON from command output: {e}\nRaw:\n{out}") from e


def _ensure_gh_authenticated() -> None:
    try:
        _run(["gh", "auth", "status"])
    except RuntimeError:
        print("run `gh auth login` to authenticate the GitHub CLI", file=sys.stderr)
        raise RuntimeError("gh auth status failed; run `gh auth login` to authenticate the GitHub CLI") from None


def gh_pr_view_json(fields: str) -> dict[str, Any]:
    # fields is a comma-separated list like: "number,url"
    return _run_json(["gh", "pr", "view", "--json", fields])


def get_current_pr_ref() -> tuple[str, str, int]:
    """
    Resolve the PR for the current branch using the base PR URL coordinates.
    """
    pr = gh_pr_view_json("number,url")
    owner, repo = parse_pr_url(pr["url"])
    number = int(pr["number"])
    return owner, repo, number


def parse_pr_url(url: str) -> tuple[str, str]:
    parts = [part for part in urlparse(url).path.split("/") if part]
    if len(parts) < 4 or parts[-2] != "pull":
        raise RuntimeError(f"Unexpected PR URL: {url}")
    owner, repo = parts[-4], parts[-3]
    return owner, repo


def gh_api_graphql(
    owner: str,
    repo: str,
    number: int,
    comments_cursor: str | None = None,
    reviews_cursor: str | None = None,
    threads_cursor: str | None = None,
) -> dict[str, Any]:
    """
    Call `gh api graphql` using -F variables, avoiding JSON blobs with nulls.
    Query is passed via stdin using query=@- to avoid shell newline/quoting issues.
    """
    cmd = [
        "gh",
        "api",
        "graphql",
        "-F",
        "query=@-",
        "-F",
        f"owner={owner}",
        "-F",
        f"repo={repo}",
        "-F",
        f"number={number}",
    ]
    if comments_cursor:
        cmd += ["-F", f"commentsCursor={comments_cursor}"]
    if reviews_cursor:
        cmd += ["-F", f"reviewsCursor={reviews_cursor}"]
    if threads_cursor:
        cmd += ["-F", f"threadsCursor={threads_cursor}"]

    return _run_json(cmd, stdin=QUERY)


def gh_api_thread_comments(thread_id: str, comments_cursor: str | None = None) -> dict[str, Any]:
    cmd = [
        "gh",
        "api",
        "graphql",
        "-F",
        "query=@-",
        "-F",
        f"threadId={thread_id}",
    ]
    if comments_cursor:
        cmd += ["-F", f"commentsCursor={comments_cursor}"]

    return _run_json(cmd, stdin=THREAD_COMMENTS_QUERY)


def fetch_remaining_thread_comments(
    thread_id: str, comments_cursor: str
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    comments: list[dict[str, Any]] = []
    cursor: str | None = comments_cursor
    page_info: dict[str, Any] = {"hasNextPage": True, "endCursor": comments_cursor}
    while cursor:
        payload = gh_api_thread_comments(thread_id, cursor)
        if "errors" in payload and payload["errors"]:
            raise RuntimeError(f"GitHub GraphQL errors:\n{json.dumps(payload['errors'], indent=2)}")

        thread = payload["data"]["node"]
        thread_comments = thread["comments"]
        comments.extend(thread_comments.get("nodes") or [])
        page_info = thread_comments["pageInfo"]
        cursor = page_info["endCursor"] if page_info["hasNextPage"] else None
    return comments, page_info


def fetch_all(owner: str, repo: str, number: int) -> dict[str, Any]:
    conversation_comments: list[dict[str, Any]] = []
    reviews: list[dict[str, Any]] = []
    review_threads: list[dict[str, Any]] = []

    comments_cursor: str | None = None
    reviews_cursor: str | None = None
    threads_cursor: str | None = None

    pr_meta: dict[str, Any] | None = None
    comments_done = False
    reviews_done = False
    threads_done = False

    while True:
        payload = gh_api_graphql(
            owner=owner,
            repo=repo,
            number=number,
            comments_cursor=comments_cursor,
            reviews_cursor=reviews_cursor,
            threads_cursor=threads_cursor,
        )

        if "errors" in payload and payload["errors"]:
            raise RuntimeError(f"GitHub GraphQL errors:\n{json.dumps(payload['errors'], indent=2)}")

        pr = payload["data"]["repository"]["pullRequest"]
        if pr_meta is None:
            pr_meta = {
                "number": pr["number"],
                "url": pr["url"],
                "title": pr["title"],
                "state": pr["state"],
                "owner": owner,
                "repo": repo,
            }

        c = pr["comments"]
        r = pr["reviews"]
        t = pr["reviewThreads"]

        if not comments_done:
            conversation_comments.extend(c.get("nodes") or [])
            comments_page_info = c["pageInfo"]
            comments_cursor = comments_page_info["endCursor"] if comments_page_info["hasNextPage"] else None
            comments_done = comments_cursor is None

        if not reviews_done:
            reviews.extend(r.get("nodes") or [])
            reviews_page_info = r["pageInfo"]
            reviews_cursor = reviews_page_info["endCursor"] if reviews_page_info["hasNextPage"] else None
            reviews_done = reviews_cursor is None

        if not threads_done:
            threads = t.get("nodes") or []
            for thread in threads:
                thread_comments = thread.get("comments") or {}
                thread_comments_page_info = thread_comments.get("pageInfo") or {}
                if thread_comments_page_info.get("hasNextPage"):
                    remaining_comments, final_page_info = fetch_remaining_thread_comments(
                        thread["id"], thread_comments_page_info["endCursor"]
                    )
                    thread_comments.setdefault("nodes", []).extend(remaining_comments)
                    thread_comments["pageInfo"] = final_page_info
            review_threads.extend(threads)
            threads_page_info = t["pageInfo"]
            threads_cursor = threads_page_info["endCursor"] if threads_page_info["hasNextPage"] else None
            threads_done = threads_cursor is None

        if comments_done and reviews_done and threads_done:
            break

    assert pr_meta is not None
    return {
        "pull_request": pr_meta,
        "conversation_comments": conversation_comments,
        "reviews": reviews,
        "review_threads": review_threads,
    }


def main() -> None:
    _ensure_gh_authenticated()
    owner, repo, number = get_current_pr_ref()
    result = fetch_all(owner, repo, number)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
