---
name: codebase-search
description: |
  Search and navigate codebases — both local and remote. Use when finding specific
  code patterns, tracing function calls, understanding code structure, locating bugs,
  or searching GitHub repositories for implementations and examples. Handles semantic
  search, grep patterns, AST analysis, and remote code search via GitHub CLI and API.
  Also use when the user asks "how do other projects do X", "find examples of Y on GitHub",
  "search repo Z for", or wants to explore code in repositories they haven't cloned.
companions: [gh]
upstream: https://github.com/supercent-io/skills-template/blob/a6d8358b4343a65059531af7656749275926052d/.agent-skills/codebase-search/SKILL.md
---

# Codebase Search

## When to use this skill

**Local search** (code you have checked out):
- Finding specific functions or classes
- Tracing function calls and dependencies
- Understanding code structure and architecture
- Finding usage examples and code patterns
- Locating bugs or issues
- Code archaeology (understanding legacy code)
- Impact analysis before changes

**Remote search** (code on GitHub you may not have locally):
- Finding real-world usage patterns of a library or API
- Searching a specific GitHub repository without cloning it
- Exploring how other projects solve a similar problem
- Looking up implementation examples across open-source projects
- Investigating code in upstream dependencies or forks

## Step 1: Understand what you're looking for

Classify the question before choosing tools:

| Category | Example questions |
|----------|-------------------|
| **Feature implementation** | Where is feature X implemented? How does Y work? |
| **Bug location** | Where is this error thrown? What handles this case? |
| **API usage** | How is this function called? Show me examples. |
| **Configuration** | Where are settings defined? What are the options? |
| **Cross-project patterns** | How do other projects handle auth? What's the convention for X? |

## Step 2: Decide scope — local, remote, or both

```
Is the code checked out locally?
├── YES → Do you also need external examples or patterns?
│   ├── YES → Combined (local + remote)
│   └── NO  → Local only
└── NO
    ├── Specific repo on GitHub? → Remote (targeted)
    └── General pattern search?  → Remote (broad)
```

**Local only** — The code is on disk. Use grep, glob, semantic search, AST analysis, LSP.

**Remote (targeted)** — You know which repo. Use `gh search code --repo owner/repo` or `gh api` to read files directly.

**Remote (broad)** — You're looking for patterns across many repos. Use `gh search code` with language/qualifier filters, or `gh search repos` to find high-quality repos first.

**Combined** — Start local to understand the current codebase, then go remote to find how others approach the same problem, compare patterns, or check upstream behavior.

## Step 3: Local search strategies

Three complementary approaches — start with whichever fits, combine as needed.

**Semantic search** — for conceptual questions ("How do we handle authentication?"):
- Finds code by meaning, not exact text
- Best for unfamiliar codebases and exploratory work

**Grep** — for exact text and patterns ("def verify_token", "API_KEY"):
- Fast, precise, supports regex
- Best when you know specific terms

**Glob** — for file discovery ("**/*.test.js", "**/config*.yaml"):
- Find files by name/type patterns
- Map out directory structure

**AST search** — for structural code patterns (`console.log($MSG)`, `def $FUNC($$$):`):
- Language-aware, ignores formatting differences
- Best for refactoring and pattern matching across syntax variations

**LSP** — for symbol-level navigation:
- Go to definition, find all references, rename across workspace
- Best when you already know the symbol name

For detailed grep/glob patterns by language and workflow examples, see `references/local-patterns.md`.

## Step 4: Remote search strategies

Remote search uses the `gh` companion skill for GitHub CLI commands (`gh search code`, `gh api`, `gh repo clone`).

### Search a specific repository

When you know which repo to search:

```bash
# Search for a pattern in a specific repo
gh search code "pattern" --repo owner/repo

# Search with language filter
gh search code "useAuth" --repo vercel/next.js --language typescript

# Read a specific file from a remote repo without cloning
gh api repos/{owner}/{repo}/contents/{path} \
  --jq '.content' | base64 -d
```

### Search across GitHub (broad)

When looking for patterns across open-source projects:

```bash
# Search all of GitHub with language filter
gh search code "pattern" --language python --limit 20

# Narrow by filename
gh search code "pattern" --filename config.yaml

# Filter by repo qualities (stars, forks, etc.)
gh search code "pattern" --language go --limit 10
```

### grep.app (optional, environment-specific)

Some agent environments provide a `grep_app_searchGitHub` tool that searches over a million public GitHub repos. If available, it's excellent for finding real-world usage patterns:

```
# Find how people use a specific API
grep_app_searchGitHub(query="useAuth(", language=["TypeScript", "TSX"])

# Find patterns with regex
grep_app_searchGitHub(query="(?s)try {.*await", useRegexp=true, language=["TypeScript"])

# Search within a specific repo
grep_app_searchGitHub(query="handleError", repo="vercel/next.js")
```

This is literal code search (like grep), not keyword search. Search for actual code patterns, not descriptions.

**If `grep_app_searchGitHub` is NOT available**, use `gh search code` instead — it provides similar functionality via GitHub's code search API.

### Tiered Remote Search Strategy

**CRITICAL**: Use the right approach based on investigation depth. Local tooling (grep, AST, LSP) is dramatically more powerful than API search — but cloning has overhead. Follow this decision tree:

```
Remote search request
    │
    ├─ Quick lookup (single symbol, single file, simple question)?
    │   └─ Use gh api / gh search code (fast, lightweight)
    │       └─ Insufficient results? → Escalate to clone
    │
    ├─ Deep investigation (call graph, multi-file, architecture)?
    │   └─ Clone to /tmp (shallow, --depth 1)
    │       └─ Clone fails? → Fallback to gh api / gh search code
    │
    └─ Broad pattern search (find examples across many repos)?
        └─ gh search code with broad qualifiers
            └─ Found interesting repo? → Clone it for deep dive
```

#### Tier 1: API Search (quick lookups)

For simple, targeted questions — "what does function X return?", "find this config key":

```bash
# Read a specific file
gh api repos/{owner}/{repo}/contents/{path} --jq '.content' | base64 -d

# Search for a symbol
gh search code "functionName" --repo owner/repo --language typescript
```

**Use when**: Single symbol lookup, known file path, quick answer needed.
**Escalate to Tier 2 when**: Results are truncated, you need surrounding context, or you need to trace across files.

#### Tier 2: Clone to /tmp (deep investigation)

For thorough exploration — call graph tracing, multi-file analysis, architecture understanding — clone shallowly to a deterministic cache path under `/tmp/agent-repos/`, then use full local search tooling on the clone. For the complete safe-clone and sparse-checkout scripts, see `references/remote-clone.md`.

**Size guard**: Check `gh api repos/{owner}/{repo} --jq '.size'` first. If size >500000 (KB, ~500MB), skip clone and use API-only (Tier 1) or a sparse checkout (see `references/remote-clone.md`).

**Existing destination policy**: Treat `/tmp/agent-repos/` as a reusable cache, not disposable scratch. Before cloning, always check whether the destination exists. If it exists, confirm it is a git repo and that `origin` matches the repo you intend to inspect. If it matches, reuse or refresh it. If it does not match, prefer a new destination name (for example `/tmp/agent-repos/owner-repo-2`) over deleting anything.

**Removal policy**: Do not clean up cloned repos automatically. `rm -rf` is a last resort, not a setup step and not routine cleanup. Never `rm` before inspecting origin. Only remove a path after all of these are true:

1. You inspected the path and confirmed it is under `/tmp/agent-repos/`.
2. You confirmed the remote and contents are not needed for the current task.
3. You are not inside that directory and no process depends on it.
4. Reusing it or choosing a different destination is worse than removal.

If removal is truly necessary, make the guard explicit:

```bash
dest=/tmp/agent-repos/owner-repo
case "$dest" in
  /tmp/agent-repos/*) ;;
  *) echo "Refusing to remove outside /tmp/agent-repos: $dest"; exit 1 ;;
esac
git -C "$dest" remote -v 2>/dev/null || true
rm -rf -- "$dest"
```

**Fallback**: If clone fails (auth, network, repo too large), fall back to Tier 1 (API search via `gh search code` + `gh api`).

#### Tier 3: Broad search (cross-repo patterns)

For "how do other projects do X?" — use `gh search code` to cast a wide net, then clone the best results:

```bash
# 1. Search broadly across GitHub
gh search code "pattern" --language typescript --limit 20

# 2. Narrow to high-quality repos (check stars, activity)
gh search repos "topic" --language typescript --sort stars --limit 10

# 3. Search within top repos
gh search code "pattern" --repo owner/top-repo --language typescript

# 4. Clone top 2-3 repos to /tmp for deep analysis (Tier 2)
dest=/tmp/agent-repos/owner-top-repo
# Repeat the Tier 2 safe clone flow for each repo: if $dest exists, verify origin first; do not remove first.
# Then use: gh repo clone owner/top-repo "$dest" -- --depth 1

# 5. Full local tooling on each clone
# 6. Compare approaches, synthesize findings
# 7. Leave reusable clones in /tmp/agent-repos; remove only as last resort per Tier 2 policy
```

**Use when**: Pattern discovery across OSS, finding best practices, comparing approaches.

> **Note**: If the agent environment provides specialized broad-search tools (e.g., `grep_app_searchGitHub`), those may be used to supplement `gh search code` for wider coverage. The strategy above works universally with just `gh` CLI.

## Step 5: Combined workflows

### Pattern: Compare local implementation to OSS

```
1. Understand local approach
   Local grep: "def authenticate" → read implementation

2. Find how others do it
   gh search code "def authenticate" --language python
   (or grep_app_searchGitHub if available in your environment)

3. Compare approaches
   Read both, note differences, decide if local approach should change
```

### Pattern: Trace a dependency's behavior

```
1. Find local usage of the dependency
   Local grep: "import some_library" → find all callsites

2. Look at the library's source
   gh api repos/{owner}/{lib}/contents/src/module.py | base64 -d
   or: gh repo clone owner/lib -- --depth 1

3. Understand the behavior
   Read the relevant source, check for edge cases
```

### Pattern: Find examples before implementing

```
1. Check if a similar feature exists locally
   Local semantic: "How do we handle webhooks?"

2. If not, find OSS examples
   gh search code "verify_webhook" --language python
   gh search code "webhook" "verify_signature" --language python

3. Read the best examples
   Pick repos with high stars, read their implementation

4. Implement locally following both local conventions and proven patterns
```

### Pattern: Cross-repo investigation (remote)
```
1. Start with a GitHub issue or PR reference
   gh issue view 123 --repo owner/repo
   gh pr view 456 --repo owner/repo --comments

2. Find the relevant code changes
   gh pr diff 456 --repo owner/repo

3. Search for related patterns
   gh search code "the_function_name" --repo owner/repo
```

## Best practices

1. **Start broad, then narrow** — semantic search first, grep to refine
2. **Use the right scope** — don't search all of GitHub when you need one repo
3. **Combine local + remote** — local for "how do we do it", remote for "how should we do it"
4. **Read surrounding context** — don't just look at matching lines
5. **Check tests** — tests often show usage examples (locally and in OSS)
6. **Use directory targeting** — narrow scope when possible
7. **Follow the data** — trace data flow through the system
8. **Use AST search for structure** — when grep is too noisy due to formatting variation
9. **Shallow clone for deep dives** — `--depth 1` when gh search isn't enough
10. **Verify assumptions** — read actual code, don't assume from function names

## Troubleshooting

### Local search issues

**No results found**:
- Check spelling and case sensitivity (`-i` for case insensitive)
- Try semantic search instead of grep
- Broaden scope (remove directory target)
- Try different terms — check if files are in .gitignore

**Too many results**:
- Add directory targeting
- Use more specific patterns or filter by file type
- Use exact phrases

### Remote search issues

**gh search returns nothing**:
- GitHub code search requires exact token matches, not fuzzy
- Try shorter or more general patterns
- Check if the repo is public (private repos need authentication)
- Clone the repo and search locally instead (see Tiered Remote Search Strategy)

**Rate limited by GitHub API**:
- Add `--limit` to reduce result count
- Space out requests
- Clone the repo and search locally instead

**Can't read remote file content**:
- Use `gh api repos/{owner}/{repo}/contents/{path}` — content is base64-encoded
- For large files, clone the repo instead (API has a 1MB file limit)

## Git integration

```bash
# Who changed this line?
git blame filename

# History of a file
git log -p filename

# Find when function was added
git log -S "function_name" --source --all

# Find commits mentioning X
git log --grep="feature name"
```

## References

- `references/local-patterns.md` — detailed grep/glob patterns by language, workflow examples, common scenarios
- `references/remote-clone.md` — safe shallow-clone and sparse-checkout scripts for deep remote investigation
- [Ripgrep User Guide](https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md)
- [GitHub Code Search Syntax](https://docs.github.com/en/search-github/github-code-search/understanding-github-code-search-syntax)
- [Git Blame Guide](https://git-scm.com/docs/git-blame)
