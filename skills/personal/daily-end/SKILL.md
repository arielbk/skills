---
name: daily-end
description: Close out the working day in the Obsidian vault — compare planned vs actual, capture wins/TIL/tomorrow, update Day flow with observed patterns. Use when the user says "/daily-end", "wrap up the day", "end of day", or wants to close out today's note.
---

# Daily End

Close out today's daily note: compare what was planned against what actually happened, capture wins/TIL/tomorrow, and append any observed patterns to `Day flow` so the next day's plan gets smarter.

This skill is stateless — it derives all context from the daily note, calendar APIs, and Granola. Works correctly in a fresh `/clear`ed session.

## Constants

Read `../config.md` (relative to this skill's directory) for personal values (timezone, calendar IDs). The config file is gitignored and not committed to the repo. If it doesn't exist, tell the user to run `/setup`.

- **Day flow file**: `Areas/Life OS/Day flow.md`
- **Daily notes path**: `Dailies/{YYYY-MM-DD}.md`

## Steps

### 1. Get current date

Run `date +%Y-%m-%d`.

### 2. Fetch end-of-day context in parallel

- Read `Dailies/{date}.md`
- `mcp__claude_ai_Google_Calendar__list_events` on Personal planning calendar for today — the proposed schedule
- `mcp__claude_ai_Google_Calendar__list_events` on work calendar for today — actual meetings
- `mcp__granola__list_meetings` → fetch notes for today's meetings with `mcp__granola__get_meeting_transcript`
- Read `Areas/Life OS/Day flow.md`
- `pmdr today --json` — completed pomodoros grouped by project, as a data point on deep-work blocks

### 3. Compute planned vs actual from the Log

Parse the `📓 Log` section. For each proposed calendar block, check whether a matching activity appears in the Log. Identify:
- Completed
- Skipped or deferred
- Unplanned (appeared in Log but not on calendar)
- Overran (Log time exceeded block time)

### 4. Present reflection prompt

```
🌙 Wrapping up {day}, {date}.

📊 Planned vs. actual

Proposed (Personal planning calendar):
{time blocks}

What the Log shows:
{summary of Log themes with rough durations}

Delta:
✅ Completed: {...}
⏭️ Skipped or deferred: {...}
🌀 Unplanned: {...}
⏰ Overran: {...}

🎯 Priorities today:
{priorities with ✅ where applicable}

⚔️ Side quests:
{side quests}

📝 Granola meeting notes:
{condensed key points + action items}

🍅 Pomodoros (deep-work blocks):
{per-project: N pomodoros, total time} — total {sum}

---

1. Wins today? (big or small)
2. TIL?
3. Priority check — which got done? Notes on the rest?
4. For tomorrow — anything to carry, prep, or remember?
5. Anything worth codifying about how today actually ran?
   (e.g. "afternoon focus block worked", "morning admin never gets done")
```

### 5. Update today's daily note

- Fill `🤓 TIL` and `🎉 Wins` sections
- Add Granola meeting notes to `📝 Notes`
- Mark completed priorities with ✅
- Add `## 🔮 For Tomorrow` section with carry-forward items

### 6. Update Day flow if patterns emerged

If the user named a pattern in answer 5, OR if the planned-vs-actual delta reveals a clear pattern (e.g. third consecutive skipped morning admin block), append to `Areas/Life OS/Day flow.md` under `## Patterns and adjustments`:

```
- {date} ({first observation|repeated|confirmed}): {pattern observed}. Next: {scheduling adjustment implied}.
```

Do not rewrite existing entries — append only. Every 10–15 entries, offer to consolidate into `Scheduling rules (observed)` and archive older entries.

**Use tabs (not spaces) for all indentation** (Obsidian config).

## Rules

- Never invent a pattern. If the day doesn't clearly show one, don't write to Day flow.
- Prefer Edit over Write for existing files.
- If the Log is empty or minimal, skip planned-vs-actual and just do the reflection pass.
