# arielbk-skills

Personal Claude Code skills. Small, opinionated, built for how I actually work.

Inspired by [Matt Pocock's skills](https://github.com/mattpocock/skills) — alignment-first ethos, no heavy spec-driven framework.

## Skills

### Engineering

| Skill | What it does |
|---|---|
| [`/slice`](./skills/engineering/slice/SKILL.md) | Break aligned work into a vertical-slice DAG in `docs/<feature>/<feature>.tasks.md`. Outside-in, dependency-aware, feedback-loop-explicit. |
| [`/spec`](./skills/engineering/spec/SKILL.md) | Synthesise conversation context into a PRD at `docs/<feature>/<feature>.prd.md` |
| [`/implement`](./skills/engineering/implement/SKILL.md) | Execute a slice DAG end-to-end using TDD, log as it goes, generate a QA plan at the end |

### Personal (Obsidian + calendar workflows)

| Skill | What it does |
|---|---|
| [`/daily-start`](./skills/personal/daily-start/SKILL.md) | Build today's daily note, triage Things Inbox, draft a timed schedule, push it to Google Calendar |
| [`/daily-end`](./skills/personal/daily-end/SKILL.md) | Close out the day: planned-vs-actual, wins/TIL/tomorrow, update Day flow with observed patterns |
| [`/log`](./skills/personal/log/SKILL.md) | Append a timestamped entry to today's Log section — minimal, stateless, no context needed |
| [`/time-summary`](./skills/personal/time-summary/SKILL.md) | Parse the Log, calculate work hours, produce a Productive-ready summary |

Personal skills read `skills/personal/config.md` for calendar IDs, timezone, and other personal constants. Copy `skills/personal/config.example.md` and fill in your own values — it's gitignored.

## How it's wired

Each skill is symlinked into `~/.claude/skills/<name>` so Claude Code discovers it. No installer.

```bash
# Engineering
ln -s "$PWD/skills/engineering/slice" ~/.claude/skills/slice
ln -s "$PWD/skills/engineering/spec" ~/.claude/skills/spec
ln -s "$PWD/skills/engineering/implement" ~/.claude/skills/implement

# Personal
ln -s "$PWD/skills/personal/daily-start" ~/.claude/skills/daily-start
ln -s "$PWD/skills/personal/daily-end" ~/.claude/skills/daily-end
ln -s "$PWD/skills/personal/log" ~/.claude/skills/log
ln -s "$PWD/skills/personal/time-summary" ~/.claude/skills/time-summary
```

## Why this repo exists

Two reasons:

1. **Personal scratch space.** Skills I find genuinely useful, not a curated public set. Low bar to add, easy to throw away. The day a skill stops earning its keep, it goes.
2. **Eventual jumping-off point for an Infinum team repo.** Skills are written so the opinions are visible — if a skill graduates to team use, the design intent is legible.

## Design principles

- **Align, don't spec.** Heavy spec-driven frameworks (BMAD, Spec-Kit) trade your control for process. Prefer interactive alignment (`grill-me` style) over upfront specification.
- **Local artefacts over external trackers.** Plans, task lists, and decisions live in the repo as markdown the agent can edit.
- **Feedback loops are first-class.** Any task without a defined "how do we know this works" is under-specified.
- **Tasks are DAGs, not lists.** Explicit dependencies enable orchestration; positional ordering doesn't.
- **Small surface area.** Few skills, each doing one thing well, beats a maximal toolbox.

## Related

- [Matt Pocock's skills](https://github.com/mattpocock/skills) — the structural template and several skills (`grill-me`, `tdd`, `diagnose`) symlinked separately into `~/.claude/skills/`.
