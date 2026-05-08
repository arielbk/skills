---
name: log
description: Append timestamped entries to today's daily note Log in the Obsidian vault. Minimal and stateless — works in a fresh session with no prior context. Use when the user says "/log", "log this", "I'm taking a break", "back", "done for the day", or describes an activity they want recorded.
---

# Log

Append one or more timestamped entries to the `📓 Log` section of today's daily note. Requires no prior conversation context.

## Steps

1. Run `date +%Y-%m-%d` and `date +%H:%M`.
2. Read `Dailies/{date}.md` — look at the `📓 Log` section for existing entries.
3. Parse the user's message into one or more entries using the entry types below.
4. If the last Log entry already has the same timestamp and description, skip it and say so.
5. Use `Edit` to append new line(s) after the last bullet in the `📓 Log` section.
6. Confirm with one line per entry: `✅ Logged: HH:MM — description`

## Entry types

| User says | Format |
|---|---|
| Break with duration | `- HH:MM — {N}m break, {description}` |
| Break without duration | `- HH:MM — break` |
| Step away | `- HH:MM — away ({reason})` |
| Return | `- HH:MM — back` |
| End of day | `- HH:MM — end` |
| Anything else | `- HH:MM — {description}` |

## Format rules

- One bullet per entry: `- HH:MM — description`
- 24-hour time only
- Use tabs for indentation (Obsidian config)
- Never rewrite, reorder, or delete existing Log entries

## Examples

| User says | Appended |
|---|---|
| "working on The Class setup" | `- 11:00 — The Class setup` |
| "taking a break" | `- 14:22 — break` |
| "lunch, about 45 mins" | `- 12:35 — 45m break, lunch` |
| "back from lunch" | `- 13:20 — back` |
| "brb, courier at the door" | `- 10:15 — away (courier)` |
| "done for the day" | `- 18:02 — end` |
