---
name: rg
description: >-
  Search file contents using ripgrep (rg) — fast recursive text/regex search with gitignore awareness.
  Use when searching for text patterns in files, finding code across a codebase, grep-style content search,
  or multi-file regex matching. Also use when user says "search file contents", "find text in files",
  "grep for", "search in files", "look for pattern in code", or "find occurrences of".
  Prefer rg over grep for speed and smart defaults.
upstream: "https://github.com/laurigates/claude-plugins/tree/main/tools-plugin/skills/rg-code-search"
---

# rg (ripgrep) — Agent Guide

Fast recursive text search. Respects `.gitignore`, smart case, recursive by default.

## When to Use rg vs Other Tools

| Task | Best tool | Why |
|------|-----------|-----|
| Search text/regex across files | **rg** | Fast, recursive, gitignore-aware |
| Find files by name/extension/path | **fd** | File finding, not content search |
| Structural code patterns (e.g., "functions with 3 params") | **ast_search** | AST-aware, not regex |
| Find all references to a symbol | **lsp_references** | Semantic, follows renames |
| Jump to definition | **lsp_definition** | Semantic |
| Read a known file | **read** | Full content with anchors |
| POSIX compatibility or piped stdin | **grep** | When rg isn't available |

## Critical Agent Rules

### 1. ALWAYS use `-F` for literal strings containing regex metacharacters

Characters `(`, `)`, `[`, `]`, `{`, `}`, `.`, `*`, `+`, `?`, `|`, `^`, `$`, `\` have special regex meaning. If you mean them literally, use `-F`:

```bash
# CORRECT — -F treats pattern as literal
rg -F 'config.get("key")'
rg -F 'array[0]'
rg -F 'value={something}'

# WRONG — regex metacharacters will cause errors or wrong matches
rg 'config.get("key")'        # . matches any char, ( is group
rg 'array[0]'                 # [0] is a character class
rg 'value={something}'        # { is quantifier in Rust regex
```

**Rule**: If the search string is a code snippet the user typed, default to `-F`.

### 2. ALWAYS limit output for common/broad patterns

Searching for patterns that match hundreds of lines will flood the context window. Use one of:

```bash
rg -l 'console.log' -t js     # List files only — best first step
rg -c 'console.log' -t js     # Count per file
rg -m 10 'console.log' -t js  # Max 10 matches per file
```

**When to limit**: `console.log`, `import`, `TODO`, common variable names, any pattern likely to match many lines. **Start with `-l` to assess scope, then narrow.**

### 3. ALWAYS use `-P` when pattern contains `(?<=`, `(?<!`, `(?=`, or `(?!`

Ripgrep uses Rust regex by default. **Any pattern with lookahead or lookbehind MUST use `-P`:**

```bash
rg -P '(?<=await\s)\w+\('     # CORRECT — -P enables PCRE2
rg '(?<=await\s)\w+\('        # WRONG — will error: "look-around not supported"
rg -P '(?!test_)\w+\.py'       # CORRECT — negative lookahead needs -P
```

### 4. Use `-U` for multi-line matching

```bash
rg -U 'def \w+.*\n.*return' -t py   # Multi-line: function with return
rg -U '(@\w+\n)+class' -t py        # Decorated class definitions
```

## Quick Reference

### File Type Filtering
```bash
rg pattern -t py              # Python (.py, .pyi)
rg pattern -t ts              # TypeScript (.ts, .tsx)
rg pattern -t js              # JavaScript (.js, .jsx)
rg pattern -t go              # Go
rg pattern -t rs              # Rust
rg pattern -t md              # Markdown
rg pattern -g '*.nix'         # Custom extension
rg pattern -t py -t rs        # Multiple types
```

### Context and Output Control
```bash
rg -C 3 pattern               # 3 lines before AND after match
rg -A 5 pattern               # 5 lines after
rg -B 2 pattern               # 2 lines before
rg -l pattern                 # List filenames with matches only
rg -c pattern                 # Count matches per file
rg -w word                    # Whole word match (not substring)
rg -i pattern                 # Case insensitive
rg -s Pattern                 # Force case sensitive
rg -n pattern                 # Show line numbers (default in tty)
```

### Hidden and Ignored Files
```bash
rg -u pattern                 # Include hidden files
rg -uu pattern                # Include hidden + gitignored
rg -uuu pattern               # Unrestricted (everything including binary)
```

### Exclusions
```bash
rg pattern -g '!node_modules/'           # Exclude directory
rg pattern -g '!{dist,build,target}/'    # Exclude multiple
rg pattern -g '!*.min.js'                # Exclude pattern
rg pattern --max-filesize 1M             # Skip large files
rg pattern --max-depth 3                 # Limit directory depth
```

### Search and Replace (preview only)
```bash
rg pattern --replace new       # Show replacements (doesn't modify files)
rg '(\w+)@(\w+)' -r '$2::$1'  # With capture groups
```

## Common Code Search Patterns

```bash
# Find definitions
rg '^def \w+\(' -t py          # Python functions
rg 'fn \w+\(' -t rs            # Rust functions
rg '^\s*class \w+' -t py       # Python classes
rg '^function \w+\(' -t js     # JavaScript functions

# Find imports
rg '^import' -t py
rg '^(import|require)' -t js

# Find markers (use -c to count first!)
rg -c 'TODO|FIXME|HACK'

# Security audit
rg -i 'password|api_key|secret|token' -g '!*.{lock,log}'

# Word boundary — match 'count' not 'counter' or 'account'
rg -w 'count' -t rs

# Files with most matches
rg -c pattern | sort -t: -k2 -rn | head -10
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Regex chars in literal search | Use `-F` for fixed strings |
| Output floods context window | Use `-l`, `-c`, or `-m N` first |
| Missing hidden/gitignored files | Use `-u`, `-uu`, or `-uuu` |
| Lookbehind/lookahead fails | Add `-P` for PCRE2 mode |
| `{` causes "invalid regex" | Escape as `\{` or use `-F` |
| Wrong file type name | Run `rg --type-list` to check |
| Too broad search scope | Add path or `-t type` |
| Matching substrings of word | Use `-w` for whole word |
