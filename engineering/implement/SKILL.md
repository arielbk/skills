---
name: implement
description: Execute a feature's task slices end-to-end using TDD, writing a log as it goes and generating a QA plan at the end. Reads docs/{feature}/{feature}.tasks.md. Use when user says "/implement", "implement this", or "start building". Pass the feature name as an argument, e.g. /implement checkout-flow.
---

# Implement

Execute a feature's slice DAG from `docs/{feature}/{feature}.tasks.md` **sequentially** in one orchestrator session. Run each unblocked slice one at a time, keep a running log, and generate a QA plan when done. The orchestrator does slice work inline by default and may delegate individual slices to fresh sub-agents when that's cheaper for context.

## Roles

**Orchestrator** (this agent): reads the DAG, picks the next unblocked slice, decides inline vs delegate, runs or delegates it, handles the result, re-evaluates. Stays light on context.

**Slice agents** (only when delegating): each runs in a fresh context window. They read the tasks file, the log, and `slice-prompt.md`, implement their slice with TDD, write a log entry, update only their own row, and emit exactly one `<status>` tag.

**Resources (load when needed):**
- [tdd-loop.md](resources/tdd-loop.md) — red/green/refactor loop and test quality rules. Load before inline TDD work.
- [log-format.md](resources/log-format.md) — how to write log entries.
- [qa-template.md](resources/qa-template.md) — QA plan structure. Load at end of run.
- [slice-prompt.md](resources/slice-prompt.md) — slice-agent role definition. The orchestrator does not read this — it points sub-agents at it.
- [delegation-handoff.md](resources/delegation-handoff.md) — when to delegate and the spawn-message template. Load only when delegating.

## Process

### 1. Identify the feature

**If a feature name was passed as an argument** → look for `docs/{feature}/{feature}.tasks.md`. If not found, tell the user.

**If no argument was given** → scan `docs/` for directories containing a `{name}.tasks.md` file and present the options:

```
Available features:
  1. checkout-flow   (3 of 7 slices done)
  2. dark-mode       (not started)

Which would you like to implement?
```

### 2. Read the tasks file

Load `docs/{feature}/{feature}.tasks.md`. Parse all slices, their statuses, and their `Depends on:` fields.

### 3. Pick the next unblocked slice

Collect all slices where **status is `not-started`** and every entry in `Depends on:` has status `done`.

- **None unblocked, all `done`** → step 8 (QA gate).
- **None unblocked, some non-done** → surface the non-done state (slug + status + reason for each) and stop.
- **One or more unblocked** → pick **exactly one** — the first unblocked slice in file order — and proceed to step 4. Sequential is enforced here; never run two slices at once.

### 4. Decide: inline or delegate?

Default: **inline**. Delegate only when one of two signals applies:

- Your context is getting heavy from prior slices.
- The slice touches a cold area of the codebase you haven't loaded yet, and the slice is self-contained enough that you won't need that area in your context later.

If you decide to delegate, load [delegation-handoff.md](resources/delegation-handoff.md) for guidance and the exact spawn message. Otherwise go to step 5 inline.

Don't delegate to offload hard problems. Inline keeps the orchestrator close to the work; delegation is for token economy.

### 5. Execute the slice

#### Inline path

1. Load [tdd-loop.md](resources/tdd-loop.md) if you haven't this run.
2. Set the slice's `Status:` to `in-progress` in the tasks file.
3. Explore the relevant code if needed.
4. Work the red→green→refactor loop — one behaviour, one test, one implementation, repeat.
5. Never reference the PRD, tasks file, or any planning document in code comments.
6. When the feedback loop passes and code is clean, set `Status:` to `done` (or `needs-review` if `Human checkpoint: yes` or you self-flag uncertainty).
7. Append a log entry per [log-format.md](resources/log-format.md) to `docs/{feature}/{feature}.log.md` (create the file if it doesn't exist).

If the slice is `needs-review`, go to step 6. Otherwise return to step 3.

#### Delegate path

Spawn a single sub-agent using the brief in [delegation-handoff.md](resources/delegation-handoff.md). Wait for it to return, then:

1. **Re-read the tasks file.** The sub-agent updated its row; your in-memory copy is stale.
2. **Parse the last `<status>` tag** in the sub-agent's reply. Three valid forms:
   - `<status>done</status>` → slice complete. Return to step 3.
   - `<status reason="...">needs-review</status>` → step 6 (delegated branch).
   - `<status reason="...">blocked</status>` → surface the `reason` to the user and stop.
   - No `<status>` tag, or malformed → treat as `blocked` with `reason="agent did not emit a valid status tag"`, surface, stop.

You parse the tag and nothing else from the agent's reply. Do not read code the agent wrote to "verify" or "summarise" its work — the log entry is the canonical record.

### 6. Human checkpoints

When a slice's status becomes `needs-review` (whether `Human checkpoint: yes` or self-flagged), surface to the user and pause.

**Surface fidelity is asymmetric** — match what you actually know:

#### Inline branch (you did the work)

Give a real summary. Cover: what was built, key decisions or trade-offs you made, files touched, anything you'd want a reviewer to focus on. Then ask for review.

#### Delegated branch (a sub-agent did the work)

Surface **strictly**. The orchestrator's only inputs are the slug, the `reason` attribute, the log path, and the changed-file list.

1. Run `git diff --name-only HEAD` (paths only). Capture as `CHANGED_FILES`. Never run `git diff` body. Never `Read` any of the changed files.
2. Compose the surface message containing only:
   - The slice slug.
   - The `reason` attribute from the `<status>` tag, verbatim.
   - The absolute path to the log file (`LOG_PATH`).
   - The `CHANGED_FILES` list, one path per line.
3. Stop and wait for the user. Do not preview the change, do not paraphrase the agent's work.

#### Handling the user's reply (both branches)

- **Approval** ("looks good", "ship it", "lgtm", etc.) → mark the slice's row as `done`, return to step 3.
- **Change request** (any non-approval text) → set the slice's row back to `in-progress`, then:
  - **If originally inline** → address the feedback inline. Continue the TDD loop, write a new log entry, return to step 6 when done.
  - **If originally delegated** → spawn a fresh sub-agent with feedback verbatim, per the change-request brief in [delegation-handoff.md](resources/delegation-handoff.md). Never inline-fix previously-delegated work.
- **Ambiguous reply** → ask one plain-text clarifying question. Do not guess.

### 7. Repeat

Return to step 3. Continue until all slices are `done`, `blocked`, or `needs-review`.

### 8. QA gate and plan

**Strict gate.** Generate the QA plan **only when every slice is `done`**.

If any slice is `blocked`, `needs-review`, or `in-progress`, do **not** generate QA. Surface the non-done state (slug + status + reason for each) and stop. The user resolves those before QA can run.

When the gate passes:

1. Re-read the tasks file once for freshness.
2. Read the log file in full (`docs/{feature}/{feature}.log.md`).
3. Load [qa-template.md](resources/qa-template.md).
4. Compose `docs/{feature}/{feature}.qa.md` per the template. Split items into two halves:
   - **Already verified by the agent** (checked, near the top) — tests, linters, typechecks, builds, CLI smoke checks the agent actually ran during implementation. Pull these from the log. Each gets a `- [x]` with a one-line result.
   - **Human verification required** (unchecked) — slices with `Human checkpoint: yes`, plus anything needing a browser, device, or human judgement. Write each as a self-contained runbook: exact command + working dir, exact entry point (URL incl. port, screen, CLI invocation), concrete steps, and pass criterion. The human lacks your context — never leave them to figure out how to start the app or which port it's on. Pull the real run command and port from `package.json` scripts, Makefile, README, or compose files (read them now if you didn't during the run); never invent them.
   - **Watch closely** — log entries with non-empty `Deviations:` or unusual `Notes:`.
   Do not put CLI commands in the unchecked sections if the agent already ran them — that erodes trust in the checklist. (Setup/run commands the human must execute to reach a manual check are the exception — those belong in the runbook.)
5. Tell the user the path:

   ```
   QA plan written: {absolute path to docs/{feature}/{feature}.qa.md}
   ```

   Then **stop completely**. Do not offer to walk through the plan, run any checks, suggest a next feature or slice, or ask if the user wants anything else. The user will `/clear` when ready.

## Constraints

- **Sequential only.** Never spawn parallel sub-agents. Pick one slice, run it, repeat.
- **Inline is the default.** Delegate only on the two named signals (context-weight, cold-area). Don't delegate to offload hard problems.
- **Minimal handoff when delegating.** Never paste slice content into the spawn message. The sub-agent reads the tasks file by slug.
- **Re-read the tasks file after every delegated return.** Your in-memory copy is stale — the sub-agent updated its row.
- **Asymmetric human-checkpoint surface.** Rich summary for inline, strict path-list for delegated. Never read a delegated slice's changed files.
- **Change-requests on delegated work re-spawn.** No inline-fix path for previously-delegated slices.
- **Strict QA gate.** No QA plan if any slice is non-`done`.
- **Stop completely when the run is over.** No next-step offers, no follow-ups. The user will `/clear` when ready.
