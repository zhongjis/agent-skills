---
name: find-skills
description: Helps users discover agent skills when they ask questions like "how do I do X", "find a skill for X", "is there a skill that can...", or express interest in extending capabilities. Discovery only — for installing or maintaining skills, use the skill-maintainer skill.
adaptedFrom:
  - "https://github.com/vercel-labs/skills/tree/main/skills/find-skills"
---

# Find Skills

This skill helps you discover skills from the open agent skills ecosystem.

## When to Use This Skill

Use this skill when the user:

- Asks "how do I do X" where X might be a common task with an existing skill
- Says "find a skill for X" or "is there a skill for X"
- Asks "can you do X" where X is a specialized capability
- Expresses interest in extending agent capabilities
- Wants to search for tools, templates, or workflows
- Mentions they wish they had help with a specific domain (design, testing, deployment, etc.)

## What is the Skills CLI?

The Skills CLI (`npx skills`) is a search tool for the open agent skills ecosystem. Skills are modular packages that extend agent capabilities with specialized knowledge, workflows, and tools.

**Key command:**

- `npx skills find [query] [--owner <owner>]` - Search for skills interactively or by keyword, optionally scoped to a GitHub owner

**Browse skills at:** https://skills.sh/

## How to Help Users Find Skills

### Step 1: Understand What They Need

When a user asks for help with something, identify:

1. The domain (e.g., React, testing, design, deployment)
2. The specific task (e.g., writing tests, creating animations, reviewing PRs)
3. Whether this is a common enough task that a skill likely exists

### Step 2: Check the Leaderboard First

Check the [skills.sh leaderboard](https://skills.sh/) for established skills in the relevant domain. The leaderboard ranks skills by total installs and can surface widely used options before a broader search.

### Step 3: Search for Skills

If the leaderboard does not cover the user's need, run the find command with a relevant query:

```bash
npx skills find [query] [--owner <owner>]
```

For example:

- User asks "how do I make my React app faster?" -> `npx skills find react performance`
- User asks "can you help me with PR reviews?" -> `npx skills find pr review`
- User asks "I need to create a changelog" -> `npx skills find changelog`

### Step 4: Verify Quality Before Recommending

Do not recommend a skill based only on its search rank. Verify:

1. **Install count** — Prefer established skills with meaningful usage; flag low adoption
2. **Source reputation** — Prefer known maintainers and official project sources
3. **Repository activity** — Check stars, recent maintenance, and unresolved issues

### Step 5: Present Options to the User

When you find relevant skills, present them to the user with:

1. The skill name and what it does
2. The install count and source
3. The source URL to learn more at skills.sh

Example response:

```
I found a skill that might help! The "vercel-react-best-practices" skill provides
React and Next.js performance optimization guidelines from Vercel Engineering.
Source: vercel-labs/agent-skills
Installs: <current install count>

Learn more: https://skills.sh/vercel-labs/agent-skills/vercel-react-best-practices

To install this skill, use the skill-maintainer skill.
```

## Common Skill Categories

When searching, consider these common categories:

| Category        | Example Queries                          |
| --------------- | ---------------------------------------- |
| Web Development | react, nextjs, typescript, css, tailwind |
| Testing         | testing, jest, playwright, e2e           |
| DevOps          | deploy, docker, kubernetes, ci-cd        |
| Documentation   | docs, readme, changelog, api-docs        |
| Code Quality    | review, lint, refactor, best-practices   |
| Design          | ui, ux, design-system, accessibility     |
| Productivity    | workflow, automation, git                |

## Tips for Effective Searches

1. **Use specific keywords**: "react testing" is better than just "testing"
2. **Try alternative terms**: If "deploy" doesn't work, try "deployment" or "ci-cd"
3. **Check popular sources**: Many skills come from `vercel-labs/agent-skills` or `ComposioHQ/awesome-claude-skills`

## When No Skills Are Found

If no relevant skills exist:

1. Acknowledge that no existing skill was found
2. Offer to help with the task directly using your general capabilities
3. Suggest the user could create their own skill using the `skill-creator` skill

Example:

```
I searched for skills related to "xyz" but didn't find any matches.
I can still help you with this task directly! Would you like me to proceed?

If this is something you do often, you could create a custom skill
using the skill-creator skill.
```

## Installation and Maintenance

This skill handles **discovery only**. For installing, updating, or maintaining skills, use the **skill-maintainer** skill which manages:

- Adding skills from upstream repositories into this Nix config
- Updating existing skills from their upstream sources
- Provenance tracking via the `upstream` frontmatter field
- Vendor-neutral genericization of skill content
- Safer `/tmp` repo reuse: check whether the temp path exists, confirm the cached repo remote matches, refresh it when it does, remove it only when it points somewhere else
