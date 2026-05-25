---
name: setup
description: Interactively bootstrap config for skills that ship a config.example.md. Detects the user's Claude config home(s), then for each such skill walks every field, prompts the user for a value, and writes a filled config.md — no hand-editing. Use when the user says "/setup", "set up the skills", "configure the personal skills", or has just installed this repo's skills and needs config.md filled in.
---

# Setup

Bootstrap the gitignored `config.md` that personal skills read for their values. The installer (`npx skills add`) puts skill files on the machine; this skill owns config only.

The logic keys off the presence of a `config.example.md` next to a skill, so it works for any skill group that ships one — today that's `skills/personal/`.

## Steps

### 1. Detect config home(s)

Look for Claude config directories the installed skills could live under:

```bash
ls -d ~/.claude ~/.claude-* 2>/dev/null
```

- If exactly one exists, use it.
- If more than one (e.g. `~/.claude` and a sibling like `~/.claude-work`), ask the user which to target — offer "all of them" as an option.
- If none of the candidate skill locations contain a `config.example.md`, fall back to this repo's own checkout (the directory this skill lives in).

### 2. Find skills that ship a config.example.md

In each target location, find every `config.example.md`:

```bash
find <target> -name config.example.md -not -path '*/node_modules/*'
```

Each hit is one config group. Process each independently.

### 3. For each group, decide what to write

Let `example` be the `config.example.md` and `config` be `config.md` in the same directory.

- **`config.md` absent** → bootstrap it from scratch (step 4, all fields).
- **`config.md` present** → never overwrite. Read it, diff its fields against `example`, and only prompt for fields that are missing or still hold the example placeholder. If nothing is missing, report that it's already complete and move on.

### 4. Walk the fields interactively

Read `example`. Each field is a markdown bullet of the form:

```
- **Label**: `placeholder` (optional one-line hint)
```

For each field that needs a value:

1. Show the label, the hint, and the placeholder as the default.
2. Ask the user for the value in chat (free-form). Use `AskUserQuestion` only when a small set of choices genuinely applies; otherwise just ask plainly and read the reply.
3. Keep the user's section headings and structure identical to `example`.

### 5. Write config.md

Write `config.md` next to its `config.example.md`, mirroring the example's structure exactly (same headings, same field labels), with the placeholder values replaced by the user's answers. Preserve any inline hints as-is.

`config.md` is gitignored — confirm it's covered by `.gitignore` and never stage it.

### 6. Report

Summarise per group: path written, fields filled, fields skipped (already set). If you targeted multiple config homes, note each.

## Notes

- Idempotent: re-running never clobbers an existing `config.md`; it only fills gaps.
- Never commit or stage `config.md`.
- Do not invent values — every field comes from the user's answer or the existing file.
