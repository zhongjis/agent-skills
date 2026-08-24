# Herdr bulk review — batch loops

Ready-to-run bash for each phase of `SKILL.md`. Set the inputs once:

```bash
REPO="owner/repo"                       # e.g. Adobe-Marketo-Engage/marketo-engage-ai-agent
URL="https://github.com/$REPO/pull"
PRS="457 458 459 460"                   # PR numbers to review
```

Every loop names agents `review-<n>` and derives each PR's branch from `gh`, so nothing is hardcoded. Each runs under `set +e` — one PR failing must not abort the batch.

## § dispatch — fan out (SKILL § 2)

```bash
set +e
git fetch origin --prune
for n in $PRS; do
  B=$(gh pr view "$n" --repo "$REPO" --json headRefName --jq .headRefName)
  [ -z "$B" ] && { echo "PR $n: no branch"; continue; }
  CJSON=$(herdr worktree create --branch "$B" --base "origin/$B" --no-focus 2>&1)
  PANE=$(echo "$CJSON" | python3 -c "import json,sys;print(json.load(sys.stdin)['result']['root_pane']['pane_id'])" 2>/dev/null)
  WT=$(echo "$CJSON" | python3 -c "import json,sys;print(json.load(sys.stdin)['result']['worktree']['path'])" 2>/dev/null)
  [ -z "$PANE" ] && { echo "PR $n WORKTREE_FAIL: $(echo "$CJSON" | head -c 160)"; continue; }
  # force HEAD to the PR head (fixes stale pre-existing local branch; no-op otherwise)
  git -C "$WT" reset --hard "origin/$B" >/dev/null 2>&1
  H=$(git -C "$WT" rev-parse HEAD); O=$(git -C "$WT" rev-parse "origin/$B")
  [ "$H" != "$O" ] && echo "PR $n WARN head!=origin ($H vs $O)"
  # start the agent, retrying while the fresh pane finishes shell init
  for i in 1 2 3 4 5; do
    OUT=$(herdr agent start review-$n --kind pi --pane "$PANE" --timeout 120000 2>&1)
    echo "$OUT" | python3 -c "import json,sys;exit(0 if json.load(sys.stdin).get('result',{}).get('agent',{}).get('interactive_ready') else 1)" 2>/dev/null && break
    echo "$OUT" | grep -q agent_pane_busy && { sleep 4; continue; }
    echo "PR $n START_ERR: $(echo "$OUT" | head -c 160)"; break
  done
  sleep 1
  herdr agent prompt review-$n "\$skill:code-review-v2 $URL/$n ulw" >/dev/null 2>&1
  sleep 3
  ST=$(herdr agent get review-$n 2>&1 | python3 -c "import json,sys;print(json.load(sys.stdin)['result']['agent']['agent_status'])" 2>/dev/null)
  echo "PR $n pane=$PANE agent=review-$n head=${H:0:8} status=$ST"
done
```

## § monitor — settle + post (SKILL § 3)

Re-checks GitHub each round; instructs any settled-but-unposted agent to post. Idempotent — a posted PR is skipped, a `working` agent is left alone.

```bash
set +e
ME=$(gh api user -q .login)
POST_TMPL="Your code review is complete but not yet posted. Post it now to PR #__N__ (repo $REPO) as one atomic GitHub PR review via gh: event = your verdict (APPROVE / REQUEST_CHANGES / COMMENT), body = your full findings + verdict, inline comments where you cited file:line. After posting, reply with the review URL."
posted() { gh pr view "$1" --repo "$REPO" --json reviews \
  --jq "[.reviews[]|select(.author.login==\"$ME\")]|last|.state" 2>/dev/null; }
for round in $(seq 1 8); do
  left=0
  for n in $PRS; do
    V=$(posted "$n"); [ -n "$V" ] && [ "$V" != "null" ] && continue
    left=$((left + 1))
    ST=$(herdr agent get review-$n 2>&1 | python3 -c "import json,sys;print(json.load(sys.stdin)['result']['agent']['agent_status'])" 2>/dev/null)
    [ "$ST" = "done" ] && herdr agent prompt review-$n "${POST_TMPL/__N__/$n}" >/dev/null 2>&1
  done
  echo "round $round: $left unposted"
  [ "$left" = 0 ] && { echo "all posted"; break; }
  sleep 120
done
# verdict summary
for n in $PRS; do echo "PR $n -> $(posted "$n")"; done
```

## § prune — remove approved worktrees (SKILL § 4)

```bash
set +e
ME=$(gh api user -q .login)
for n in $PRS; do
  V=$(gh pr view "$n" --repo "$REPO" --json reviews \
    --jq "[.reviews[]|select(.author.login==\"$ME\")]|last|.state" 2>/dev/null)
  [ "$V" != "APPROVED" ] && continue
  WS=$(herdr agent list 2>&1 | python3 -c "
import json,sys
for a in json.load(sys.stdin).get('result',{}).get('agents') or []:
    if a.get('name')=='review-$n':
        print((a.get('pane_id') or '').split(':')[0]); break" 2>/dev/null)
  [ -z "$WS" ] && { echo "PR $n APPROVED but no live workspace"; continue; }
  R=$(herdr worktree remove --workspace "$WS" --force 2>&1)
  echo "PR $n APPROVED ws=$WS -> $(echo "$R" | python3 -c "import json,sys;d=json.load(sys.stdin);print(d.get('result',{}).get('type','ERR'))" 2>/dev/null)"
done
echo "--- ground truth (git worktree list) ---"; git worktree list
```

## § rereview — detect + re-dispatch (SKILL § 5)

Needs re-review when the newest commit postdates the last posted review (ISO-8601 UTC compares lexicographically).

```bash
set +e
ME=$(gh api user -q .login)
git fetch origin --prune
for n in $PRS; do
  read -r NEED B < <(gh pr view "$n" --repo "$REPO" --json reviews,commits,headRefName 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin); me='$ME'
revs=[r['submittedAt'] for r in d.get('reviews',[]) if (r.get('author') or {}).get('login')==me]
rat=max(revs) if revs else ''
dates=[c.get('committedDate') for c in d.get('commits',[]) if c.get('committedDate')]
latest=max(dates) if dates else ''
print(('yes' if latest>rat else 'no'), d.get('headRefName',''))")
  [ "$NEED" != "yes" ] && { echo "PR $n up-to-date"; continue; }
  WT=$(git worktree list --porcelain | awk -v b="refs/heads/$B" '/^worktree /{p=$2} $0=="branch "b{print p}')
  [ -z "$WT" ] && { echo "PR $n needs re-review but has no worktree"; continue; }
  git -C "$WT" reset --hard "origin/$B" >/dev/null 2>&1
  herdr agent prompt review-$n "\$skill:code-review-v2 $URL/$n ulw" >/dev/null 2>&1
  echo "PR $n re-review dispatched head=$(git -C "$WT" rev-parse --short HEAD)"
done
```
