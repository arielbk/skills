---
name: daily-start
description: Start the working day in the Obsidian vault — build today's daily note, triage the Things Inbox, draft a timed schedule, and push it to Google Calendar. Use when the user says "/daily-start", "start my day", "set up today's note", or wants to plan their day.
---

# Daily Start

Build today's daily note, propose a realistic timed schedule, write that schedule onto the Personal planning calendar, and seed the Log with the start time.

## Constants

Read `skills/personal/config.md` for personal values (timezone, calendar IDs). The config file is gitignored and not committed to the repo.

- **Day flow file**: `Areas/Life OS/Day flow.md`
- **Daily notes path**: `Dailies/{YYYY-MM-DD}.md`
- **Template**: `Templates/Dailies.md`

## Steps

### 1. Get current date/time

Run `date +%Y-%m-%d`, `date +%A`, and `date +%H:%M`. Do NOT guess the day of week.

### 2. Check for existing note

If `Dailies/{date}.md` already exists, read it and skip to step 5 (schedule). Otherwise continue.

### 3. Gather context in parallel

- Read `Areas/Life OS/Day flow.md` — observed scheduling preferences
- Read yesterday's daily note (Mon: try Sun → Fri → most recent; other days: try yesterday → most recent). Extract `🔮 For Tomorrow` items, unfinished priorities, open Log threads.
- `mcp__things__get_inbox` — every item (needs triage)
- `mcp__things__get_today` — items already scheduled for today
- `mcp__things__get_tagged_items` tag=`side-quest`
- `mcp__things__get_anytime` — first 10 for context
- `mcp__claude_ai_Google_Calendar__list_events` on work calendar, today 00:00–23:59
- `mcp__claude_ai_Google_Calendar__list_events` on Personal planning calendar for today

### 4. Present triage prompt and ask for input

```
🌅 Good morning! Let's plan {day}, {date}.

📋 From yesterday:
{carry-forward items, open threads, for-tomorrow items}

📥 Things Inbox ({N} items — needs triage):
{numbered list}

✅ Already scheduled for today in Things ({N}):
{list}

⚔️ Side quests:
{list}

📅 Work calendar today:
{events}

---

1. What are today's 1–3 priorities?
2. Any energy notes? (tired, foggy, wired, etc.)
3. For each Inbox item: schedule today, defer, delete, or file to project/area?
   (Loose answers fine — "1, 3, 5 today; 2 delete; rest defer")
4. Any side quests to pull in?
```

### 5. Process Things Inbox based on answers

- "today" → `mcp__things__update_todo` with `when: today`
- "delete" → `mcp__things__update_todo` with `canceled: true`
- "file" → `mcp__things__update_todo` with relevant `list` or project
- "defer" → leave in Inbox

### 6. Draft a timed schedule

Use Day flow as the guide:
- Work calendar events are fixed — schedule around them
- Schedule the smallest concrete first action per priority, not the abstract goal
- Leave buffer gaps — do not overbook
- Include meal/break blocks if Day flow suggests them
- Present as a table. Ask: "Look OK, or want to adjust?"

### 7. On confirmation, write calendar events

For each block: `mcp__claude_ai_Google_Calendar__create_event` with `calendarId` = Personal planning ID and `timeZone` = the Timezone (both from `config.md`).
- Title: emoji + short label (`🎯 Workshop prep — outline section 2`)
- Description: which priority/side quest it ties to

### 8. Write the daily note

Write to `Dailies/{date}.md` using `Templates/Dailies.md` as structure. Fill in:
- Priorities
- Side Quests
- Schedule: bulleted mirror of calendar events (`HH:MM–HH:MM — label`)
- Log: seeded with `{current-time} — start`

**Use tabs (not spaces) for all indentation** (Obsidian config).

### 9. Check the pomodoro timer

Run `pmdr status --json`. Surface what you find:
- `state: "idle"` → nudge: "💡 No pomodoro running — start one with `pmdr start --project NAME --duration 25m --no-interactive &` when you begin the first block."
- `state: "running"` or `"paused"` → confirm: "✅ Pomodoro `{state}` for {project} ({remainingMs} remaining)."

Do **not** auto-start a timer. The user picks the project when they actually begin work.

### After completion

Tell the user:

> "Daily note is ready. You can **`/clear`** this session now — use **`/log`** during the day to append entries without conversation overhead. `/daily-end` and `/time-summary` read directly from the note and need no prior context."

## Rules

- Never write to the work calendar. Read-only.
- If Day flow is empty, still draft a schedule — it fills over time via `/daily-end`.
- Dictation-friendly: user may answer in one long stream. Parse liberally.
