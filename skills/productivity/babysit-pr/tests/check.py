#!/usr/bin/env python3
"""Offline check of pr-wait's review-bot gate; never calls gh."""

import importlib.machinery
import importlib.util
import json
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True
script = Path(__file__).resolve().parent.parent / "scripts" / "pr-wait"
loader = importlib.machinery.SourceFileLoader("pr_wait", str(script))
spec = importlib.util.spec_from_loader("pr_wait", loader)
pr_wait = importlib.util.module_from_spec(spec)
loader.exec_module(pr_wait)
pr_wait.STATE_DIR = Path(tempfile.mkdtemp())

HEAD = "a" * 40
BOT = "Bot"


def codex_summary(sha: str, status: str) -> dict:
    state = {"code_review": {"commit_sha": sha, "status": status, "has_any_findings": False}}
    body = f"<!-- codex-pull-request-review-summary -->\n<!-- codex-review-state:v1 {json.dumps(state)} -->\n`{sha[:7]}`"
    return {"id": "codex", "url": "u", "body": body, "author": {"login": "chatgpt-codex-connector[bot]", "__typename": BOT}}


def coderabbit_review(sha: str) -> dict:
    return {"id": "cr", "url": "u", "state": "COMMENTED", "body": "", "commit": {"oid": sha},
            "author": {"login": "coderabbitai[bot]", "__typename": BOT}}


def coderabbit_rate_limited() -> dict:
    return {"id": "crl", "url": "u", "body": "rate limited", "author": {"login": "coderabbitai[bot]", "__typename": BOT}}


def outcome(comments: list, reviews: list) -> int | None:
    """Exit code after two polls (green needs two identical check snapshots), or None while waiting."""
    pr = {
        "url": "u", "state": "OPEN", "headRefOid": HEAD, "baseRefName": "main", "mergeStateStatus": "CLEAN",
        "author": {"login": "me"}, "baseRef": None, "viewer": "me",
        "comments": {"nodes": comments}, "reviews": {"nodes": reviews}, "reviewThreads": {"nodes": []},
    }
    watcher = pr_wait.Watcher("o/r", 1, "ready", 5)
    watcher.path.unlink(missing_ok=True)
    watcher.required = set()
    watcher.fetch_pr = lambda: pr
    watcher.fetch_checks = lambda: {"unit": {"name": "unit", "bucket": "pass", "link": "l", "description": ""}}
    try:
        watcher.poll()
        watcher.poll()
    except SystemExit as stop:
        return stop.code
    return None


assert outcome([codex_summary(HEAD, "completed")], [coderabbit_review(HEAD)]) == 0, "both bots done"
assert outcome([codex_summary(HEAD, "completed")], []) == 0, "absent bot is not waited on"
assert outcome([codex_summary(HEAD, "in_progress")], []) is None, "running Codex review is not done"
assert outcome([codex_summary("b" * 40, "completed")], []) is None, "Codex reviewed an older head"
assert outcome([codex_summary(HEAD, "completed"), coderabbit_rate_limited()], []) is None, "seen CodeRabbit gates"
assert not pr_wait.codex_reviewed([{"body": "<!-- codex-review-state:v1 {broken -->"}], HEAD)
print("pr-wait checks passed")
