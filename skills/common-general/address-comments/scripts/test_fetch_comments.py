#!/usr/bin/env python3
from __future__ import annotations
# pyright: reportAny=false, reportExplicitAny=false, reportUnknownVariableType=false, reportUnknownMemberType=false

import importlib.util
import sys
import unittest
from pathlib import Path
from typing import Any, cast
from unittest import mock

SCRIPT_DIR = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("fetch_comments", SCRIPT_DIR / "fetch_comments.py")
assert spec is not None
fetch_comments = cast(Any, importlib.util.module_from_spec(spec))
sys.modules["fetch_comments"] = fetch_comments
assert spec.loader is not None
spec.loader.exec_module(fetch_comments)
SKILL_MD = SCRIPT_DIR.parent / "SKILL.md"


def page(
    comment_nodes: list[dict[str, Any]],
    review_nodes: list[dict[str, Any]],
    thread_nodes: list[dict[str, Any]],
    *,
    c_next: bool = False,
    r_next: bool = False,
    t_next: bool = False,
) -> dict[str, Any]:
    return {
        "data": {
            "repository": {
                "pullRequest": {
                    "number": 7,
                    "url": "https://github.com/base/repo/pull/7",
                    "title": "title",
                    "state": "OPEN",
                    "comments": {
                        "pageInfo": {"hasNextPage": c_next, "endCursor": "c2" if c_next else None},
                        "nodes": comment_nodes,
                    },
                    "reviews": {
                        "pageInfo": {"hasNextPage": r_next, "endCursor": "r2" if r_next else None},
                        "nodes": review_nodes,
                    },
                    "reviewThreads": {
                        "pageInfo": {"hasNextPage": t_next, "endCursor": "t2" if t_next else None},
                        "nodes": thread_nodes,
                    },
                }
            }
        }
    }


class FetchAllTests(unittest.TestCase):
    def test_fetch_all_does_not_duplicate_completed_collections_when_page_counts_differ(self):
        first = page(
            [{"id": "comment-1"}],
            [{"id": "review-1"}],
            [{"id": "thread-1", "comments": {"pageInfo": {"hasNextPage": False}, "nodes": []}}],
            c_next=True,
        )
        second = page(
            [{"id": "comment-2"}],
            [{"id": "review-1"}],
            [{"id": "thread-1", "comments": {"pageInfo": {"hasNextPage": False}, "nodes": []}}],
        )

        with mock.patch.object(fetch_comments, "gh_api_graphql", side_effect=[first, second]):
            result = fetch_comments.fetch_all("base", "repo", 7)

        self.assertEqual(["pull_request", "conversation_comments", "reviews", "review_threads"], list(result))
        self.assertEqual(["comment-1", "comment-2"], [node["id"] for node in result["conversation_comments"]])
        self.assertEqual(["review-1"], [node["id"] for node in result["reviews"]])
        self.assertEqual(["thread-1"], [node["id"] for node in result["review_threads"]])

    def test_fetch_all_paginates_review_thread_replies_beyond_first_100(self):
        first_thread = {
            "id": "thread-1",
            "comments": {
                "pageInfo": {"hasNextPage": True, "endCursor": "reply-100"},
                "nodes": [{"id": "reply-1"}],
            },
        }
        payload = page([], [], [first_thread])

        final_page_info = {"hasNextPage": False, "endCursor": "reply-200"}
        with mock.patch.object(fetch_comments, "gh_api_graphql", return_value=payload), mock.patch.object(
            fetch_comments,
            "fetch_remaining_thread_comments",
            return_value=([{"id": "reply-101"}], final_page_info),
        ) as fetch_remaining:
            result = fetch_comments.fetch_all("base", "repo", 7)

        fetch_remaining.assert_called_once_with("thread-1", "reply-100")
        comments = result["review_threads"][0]["comments"]
        self.assertEqual(["reply-1", "reply-101"], [node["id"] for node in comments["nodes"]])
        self.assertEqual(final_page_info, comments["pageInfo"])

    def test_get_current_pr_ref_uses_base_repository_coordinates_from_pr_url(self):
        with mock.patch.object(
            fetch_comments,
            "gh_pr_view_json",
            return_value={
                "number": 7,
                "url": "https://github.com/base-owner/base-repo/pull/7",
                "headRepositoryOwner": {"login": "fork-owner"},
                "headRepository": {"name": "fork-repo"},
            },
        ) as view:
            self.assertEqual(("base-owner", "base-repo", 7), fetch_comments.get_current_pr_ref())

        view.assert_called_once_with("number,url")

    def test_parse_pr_url_allows_pull_as_owner_or_repository_name(self):
        self.assertEqual(
            ("pull", "repo"),
            fetch_comments.parse_pr_url("https://github.com/pull/repo/pull/7"),
        )
        self.assertEqual(
            ("owner", "pull"),
            fetch_comments.parse_pr_url("https://github.com/owner/pull/pull/7"),
        )


class SkillTextTests(unittest.TestCase):
    def test_skill_text_invariants(self):
        text = SKILL_MD.read_text()
        frontmatter = text.split("---", 2)[1]

        self.assertIn("disable-model-invocation: true", frontmatter)
        self.assertIn("description: >", frontmatter)
        self.assertNotIn("Triggers on", frontmatter)
        self.assertNotIn("gh pr view --json reviewThreads", text)
        self.assertNotIn("ask for user permission", text)
        self.assertEqual(1, text.count("approval"))
        self.assertIn("approval before", text.lower())


if __name__ == "__main__":
    _ = unittest.main()
