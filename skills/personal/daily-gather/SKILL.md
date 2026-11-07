---
name: daily-gather
description: Read-only pre-gather for daily-start — collect the day's context (Day flow, goals, yesterday's note, Things Inbox, calendar) and write a briefing file so the morning /daily-start is instant. Use when the user says "/daily-gather", or when run unattended by the morning launchd job.
---

# Daily Gather

The **read-only** front half of `/daily-start`. Gathers all the context that
normally takes several minutes of MCP round-trips and writes it to a briefing
file. When `/daily-start` runs later and finds a fresh briefing, it skips the
gathering and jumps straight to triage — turning a ~5-minute cold start into
a few seconds.

This skill **mutates nothing**: no Things updates, no calendar writes, no daily
note. It only reads and writes one briefing file. That is what makes it safe to
run unattended on a schedule (see `launchd/README.md`).

## Constants

Read `../config.md` (relative to this skill's directory) for personal values
(timezone, calendar IDs). If it doesn't exist, stop and tell the user to run
`/setup`.

- **Day flow file**: `Areas/Life OS/Day flow.md`
- **Daily notes path**: `Dailies/{YYYY-MM-DD}.md`
- **Briefing file**: `Dailies/.briefing-{YYYY-MM-DD}.md` (gitignored, Obsidian-hidden)

## Steps

### 1. Get current date/time

Run `date +%Y-%m-%d`, `date +%A`, and `date +%H:%M`. Do NOT guess the day of week.

### 2. Bail if today's note already exists

If `Dailies/{date}.md` already exists, the day is already planned — do not write
a briefing (it would be stale/pointless). Print a one-line note and stop.

### 3. Gather context in parallel

- Read `Areas/Life OS/Day flow.md` — observed scheduling preferences
- Read `Areas/Career/Career Talk 2026/Performance Goals.md` — work performance goals
- Read `Areas/Life OS/🔭 Goals.md` — life goals
- Read yesterday's daily note (Mon: try Sun → Fri → most recent; other days: try
  yesterday → most recent). Extract `🔮 For Tomorrow` items, unfinished
  priorities, open Log threads.
- `mcp__things__get_inbox` — every item (needs triage)
- `mcp__things__get_today` — items already scheduled for today
- `mcp__things__get_tagged_items` tag=`side-quest`
- `mcp__things__get_anytime` — first 10 for context
- `mcp__claude_ai_Google_Calendar__list_events` on work calendar, today 00:00–23:59
- `mcp__claude_ai_Google_Calendar__list_events` on Personal planning calendar for today

If any single source fails (e.g. an MCP connector is unavailable in the headless
run), do NOT abort. Capture whatever you can and note the gap in the briefing
under a `⚠️ Gather gaps` line, so the live `/daily-start` knows to re-pull it.

### 4. Write the briefing file

Write to `Dailies/.briefing-{date}.md`. Use tabs for any indentation (Obsidian
config). The body is the fully-formatted step-4 triage prompt from `daily-start`,
with all data already filled in — so the live run can present it verbatim.

```
---
gathered: {HH:MM}
date: {YYYY-MM-DD}
day: {day}
---

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

🔭 Goals pulse:
{top 2–3 performance goals, one line each}
{top 1–2 life goals, one line each}

→ Does at least one of today's priorities move one of these?

{⚠️ Gather gaps: <sources that failed, if any> — omit this line if none}
```

### 5. Report

Print one line: `Briefing written: Dailies/.briefing-{date}.md (gathered {HH:MM})`.
When run unattended this goes to the launchd log; when run by hand the user sees it.

## Rules

- Read-only except for the single briefing file. Never touch Things, the calendar,
  or the daily note.
- Never fabricate data to fill a section. Empty is empty; a failed source is a gap.
- The briefing is disposable — it's fine to overwrite an existing one for the same day.
