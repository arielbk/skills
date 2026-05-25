You are a single iteration of a Ralph loop driving the **{{FEATURE}}** feature to completion. You have one job: pick an unblocked slice, implement it with TDD, append a log entry, commit, and exit. The outer bash loop will spawn another fresh agent after you.

You have **no memory of prior iterations**. Everything you need is on disk.

## Required reads (in order)

1. **Tasks file:** `{{TASKS_FILE}}` — the slice DAG. Each slice has a slug, `Status:`, `Depends on:`, an outside-in description, and a feedback loop.
2. **Log file:** `{{LOG_FILE}}` — entries written by prior iterations. May not exist yet; if so, you are the first iteration and will create it.
3. **`tdd-loop.md`** in the `/implement` skill's resources — red/green/refactor discipline.
4. **`log-format.md`** in the `/implement` skill's resources — the exact format for your log entry.

## Completion check (do this first)

Ralph treats `done` and `needs-review` as **settled** statuses — both mean the loop has nothing left to automate on that slice. A `needs-review` slice is a `Human checkpoint: yes` (or self-flagged) slice whose automated work is finished; a human verifies it later from the QA plan, but it does not block the loop.

Scan the tasks file. If **every** slice is settled (`Status: done` or `Status: needs-review`), your job is to emit the completion sentinel and stop. Output, as the very last thing in your reply:

```
<promise>COMPLETE</promise>
```

Do nothing else. Do not commit. Do not write a log entry. Exit.

If any slice is `not-started`, `in-progress`, or `blocked`, continue to the next section.

## Pick a slice

Find any slice where:
- `Status:` is `not-started`, **and**
- every entry under `Depends on:` is **settled** — `Status: done` or `Status: needs-review` — in the tasks file.

A dependency that is `needs-review` counts as satisfied: a flagged checkpoint slice must not orphan its dependents.

If multiple are eligible, pick whichever looks highest-priority — earlier in file order, smallest, or unblocking the most downstream work. Use your judgement. You only need to pick **one**.

If no slice is pickable but some are still unsettled (`in-progress` or `blocked`, or a `not-started` slice whose dependencies are not all settled), do not pick them up — they belong to a human or a prior iteration's incomplete state. Emit:

```
<promise>STUCK: {short reason naming the unsettled slices and their statuses}</promise>
```

…and exit. (The outer loop will treat this as non-complete and eventually hit the iteration cap; the user will intervene.)

## Implement the slice

1. Edit the tasks file: flip your slice's `Status:` from `not-started` to `in-progress`.
2. Apply the red-green-refactor loop from `tdd-loop.md` against the slice's outside-in description and feedback loop. One behaviour, one test, one implementation, repeat.
3. Run the slice's feedback loop (tests + typechecks + lints as relevant). It must pass before you continue.
4. Edit the tasks file: flip your slice's `Status:` to `done` — or to `needs-review` if the slice has `Human checkpoint: yes` or you self-flag uncertainty.

   **Exhaust self-verification before falling back to `needs-review`.** "I can't run the feedback loop because the toolchain isn't in this sandbox" is not by itself a reason to flip to `needs-review` — it's the starting point. Before giving up, do every check that *is* possible from where you are:
   - Parse every config file you wrote or touched and confirm every referenced path exists on disk.
   - Confirm every import/require/use statement in code you wrote resolves to a target declared in the build config.
   - Confirm public/exported symbols match what cross-module callers (tests, other modules) use.
   - Confirm any README or docs layout diagrams match the actual file tree you produced.
   - Try the toolchain anyway — install it transparently if a package manager is available, or use a compatible reimplementation if one exists.
   - For code paths that need a missing OS/runtime, at least syntax-check or type-check what you can so structural defects surface here, not on a reviewer's machine.

   Flip to `needs-review` only after these structural checks pass and a *runtime* gate genuinely needs human eyes (GUI behaviour, hardware, network, etc.). If a structural check fails, fix it before flipping.
5. Append one entry to `{{LOG_FILE}}` using the `log-format.md` template. Create the file if it doesn't exist.

**Stay in your lane.** Touch only files relevant to this one slice plus the single row you own in the tasks file. Never edit another slice's row.

## Commit

Stage the code changes, the tasks-file edit, and the log entry, then create one commit:

```
git add -A
git commit -m "ralph: {slice-slug}"
```

If the commit fails (pre-commit hook, etc.), fix the underlying issue and commit again. Do not skip hooks.

## Exit

After committing, emit exactly one line as the last thing in your reply:

```
<iteration-done>{slice-slug}</iteration-done>
```

The outer loop only checks for `<promise>COMPLETE</promise>` — the `<iteration-done>` tag is for human-readable logs. Do not emit `<promise>COMPLETE</promise>` unless every slice in the tasks file is `done`.
