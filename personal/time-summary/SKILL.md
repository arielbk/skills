---
name: time-summary
description: Parse the Log section of today's (or a specified) daily note in the Obsidian vault, calculate total work hours minus breaks, and produce a summary ready to paste into Productive. Use when the user says "/time-summary", "how long did I work", "calculate my hours", or wants a time breakdown for a day.
---

# Time Summary

Parse the `📓 Log` section of a daily note, calculate total work hours, apply the lunch benefit rule, and offer to log the entries directly to Productive.

## Steps

1. Determine which daily note to analyze:
   - If user provides a date, use it (format: YYYY-MM-DD)
   - Otherwise run `date +%Y-%m-%d` for today
   - Read `Dailies/{date}.md`

2. Parse the `📓 Log` section:
   - **Start**: `HH:MM — start` (fallback: earliest timestamp)
   - **End**: `HH:MM — end` (fallback: latest timestamp; if no end and date is today, use current time and note "in progress")
   - **Breaks**: `away`/`back` pairs, explicit durations like `20m break`, or any step-away entry
   - **Activities**: everything else

3. Calculate:
   - **Work time = (end − start) − total break time**
   - Multiple start/end pairs (split shift): calculate each session separately, then sum.
   - **Lunch benefit**: if work time is **≥ 5h30m** (greater than *or equal to* — at exactly 5h30m the benefit applies), add 30 minutes to total billable time. Note it explicitly in the summary.
   - **Round** the final billable total to the nearest 15 minutes.

4. Extract what was worked on:
   - Group activity descriptions into themes by project (use Slack threads, schedule, and log context)
   - Pull completed priorities (lines with ✅) and side quests

5. Present the summary:

```
⏱️ Time Summary for {Day}, {Date}

📊 Work Time
Start: {start}
End: {end}

Breaks: {total-break}
  - {HH:MM}–{HH:MM} — {description} ({duration})

Calculation: {elapsed} − {break} = {work-time}
{+ 30m paid lunch (work ≥ 5.5h) = {billable-total} → rounded to {rounded-total}}

📋 What You Worked On
  - {project}: {themes/activities}

---
💡 For Productive:
Total billable: {rounded-total}
Proposed split:
  - {Service name}: {time}
  - {Service name}: {time}
```

6. Ask the user to confirm or adjust the split, then log to Productive:
   - Look up service IDs via `search_resource` (type: `services`) if not already known
   - Look up person ID via `search_resource` (type: `people`) for your name if needed (see `skills/personal/config.md` for your Productive person ID)
   - Create one `time_entries` record per service with:
     - `time` in minutes
     - `date` as YYYY-MM-DD
     - `note` formatted as **plain markdown** — bullets with `- `, newlines between them, nesting via two-space indent. **Do NOT use HTML tags** (`<ul>`/`<li>` render literally in the Productive UI). No project name prefix (it's visible from the service context).
     - `person`: your Productive person ID from `config.md` (as a string — not an object)
     - `service`: the matched service ID (as a string)
   - Make notes specific: name the actual artefact or action ("Architecture walkthrough generation for review handoff"), not generic labels ("walkthrough work").

## Duration parsing

- `20m` → 20 min
- `1h` → 60 min
- `1h30m` → 90 min
- `1:30` → 90 min (accept but prefer letter form)

## Rounding

Round the final billable total to the nearest 15 minutes:
- e.g. 6h18m → 6h15m, 6h23m → 6h30m, 5h48m → 5h45m

## Break detection

Breaks are identified by:
- Explicit `away`/`back` pairs in the log — duration = time between them
- Explicit duration markers (`20m kid time`, `1h lunch`, etc.)
- Both can coexist: use the explicit duration if given, otherwise calculate from timestamps

## Edge cases

- No `end` entry + today's date → use current time, mark "in progress"
- Separators `–`, `—`, `-` are all accepted
- 24-hour preferred; 12-hour accepted
- If the project split is ambiguous (e.g. mixed work in one block), ask the user before logging

## Legacy format

Older notes may use a `⏱️ Time` section with `Started: HH:MM`, break lists, and `until HH:MM` markers. Fall back to parsing that format and present in the same output structure.
