---
name: inbox-zero
description: Process the Things Inbox to zero by classification groups — agent pre-classifies the whole inbox, then walks one group at a time (references, junk, actionable). User confirms or corrects each group, then the remainder is processed by item number. Use when the user says "/inbox-zero", "clear my inbox", "process my Things inbox", or wants to get to inbox zero.
---

# Inbox Zero

Drive the Things Inbox to zero by classification groups: pre-classify everything, then walk one group at a time. Reference items first, junk next, then the actionable remainder by number. Every item leaves the Inbox via exactly one action verb.

## Setup (run once per session)

Fetch context in parallel:

- `mcp__things__get_inbox` — full inbox; keep the list in working memory
- `mcp__things__get_projects` (or equivalent) — every project name and id; keep in context so you can suggest project assignments without dumping the list on screen

If the Inbox is empty, say so and stop. Do not invent work.

## Pre-classify the whole inbox

Walk the entire inbox once and label each item with one tag:

- **reference** — looks like a note, link, or piece of information rather than an action ("read later" material, a quote, a URL with no verb)
- **junk** — empty title, garbled, obvious noise, duplicate of an item already actioned elsewhere
- **actionable** — everything else (default)

Be conservative on reference and junk. When in doubt, classify as actionable. The user will correct misclassifications inline.

## The three passes

Walk the groups in this order: **references → junk → actionable**. Show one group at a time and wait for input before moving to the next.

### Soft display cap

If a group has more than ~20 items, show the first 20 and append `…and {N} more like this — show all?` Let the user say "show all" to dump the rest. Do not split into arbitrary slices.

### Pass 1 — Reference

```
📚 Reference candidates ({N})

These all look like reference material — confirm to file them all with tag `reference` and move to Someday.
Reply with corrections: "3 is not reference, schedule today" / "drop 5 and 7" / "all good".

 1. Article: "On the design of agent loops"
 2. https://example.com/post
 3. ...
```

For each item the user confirms:
- `update_todo` with `tags: ["reference", …any extras the user adds]` and `when: "someday"`

If the user asks to add extra tags or notes for an item, capture them in the same `update_todo` call. Ask "anything to add for context?" only if the user gives a vague nod — do not pester on every item.

For corrections ("3 is not reference, schedule today"): drop the classification and apply the requested verb instead.

### Pass 2 — Junk

```
🗑  Junk candidates ({N})

These all look like deletions — confirm to cancel them all.
Reply with corrections: "2 is real, leave it" / "all good".

 1. asdfasdf
 2. (empty)
 3. ...
```

For confirmed items: `update_todo` with `canceled: true`.

For corrections: the item moves back into the actionable pool.

### Pass 3 — Actionable remainder

Now the easy stuff is gone. Re-number what's left and process it by item number:

```
✅ Actionable ({N} left)

 1. Finish Q3 report draft
 2. Email Sara about the workshop
 3. ...

Tell me what to do. Examples:
  "1 today; 2 friday; project 'workshop prep' for 3, 5; rest someday"
  "delete 4; today 1, 7; the rest anytime"
```

Parse the user's instruction liberally. Recognise these verbs:

| Verb              | Effect                                                                                     |
| ----------------- | ------------------------------------------------------------------------------------------ |
| `today`           | `update_todo` with `when: "today"`                                                         |
| `tomorrow`        | `update_todo` with `when: "tomorrow"`                                                      |
| `<date>` / `<day>`| `update_todo` with `when: "<YYYY-MM-DD>"` — resolve relative dates against today's date    |
| `anytime`         | `update_todo` with `when: "anytime"`                                                       |
| `someday`         | `update_todo` with `when: "someday"`                                                       |
| `project <name>`  | `update_todo` with `list: "<project id>"` — match name against the cached projects list    |
| `delete` / `kill` | `update_todo` with `canceled: true`                                                        |
| `reference`       | `update_todo` with `tags: ["reference", …extras]` and `when: "someday"`                    |
| `rest <verb>`     | Apply `<verb>` to every item not yet acted on                                              |

If an instruction is ambiguous (unknown project name, unparseable date), ask before acting. Do not guess destructively.

If the actionable list is long, you may take input in waves — apply what the user told you, then show the remaining items renumbered, ask for the next round. Do not force a fixed batch size.

## Special moves

### Project suggestions

When you spot an actionable item that obviously fits a cached project, suggest it inline: "2 looks like **workshop prep** — assign it?" Only suggest projects that exist in the cached list. Do not invent project names.

### Suggesting a new project

If you see **two or more actionable items that clearly belong together** in a coherent body of work, or **a single item that reads as a multi-step undertaking rather than one task**, suggest creating a new project:

> "Items 1, 4, and 9 all look like pieces of the same effort — want me to spin up a project for them? Suggested name: **Q3 reporting**."

On confirmation, create the project (via `mcp__things__add_project` or equivalent) and assign those items to it.

### "What are my projects?"

If the user asks, list the cached projects from setup. Do not re-fetch.

## Rules

- One group at a time. Do not show junk before references are cleared, and do not show actionable before junk is cleared.
- Every action verb removes the item from the Inbox. If an item is still in Inbox after a pass, you missed it — flag and ask.
- Classification is a suggestion, never an action. Never apply a delete or a reference-file without the user confirming the group (or the specific items).
- Dictation-friendly parsing: accept loose grammar, item-number ranges ("3 through 6"), and trailing "the rest" clauses.
- If a Things MCP tool you need does not exist (e.g. no `get_projects`), tell the user and ask how to proceed rather than skipping silently.

## Done

Stop when `get_inbox` returns zero items, or when the user says they're done. End with a one-line summary:

> "📭 Inbox zero. Processed {N} items: {breakdown by verb}."
