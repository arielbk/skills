---
name: implement
description: Execute a feature's task slices end-to-end using TDD, writing a log as it goes and generating a QA plan at the end. Reads docs/{feature}/{feature}.tasks.md. Use when user says "/implement", "implement this", or "start building". Pass the feature name as an argument, e.g. /implement checkout-flow.
---

# Implement

Execute a feature's slice DAG from `docs/{feature}/{feature}.tasks.md`. Work through each unblocked slice using TDD, keep a running log, and generate a QA plan when done.

## Roles

**Orchestrator** (this agent): reads the DAG, dispatches slices, waits for completion, re-evaluates. Stays lightweight — it does not hold implementation details in context.

**Slice agents**: each runs in a fresh context window. They read the log to understand what prior slices did, implement their slice with TDD, write their own log entry, and update their slice status. They report back only `done` or `needs-review` — the orchestrator needs nothing else.

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

### 3. Identify unblocked slices

Collect all slices where **status is `not-started`** and all `Depends on:` slices have status `done`.

- **None unblocked** → report what's blocking and stop.
- **One unblocked** → execute it directly (step 4).
- **Multiple unblocked** → spawn one sub-agent per slice and run them in parallel (step 4a), then return here when all complete.

### 4. Execute a slice with TDD

Load [tdd-loop.md](resources/tdd-loop.md) before starting.

1. Set **Status** to `in-progress` in the tasks file.
2. Explore the relevant code if needed.
3. Work through behaviors using the red→green loop — one test, one implementation, repeat.
4. Never reference the PRD, tasks file, or any planning document in code comments.
5. When all behaviors pass and code is clean, set **Status** to `done` (or `needs-review` if `Human checkpoint: yes`).
6. Write a log entry (see step 5).

### 4a. Parallel execution (multiple unblocked slices)

Spawn one sub-agent per unblocked slice. Each agent is self-contained — it does not share context with the orchestrator or sibling agents. Brief each agent with:
- The slice slug and its full spec from the tasks file
- Paths to the tasks file and log file
- The contents of [tdd-loop.md](resources/tdd-loop.md) and [log-format.md](resources/log-format.md)
- Instruction to read the current log before starting — prior slice agents will have written entries that may be relevant (shared types, APIs, conventions established)

Each agent works independently and reports back only its final status (`done` or `needs-review`). The orchestrator re-reads the tasks file when all are done and returns to step 3.

**Constraints:**
- Each agent updates only its own slice's status — no other rows.
- If any slice has `Human checkpoint: yes`, do not parallelize it with others — run it alone so the user can review before work continues.
- If two unblocked slices touch the same file heavily, flag this to the user and ask whether to run sequentially instead.

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

Tell the user the QA plan is at `docs/{feature}/{feature}.qa.md`. Then stop completely — do not offer to fix failing tests, suggest a next feature, or continue in any direction. The user will `/clear` and continue when they're ready.
