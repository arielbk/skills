---
name: inbox-zero
description: Process the Things Inbox to zero in batched passes — show 12 items at a time, pre-classify likely-junk and likely-reference, take bulk commands by item number, and apply actions via the Things MCP. Use when the user says "/inbox-zero", "clear my inbox", "process my Things inbox", or wants to get to inbox zero.
---

# Inbox Zero

Drive the Things Inbox to zero by paginating it in batches of 12, pre-classifying each batch, and processing items one verb at a time. GTD-style: every item leaves the Inbox via exactly one of the action verbs below.

## Setup (run once per session)

Fetch context in parallel:

- `mcp__things__get_inbox` — full inbox; keep the list in working memory
- `mcp__things__get_projects` (or equivalent) — every project name and id; keep in context so you can suggest project assignments without dumping the list on screen

If the Inbox is empty, say so and stop. Do not invent work.

## The loop

Process the inbox in slices of **12 items at a time**, in inbox order. For each slice:

### 1. Pre-classify

Scan the 12 items and label each one with at most one tag:

- **junk** — empty title, garbled, obvious noise, duplicate of an item already in another list
- **reference** — looks like a note, link, or piece of information rather than an action ("read later" material, a quote, a URL with no verb)
- *(unlabeled — actionable)*

Be conservative. If unsure, leave it unlabeled. The user will correct misclassifications by number.

### 2. Present the batch

Show the slice in a numbered list. Append the classification tag inline:

```
📥 Inbox — batch 1 of {N} ({remaining} items left)

 1. Finish Q3 report draft
 2. asdfasdf                                   [junk?]
 3. Article: "On the design of agent loops"    [reference?]
 4. Email Sara about the workshop
 5. ...
12. ...

Suggestions:
- Likely junk to delete: 2, 7
- Likely reference: 3, 9

Tell me what to do. Examples:
  "delete 2, 7; reference 3, 9; today 1, 4; project 'workshop prep' for 5, 8; rest someday"
  "1 today; 3 is not reference, schedule for friday; everything else delete"
```

### 3. Parse the user's instruction

The user will speak loosely (often dictated). Parse liberally. Recognise these verbs:

| Verb              | Effect                                                                                     |
| ----------------- | ------------------------------------------------------------------------------------------ |
| `today`           | `update_todo` with `when: "today"`                                                         |
| `tomorrow`        | `update_todo` with `when: "tomorrow"`                                                      |
| `<date>` / `<day>`| `update_todo` with `when: "<YYYY-MM-DD>"` — resolve relative dates against today's date    |
| `anytime`         | `update_todo` with `when: "anytime"`                                                       |
| `someday`         | `update_todo` with `when: "someday"`                                                       |
| `project <name>`  | `update_todo` with `list: "<project id>"` — match name against the cached projects list    |
| `delete` / `kill` | `update_todo` with `canceled: true`                                                        |
| `reference`       | `update_todo` with `tags: ["reference", …extras]` and `when: "someday"` to remove from Inbox |
| `rest <verb>`     | Apply `<verb>` to every item in this slice not yet acted on                                |

If the user corrects a classification ("3 is not reference"), drop that tag and ask what to do with the item instead.

If an instruction is ambiguous (an unknown project name, a date you can't parse), ask before acting. Do not guess destructively.

### 4. Apply the actions, then advance

Execute the updates via the Things MCP. Confirm in one line: "✅ Done — moved 12 items: 4 today, 2 deleted, 2 reference, 1 project, 3 someday."

Re-fetch the inbox with `mcp__things__get_inbox` and start the next batch. Continue until the inbox is empty or the user stops.

## Special moves

### Project suggestions

When matching items to projects, suggest a project inline if you see an obvious fit ("4 looks like it belongs in **workshop prep** — confirm?"). Only suggest projects that exist in the cached list. Do not invent project names.

### Suggesting a new project

If you notice **two or more inbox items that clearly belong together** in a coherent body of work, or **a single item that reads as a multi-step undertaking rather than one task**, suggest creating a new project:

> "Items 1, 4, and 9 all look like pieces of the same effort — want me to spin up a project for them? Suggested name: **Q3 reporting**."

On confirmation, create the project (via `mcp__things__add_project` or equivalent) and assign those items to it.

### "What are my projects?"

If the user asks, list the cached projects from setup. Do not re-fetch.

### Reference items — extra context

When tagging an item as `reference`, ask if the user wants to add extra tags or a note ("anything to add for context?"). If they say no, proceed with just the `reference` tag. If they provide more, include those as additional tags or append to the item's notes via `update_todo`.

## Rules

- One batch at a time. Do not show batch 2 before batch 1 is applied.
- Every action verb removes the item from the Inbox. If an item is still in Inbox after the slice, you missed it — flag and ask.
- Dictation-friendly parsing: accept loose grammar, item-number ranges ("3 through 6"), and trailing "the rest" clauses.
- Never delete an item the user did not explicitly call out — even if you classified it as junk. Classification is a suggestion, not an action.
- If a Things MCP tool you need does not exist (e.g. no `get_projects`), tell the user and ask how to proceed rather than skipping silently.

## Done

Stop when `get_inbox` returns zero items, or when the user says they're done. End with a one-line summary:

> "📭 Inbox zero. Processed {N} items: {breakdown by verb}."
