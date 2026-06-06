---
name: setup
description: Interactively bootstrap the gitignored config.md that the personal skills read (timezone, calendar IDs, Productive person ID). Ships its own config.example.md and writes config.md to the shared skills root. Use when the user says "/setup", "set up the skills", "configure the personal skills", or has just installed this repo's skills and needs config.md filled in.
---

# Setup

Bootstrap the `config.md` that the personal skills read for their values (timezone, calendar IDs, Productive person ID). The installer (`npx skills add`) flattens each skill into `<claude-home>/skills/<name>`, so this skill **ships its own `config.example.md`** and writes `config.md` to the shared **skills root** — the directory the personal skills reach via `../config.md`.

## Why config lives at the skills root

Each personal skill reads `../config.md` relative to its own directory. After install every skill is a direct child of `<claude-home>/skills/`, so that resolves to **`<claude-home>/skills/config.md`** — the single target this skill writes. `config.example.md` is bundled inside this `setup/` skill so it always installs alongside it — never search the tree for it.

> Compute the target as the absolute path `<claude-home>/skills/config.md`, not as `../config.md` from this skill's own directory. When skills are installed as symlinks, the `setup` symlink and the personal-skill symlinks can point at different source folders, so a physically-resolved `..` from `setup` may land somewhere other than the skills root. The absolute skills-root path is unambiguous; that's where every personal skill's lexical `../config.md` lands.

## Steps

### 1. Locate this skill and its example

- This skill's directory is the base directory shown when the skill is invoked (e.g. `~/.claude/skills/setup`).
- The example is `config.example.md` in that directory. Read it — it's the field source of truth.
- The **target** is `../config.md` relative to this skill's directory (i.e. the skills root, `<claude-home>/skills/config.md`).

### 2. Detect other config homes (optional)

Some users keep more than one Claude home:

```bash
ls -d ~/.claude ~/.claude-* 2>/dev/null
```

For any sibling home that also has `skills/setup/config.example.md`, its target is `<home>/skills/config.md`. If more than one home has the skills installed, ask which to target — offer "all of them". The same answers fill every target.

### 3. Decide what to write (per target)

- **target `config.md` absent** → bootstrap it from scratch (step 4, all fields).
- **target present (regular file _or_ symlink)** → never overwrite, never replace a symlink. Read its current values, diff against the example, and only prompt for fields that are missing or still hold the example placeholder. If nothing is missing, report it's already complete and move on.

### 4. Walk the fields interactively

Each example field is a markdown bullet:

```
- **Label**: `placeholder` (optional one-line hint)
```

For each field that needs a value:

1. Show the label, the hint, and the placeholder as the default.
2. Ask the user for the value in chat (free-form). Use `AskUserQuestion` only when a small set of choices genuinely applies; otherwise just ask plainly and read the reply.
3. Keep the example's section headings and field labels identical.

### 5. Write config.md

Write the target `config.md`, mirroring the example's structure exactly (same headings, same field labels), with the placeholder values replaced by the user's answers. Preserve any inline hints as-is. If the target is a symlink, write **through** it — do not unlink or replace it with a regular file.

`config.md` is user-local and gitignored — never stage or commit it.

### 6. Report

Summarise per target: path written, fields filled, fields skipped (already set). If you wrote to more than one home, note each.

## Notes

- Idempotent: re-running never clobbers an existing `config.md`; it only fills gaps.
- `config.example.md` ships with this skill and is committed; `config.md` is user-local — never commit or stage it.
- Do not invent values — every field comes from the user's answer or the existing file.
