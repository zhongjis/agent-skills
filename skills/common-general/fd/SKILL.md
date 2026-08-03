---
name: fd
description: "Fast file finding using fd command-line tool with smart defaults, gitignore awareness, and parallel execution. Use when: finding files by name, extension, or path pattern; filtering by metadata (size with --size +10m, modification time with --changed-within 1d, type with -t f/d/l/x); locating project roots (fd -t f '^Cargo.toml$' --format '{//}'); batch executing commands on found files (fd -e log -x rm); cleanup operations (removing node_modules, old logs, .pyc bytecache, .DS_Store); building file lists for downstream tools. Also use fd as a fallback when searching for files by content if no dedicated content search tool like rg is available. Do NOT use fd for: finding empty directories (use find -empty), complex boolean logic, or POSIX compliance."
upstream: "https://github.com/laurigates/claude-plugins/tree/main/tools-plugin/skills/fd-file-finding"
---

# fd File Finding

Expert knowledge for using `fd` as a fast, user-friendly alternative to `find` with smart defaults and powerful filtering.

## When to Use This Skill

| Use this skill when... | Use rg instead when... |
|---|---|
| Finding files by name, extension, or path pattern | Searching inside file contents for text or regex |
| Filtering by mtime (`--changed-within`) or size (`--size`) | Filtering matches by file type (`-t py`, `-t js`) |
| Locating files to feed into `-x` / `-X` execution | Auditing source code for patterns across many files |
| Batch executing commands on found files (`-x`, `-X`) | |
| Cleanup ops: remove `node_modules`, old logs, `.pyc`, `.DS_Store` | |
| Locating project roots via marker files (`Cargo.toml`, `package.json`) | |
| Building file lists for downstream tools or pipelines | |

| Use this skill when... | Use jq or yq instead when... |
|---|---|
| Discovering JSON, YAML, or other files on disk | Querying or transforming the contents of those files |
| Building a file list for downstream batch processing | Extracting fields, filtering arrays, or reshaping JSON |

| Use this skill when... | Use find instead when... |
|---|---|
| Most file-finding tasks (fd is faster and simpler) | Complex boolean logic or POSIX compliance required |
| Gitignore-aware searches | Finding empty directories (`find -empty`) |
| Parallel execution with `-x` / `-X` | Advanced permission checks or non-standard attributes |

**Content search fallback:** If the user asks to search file contents (e.g., "find files containing X") and no dedicated content search tool (rg, grep) is available, use fd to first locate relevant files, then pipe to grep: `fd -e py -x grep -l "pattern" {}`

## Basic Usage

```bash
# By name/extension
fd config                       # Files named config
fd -e rs                        # All Rust files
fd -e js -e ts                  # JavaScript and TypeScript
fd -s Config                    # Case-sensitive

# Patterns
fd '^test_.*\.py$'              # Regex: Python test files
fd -g '*.config.js'             # Glob: config files

# Type filtering: -t f(ile) d(ir) l(ink) x(ecutable)
fd -t f pattern                 # Files only
fd -t d pattern                 # Directories only
fd -t x pattern                 # Executables only

# Depth
fd -d 1 pattern                 # Current directory only
fd -d 3 pattern                 # Max 3 levels deep

# Hidden and ignored files
fd -H pattern                   # Include hidden (dotfiles)
fd -I pattern                   # Include .gitignore'd files
fd -u pattern                   # Unrestricted: hidden + ignored
```

## Advanced Features

```bash
# Size filtering
fd --size +10m              # Larger than 10 MB
fd --size +100k --size -10m # Between 100 KB and 10 MB

# Modification time
fd --changed-within 1d      # Last 24 hours
fd --changed-within 2w      # Last 2 weeks
fd --changed-before 1y      # Older than 1 year

# Execute on results: -x (each) / -X (batch)
fd -e jpg -x convert {} {.}.png     # Convert JPG→PNG
fd -e rs -x rustfmt                 # Format all Rust files
fd -e md -X wc -l                   # Word count all Markdown

# Output format placeholders: {} {/} {//} {.} {/.}
fd -e tf --format '{//}'            # Parent directory
fd -e rs --format '{/}'             # Filename only

# Integration with other tools
fd -e py -x rg "import numpy" {}    # Search within found files
fd -e md -X nvim                    # Open all in editor
```

## Common Patterns

```bash
# Test files
fd '^test_.*\.py$'                  # Python tests
fd -e test.js -e spec.js            # JavaScript tests

# Config and env files
fd -g '.env*' -H                    # Environment files (include hidden)
fd -g '*rc' -H                      # RC files

# Cleanup
fd -e pyc -x rm                     # Remove Python bytecode
fd node_modules -t d -x rm -rf      # Remove node_modules
fd -g '*.log' --changed-before 30d -X rm  # Remove old logs

# Path scope
fd -e ts -e tsx src/                # TypeScript in src/
fd -e js -E node_modules -E dist    # Exclude multiple paths
fd -p src/components/.*\.tsx$       # Match full path
```

### Find Directories Containing Specific Files
```bash
# Pattern: fd -t f '^marker$' --format '{//}'
fd -t f '^Cargo\.toml$' --format '{//}'   # Rust project roots
fd -t f '^package\.json$' --format '{//}' # Node.js project roots
fd -t f '^go\.mod$' --format '{//}'       # Go module roots
```

**Note:** Use `--format '{//}'` instead of piping to xargs - it's faster and simpler.


## Quick Reference

### Essential Options

| Option | Purpose | Example |
|--------|---------|---------|
| `-e EXT` | Filter by extension | `fd -e rs` |
| `-t TYPE` | Filter by type (f/d/l/x) | `fd -t d` |
| `-d DEPTH` | Max search depth | `fd -d 3` |
| `-H` | Include hidden files | `fd -H .env` |
| `-I` | Include ignored files | `fd -I build` |
| `-u` | Unrestricted (no ignore) | `fd -u pattern` |
| `-E PATH` | Exclude path | `fd -E node_modules` |
| `-x CMD` | Execute command | `fd -e log -x rm` |
| `-X CMD` | Batch execute | `fd -e md -X cat` |
| `-s` | Case-sensitive | `fd -s Config` |
| `-g GLOB` | Glob pattern | `fd -g '*.json'` |
| `--format FMT` | Custom output format | `fd -e tf --format '{//}'` |

### Units
- **Time**: `s`=seconds, `m`=minutes, `h`=hours, `d`=days, `w`=weeks, `y`=years
- **Size**: `b`=bytes, `k`=KB, `m`=MB, `g`=GB, `t`=TB
