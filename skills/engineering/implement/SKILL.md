---
name: implement
description: Execute a feature's task slices end-to-end using TDD, writing a log as it goes and generating a QA plan at the end. Reads docs/{feature}/{feature}.tasks.md. Use when user says "/implement", "implement this", or "start building". Pass the feature name as an argument, e.g. /implement checkout-flow.
---

# Implement

Execute a feature's slice DAG from `docs/{feature}/{feature}.tasks.md`. Work through each unblocked slice using TDD, keep a running log, and generate a QA plan when done.

**Resources (load when needed):**
- [tdd-loop.md](resources/tdd-loop.md) — red/green/refactor loop and test quality rules
- [log-format.md](resources/log-format.md) — how to write log entries
- [qa-template.md](resources/qa-template.md) — QA plan structure

## Process

### 1. Identify the feature

**If a feature name was passed as an argument** → look for `docs/{feature}/{feature}.tasks.md`. If not found, tell the user.

**If no argument was given** → scan `docs/` for directories containing a `{name}.tasks.md` file. Present the options:

```
Available features:
  1. checkout-flow   (3 of 7 slices done)
  2. dark-mode       (not started)

Which would you like to implement?
```

### 2. Read the tasks file

Load `docs/{feature}/{feature}.tasks.md`. Parse all slices, their statuses, and their `Depends on:` fields.

### 3. Pick the next slice

Select the highest-priority unblocked slice: **status is `not-started`** and all `Depends on:` slices have status `done`.

If no slices are unblocked (all remaining are blocked or in-progress), report what's blocking and stop.

### 4. Execute the slice with TDD

Load [tdd-loop.md](resources/tdd-loop.md) before starting.

For each slice:
1. Set **Status** to `in-progress` in the tasks file.
2. Explore the relevant code if needed.
3. Work through behaviors using the red→green loop — one test, one implementation, repeat.
4. Never reference the PRD, tasks file, or any planning document in code comments.
5. When all behaviors pass and code is clean, set **Status** to `done` (or `needs-review` if `Human checkpoint: yes`).

### 5. Write a log entry

After each slice completes, load [log-format.md](resources/log-format.md) and append an entry to `docs/{feature}/{feature}.log.md`. Create the file if it doesn't exist.

Capture: what was built, any deviations from the plan, anything useful for the next developer.

### 6. Handle human checkpoints

If a slice has `Human checkpoint: yes`:
- Set status to `needs-review`
- Summarise the key decisions made in this slice
- Pause and wait for the user's feedback before continuing

### 7. Repeat

Return to step 3. Continue until all slices are `done`, `blocked`, or `needs-review`.

### 8. Generate the QA plan

When no more unblocked slices remain, load [qa-template.md](resources/qa-template.md).

Read `{feature}.tasks.md` and `{feature}.log.md`, then write `docs/{feature}/{feature}.qa.md`. Weight the checklist toward:
- Slices with `Human checkpoint: yes`
- Log entries with deviations or unusual decisions

Tell the user the QA plan is ready and where to find it.
