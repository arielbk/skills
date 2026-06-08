# agents

Custom sub-agent definitions that pair with the skills in this repo (currently the `/implement` crew: `slice-agent`, `slice-reviewer`, `qa-writer`). Each file's frontmatter documents itself — that's the source of truth.

The skills reference these agents by name and fall back gracefully when they aren't installed — so linking is the part that matters.

## Install

Claude Code discovers agents in `~/.claude/agents/` (global) or `.claude/agents/` (per project), and **scans recursively** — so symlink this whole directory once and every agent in it, including ones added later, is picked up automatically:

```bash
# global — all projects
ln -s "$PWD/.agents" ~/.claude/agents/arielbk-skills

# per project
ln -s /path/to/arielbk-skills/.agents /path/to/project/.claude/agents/arielbk-skills
```

The subdirectory name doesn't matter — agent identity comes only from the `name:` frontmatter field, which must stay unique across everything you have installed.

Verify with `/agents` (Library tab) in any session.

## Sync

`slice-agent.md` doubles as the system-prompt form of `skills/engineering/implement/resources/slice-prompt.md`, which the `/implement` skill uses as a fallback when the agent isn't installed. Edit both or neither.

## Design rule

A sub-agent only saves context when both directions are narrow: the brief goes by reference (file paths, slugs), and the report comes back by contract (a status tag, a path, a capped summary). Every agent here ends with an **Output contract** section enforcing the return half; the skills' spawn messages enforce the other half.
