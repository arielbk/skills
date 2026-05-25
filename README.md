# skills

My own Claude Code skills — small, single-purpose, shaped around how I actually work. Shared in case they're useful or worth forking.

Big thanks to [Matt Pocock's skills](https://github.com/mattpocock/skills), which kicked this off and shaped how I think about them.

## What's here

Two kinds of skill, organised by folder:

- **`skills/engineering/`** — general-purpose dev workflow (planning, slicing work into tasks, TDD-driven implementation).
- **`skills/personal/`** — my daily-driver workflow, wired to my own stack (Obsidian, Things, Productive, Google Calendar). These read every personal value from a gitignored `config.md`, so fork them and adjust the prose to your own tools.

Browse the folders to see what's there — each skill's `SKILL.md` documents itself, and that's the source of truth (a README list here would just go stale).

## Install

```bash
npx skills add arielbk/skills
```

### Configure the personal skills

The personal skills read calendar IDs, timezone, and a Productive person ID from a gitignored `config.md`. Don't hand-edit it — run `/setup`, which detects your Claude config home and interactively writes `config.md` from your answers.

## Design principles

- **Align, don't spec.** Heavy spec-driven frameworks trade your control for process. Prefer interactive alignment over upfront specification.
- **Local artefacts over external trackers.** Plans, task lists, and decisions live in the repo as markdown the agent can edit.
- **Feedback loops are first-class.** Any task without a defined "how do we know this works" is under-specified.
- **Tasks are DAGs, not lists.** Explicit dependencies enable orchestration; positional ordering doesn't.
- **Small surface area.** Few skills, each doing one thing well, beats a maximal toolbox.
