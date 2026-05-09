---
name: dispatch
description: Orchestrate a feature's task slice DAG by always delegating slice work to fresh sub-agents and parsing structured `<status>` replies, keeping the orchestrator's context lightweight. Reads docs/{feature}/{feature}.tasks.md. Use when user says "/dispatch", "dispatch this", or "dispatch {feature}". Pass the feature name as an argument, e.g. /dispatch checkout-flow.
---

# Dispatch

Execute a feature's slice DAG from `docs/{feature}/{feature}.tasks.md` by dispatching every slice to a fresh sub-agent. The orchestrator stays structurally lightweight: it never executes slice work, never reads slice code, only dispatches sub-agents, parses their `<status>` replies, and updates bookkeeping files.

## Roles

**Orchestrator** (this agent, runs on Opus): reads the DAG, dispatches slices, regex-parses each agent's `<status>` tag, updates the tasks file, and re-evaluates. It never writes implementation code, never reads slice code. The only files it opens itself are the tasks file, the log file (when composing the QA plan), and `git diff --name-only` output (when surfacing checkpoints).

**Slice agents** (sub-agents, default model `sonnet`): each runs in a fresh context window. They read the tasks file (locating their slice by slug), read the log file, implement the slice with TDD, write a log entry, update only their own row's status, and emit exactly one `<status>` tag.

**Always delegate.** Even a single unblocked slice goes to a sub-agent. There is no inline-execution branch in this skill.

**Resources (the orchestrator does not load these into its own context — it points sub-agents at them):**
- [slice-prompt.md](resources/slice-prompt.md) — the slice-agent role definition
- [merge-fix-prompt.md](resources/merge-fix-prompt.md) — the merge-fix-agent role definition (used by step 6a)
- [tdd-loop.md](resources/tdd-loop.md) — red/green/refactor loop and test quality rules (referenced by slice-prompt.md)
- [log-format.md](resources/log-format.md) — how to write log entries (referenced by slice-prompt.md)
- [qa-template.md](resources/qa-template.md) — QA plan structure (used at end of run)

## Process

### 1. Identify the feature

**If a feature name was passed as an argument** → look for `docs/{feature}/{feature}.tasks.md`. If not found, tell the user.

**If no argument was given** → scan `docs/` for directories containing a `{name}.tasks.md` file and present the options:

```
Available features:
  1. checkout-flow   (3 of 7 slices done)
  2. dark-mode       (not started)

Which would you like to dispatch?
```

### 2. Read the tasks file

Load `docs/{feature}/{feature}.tasks.md`. Parse the slug, status, and `Depends on:` field of every slice. Do **not** read or memorise the outside-in description, feedback loop, or any code — those are for the slice agent, not you.

### 3. Identify unblocked slices

Collect all slices where **status is `not-started`** and every entry in `Depends on:` has status `done`.

- **None unblocked, all done** → go to step 7 (QA plan).
- **None unblocked, some not-done** → report what's blocking and stop.
- **One or more unblocked** → go to step 4.

### 4. Dispatch a slice to a sub-agent

For each unblocked slice you intend to run now (single slice in this section; parallel handling is in step 4a):

1. Resolve absolute paths:
   - `TASKS_PATH` = absolute path to `docs/{feature}/{feature}.tasks.md`
   - `LOG_PATH` = absolute path to `docs/{feature}/{feature}.log.md`
   - `SLICE_PROMPT_PATH` = absolute path to this skill's `resources/slice-prompt.md`
2. Spawn a sub-agent (default `model: "sonnet"`) with a **minimal handoff** brief. The brief contains only the slice slug, the three paths, and a directive to read `slice-prompt.md` first. The brief MUST NOT include the slice's outside-in text, feedback loop, code snippets, or anything else from the tasks file — the sub-agent reads the tasks file itself and locates its slice by slug.

Use this exact spawn-message template (substitute the four variables):

```
You are a slice agent for the `{slug}` slice of the `{feature}` feature.

First, read `{SLICE_PROMPT_PATH}` — it defines your role, required reads, and output contract.

Then locate your slice (by slug `{slug}`) in the tasks file at `{TASKS_PATH}` and proceed per the role definition. Append your log entry to `{LOG_PATH}`.

End your reply with exactly one `<status>` tag.
```

That is the entire brief. Do not add slice content. Do not add code. Do not paraphrase the spec.

### 4a. Parallel execution (multiple unblocked slices)

When step 3 surfaces **more than one** unblocked slice, dispatch them in parallel — but apply the gates below first.

**Gates (apply before spawning):**

1. **Human-checkpoint slices run alone.** If any unblocked slice has `Human checkpoint: yes`, do **not** parallelize it with siblings. Run it on its own via step 4 (single Agent spawn, no worktree), let it complete the checkpoint flow, then re-evaluate. Other unblocked siblings wait for the next iteration.
2. **File-collision check.** If two unblocked slices appear (from their outside-in headers / `touches:` notes / file paths called out in the slice spec) to heavily edit the same file, stop and ask the user: "slices `{a}` and `{b}` both touch `{file}` — run sequentially or risk a merge conflict?" Default to sequential on ambiguous answers. (Mirrors the same constraint in `implement`.)

**Spawning in parallel:**

Once the gates pass and you have two-or-more eligible slices, spawn them in **a single message** with **multiple `Agent` tool calls** — one per slice. Each call:

- Uses `model: "sonnet"` (default).
- Uses `isolation: "worktree"` so the sub-agent runs on its own branch in its own worktree directory. The `Agent` tool returns the worktree path and branch name when it completes; capture both per-slice.
- Carries the same minimal handoff brief as step 4 (slug + `TASKS_PATH` + `LOG_PATH` + `SLICE_PROMPT_PATH`, nothing more).

Single-slice runs continue to follow step 4 unchanged — solo execution does not need worktree isolation (per PRD: *"Single spawns may run in-place"*).

**Collecting results and merging:**

Each sub-agent reports back independently with its own `<status>` tag. As each one returns:

1. Parse its `<status>` tag per step 5.
2. If `done` and the spawn used `isolation: "worktree"`, run `git merge --no-ff <branch>` from the main working tree, where `<branch>` is the branch name returned by the `Agent` call for that slice.
3. Clean merges proceed silently — no further action, just continue collecting other sibling results.
4. If `git merge --no-ff` returns non-zero (conflict), see step 6a (Merge handling).
5. If the agent reported `needs-review` or `blocked`, route it through step 6 / step 5 as usual; do **not** merge a non-`done` branch.

Once all parallel siblings are resolved, re-read the tasks file and return to step 3.

**Constraints recap:**

- Spawn all parallel agents in a single message — do not serialize them with intermediate text.
- Never read the contents of a worktree's branch yourself. The orchestrator's only branch-level operation is `git merge --no-ff` and (if needed) `git diff --name-only` for human-checkpoint surfacing.
- Branch names are determined by the `Agent` tool's worktree result — do not invent them.

### 5. Parse the sub-agent's `<status>` tag

Regex-match the **last** `<status ...>...</status>` tag in the sub-agent's reply. Three valid forms:

- `<status>done</status>` → slice complete. Re-read the tasks file (do **not** trust your in-memory copy — the agent updated its row) and return to step 3.
- `<status reason="...">needs-review</status>` → human checkpoint flow (step 6).
- `<status reason="...">blocked</status>` → surface the `reason` to the user and stop.

If the reply contains no `<status>` tag, or the tag is malformed, treat it as `blocked` with `reason="agent did not emit a valid status tag"` and surface to the user.

You parse the tag and nothing else from the agent's reply. Do not read code the agent wrote, do not summarise its work — the log entry it left is the canonical record.

### 6. Human checkpoints

When a slice agent emits `<status reason="...">needs-review</status>`, the orchestrator pauses and surfaces a **minimal** message to the user. The orchestrator does **not** read the slice's code, does **not** summarise the agent's work, and does **not** open any file the agent wrote.

This flow applies whenever `needs-review` is emitted, regardless of the slice's `Human checkpoint:` field. A `Human checkpoint: yes` slice is the **expected** path here; `needs-review` on a `Human checkpoint: no` slice means the agent self-flagged uncertainty — surface it the same minimal way and let the user decide.

**Surfacing (on `needs-review`):**

1. **Capture the changed-file list** with shell only:
   - If the slice ran on a worktree branch (from step 4a), run `git diff --name-only <branch>` against the main working tree's HEAD — paths only. Capture as `CHANGED_FILES`.
   - If the slice ran in-place (single-slice path, step 4), run `git diff --name-only HEAD` (or `git status --porcelain` filtered to modified/added paths) — paths only. Capture as `CHANGED_FILES`.
   - Never run `git diff` body. Never `Read` any of the listed files.

2. **Compose the surface message** containing **only** these four things:
   - The slice slug.
   - The `reason` attribute from the `<status>` tag, verbatim.
   - The absolute path to the log file (`LOG_PATH`) so the user can open the entry themselves.
   - The `CHANGED_FILES` list — one path per line, no diff content.

   Example shape:

   ```
   Slice `{slug}` needs review.

   Reason: {reason verbatim}

   Log entry: {LOG_PATH}

   Changed files:
   {one path per line from CHANGED_FILES}
   ```

3. **Stop and wait** for the user's reply. Do not offer suggestions, do not preview the change, do not read any of the listed files to "help" the user. The user opens the log and the files themselves.

**Handling the user's reply:**

Two outcomes — classify by intent:

- **Approval** (e.g. "looks good", "ship it", "approved", "lgtm", "merge it") →
  1. Mark the slice's row in `TASKS_PATH` as `done` (only that row).
  2. If the slice ran on a worktree branch, run `git merge --no-ff <branch>` per the merge-flow rules in step 6a (clean → silent; conflict → spawn merge-fix agent).
  3. Re-read the tasks file and return to step 3.

- **Change request** (any non-approval text — corrections, requests, questions about the change itself) →
  1. Set the slice's row in `TASKS_PATH` back to `in-progress` (only that row).
  2. **Spawn a fresh sub-agent** for the same slug, with the user's feedback inlined **verbatim** in the brief. Do **not** execute the change inline. Do **not** read the slice's code to "understand" the feedback first.
  3. Use this exact spawn-message template (substitute the five variables):

     ```
     You are a slice agent for the `{slug}` slice of the `{feature}` feature. A previous attempt was reviewed by the user and requires changes.

     User feedback (verbatim):
     {user feedback verbatim}

     First, read `{SLICE_PROMPT_PATH}` — it defines your role, required reads, and output contract.

     Then locate your slice (by slug `{slug}`) in the tasks file at `{TASKS_PATH}`, read the prior log entry for this slug in `{LOG_PATH}` to understand what was already attempted, and address the feedback. Append a new log entry to `{LOG_PATH}`.

     End your reply with exactly one `<status>` tag.
     ```

     That is the entire brief. No code, no diff, no slice content beyond the slug pointer.
  4. When the fresh agent reports back, parse its `<status>` per step 5 and loop again — including looping back through this checkpoint flow if it again emits `needs-review`.

**Constraints recap (human-checkpoint):**

- The orchestrator's only inputs to the surface message are: the slug it already knows, the `reason` attribute it parsed, `LOG_PATH` (a path string), and the output of `git diff --name-only` (paths only).
- The orchestrator never `Read`s a changed file, never inspects diff bodies, never paraphrases the agent's work to the user.
- Change requests always go through a fresh sub-agent — there is no inline-fix path.
- Ambiguous replies (neither clearly approval nor clearly a change request) → ask the user a single plain-text clarifying question; do not guess and do not act.

### 6a. Merge handling

Clean merges from step 4a proceed silently (`git merge --no-ff <branch>` exit 0 → done, continue). Single-slice (no-worktree) execution from step 4 does not require merging.

If `git merge --no-ff <branch>` returns **non-zero** (conflict), the conflict has produced markers in one or more files. The orchestrator does **not** read those files. Instead:

1. **Capture the conflict surface** with shell commands only:
   - `CONFLICTED_FILES` ← output of `git diff --name-only --diff-filter=U`
   - Identify the **two slices whose work conflicts**: the slice on the branch you just attempted to merge (`{slug-incoming}`) and the slice whose already-merged work the conflict is against (`{slug-base}` — the most-recently-merged sibling from the same parallel batch). You know both slugs from your own bookkeeping; you do not need to read the files.

2. **Spawn a merge-fix sub-agent** in a single `Agent` tool call (default `model: "sonnet"`, no worktree — the conflict lives in the main working tree where the failed merge currently sits). The brief contains, and only contains:
   - The two slugs (`{slug-incoming}`, `{slug-base}`).
   - The list of conflicted file paths (`CONFLICTED_FILES`) — paths only, no contents.
   - The absolute path to the tasks file (`TASKS_PATH`) and the two slice slugs so the agent can locate both slice specs itself.
   - The absolute path to the log file (`LOG_PATH`) and the two slugs so the agent can locate both log entries itself.
   - The absolute path to `resources/merge-fix-prompt.md` (`MERGE_FIX_PROMPT_PATH`) with a directive to read it first.

   Use this exact spawn-message template:

   ```
   You are a merge-fix agent for a conflict between slices `{slug-incoming}` and `{slug-base}` of the `{feature}` feature.

   First, read `{MERGE_FIX_PROMPT_PATH}` — it defines your role, process, and output contract.

   Conflicted files:
   {one path per line from CONFLICTED_FILES}

   Locate both slice specs (by slug) in the tasks file at `{TASKS_PATH}` and both log entries (by slug) in the log file at `{LOG_PATH}` to understand intent. Resolve the conflicts in the listed files, `git add` each resolved file, and end your reply with exactly one `<status>` tag.
   ```

   That is the entire brief. Do **not** paste conflict markers, file contents, or slice bodies into it.

3. **Parse the merge-fix agent's `<status>` tag** per step 5 (same contract — `done`, `needs-review` with `reason`, or `blocked` with `reason`).

4. **On `<status>done</status>`**: the agent has staged the resolved files. Finalise the merge with `git commit --no-edit` (the in-progress merge already has a prepared commit message from `git merge --no-ff`). Then continue collecting other parallel siblings' results and return to step 3 once they are all resolved.

5. **On `<status reason="...">needs-review</status>`** or `blocked`: surface to the user **only**:
   - The reason attribute (verbatim).
   - The two slugs and the path to the log file (so the user can read both log entries themselves).
   - The conflicted-file list (paths only).
   The orchestrator does not read the conflicted files, does not summarise the agent's work, does not attempt its own resolution. Stop and wait for the user.

**Constraints recap (merge-flow):**

- The orchestrator's only view into the conflict is `git status --porcelain` and `git diff --name-only --diff-filter=U` — never `git diff` body, never `Read` on a conflicted file.
- Branch and commit operations the orchestrator may run: `git merge --no-ff <branch>`, `git diff --name-only --diff-filter=U`, `git status --porcelain`, `git commit --no-edit` (only after the merge-fix agent reports `done`).
- The merge-fix agent runs in the main working tree (no `isolation: "worktree"`) so its `git add` lands on the in-progress merge state.

### 7. QA plan generation

**Trigger:** step 3 found **no unblocked slices** and **every** slice in the tasks file is `done` — none are `not-started`, `in-progress`, `blocked`, or `needs-review`.

If any slice is `blocked` or `needs-review`, do **not** generate QA. Surface the current state (which slugs are in which non-`done` status, with the `reason` you've already captured for `blocked`/`needs-review`) and stop. The user resolves those before QA can run.

When the trigger condition holds:

1. **Read the inputs the orchestrator is now allowed to open for QA composition only:**
   - `TASKS_PATH` = `docs/{feature}/{feature}.tasks.md` (already in your context — re-read once for freshness).
   - `LOG_PATH` = `docs/{feature}/{feature}.log.md` — read in full.
   - `QA_TEMPLATE_PATH` = absolute path to this skill's `resources/qa-template.md` — read for structure.

   This is the **only** point in the run where the orchestrator opens the log file or the QA template. The constraint against reading slice **code** still holds — you read the tasks file (slice metadata) and the log file (agent-authored summaries), nothing else.

2. **Compose `docs/{feature}/{feature}.qa.md`** following the structure in `qa-template.md`. Weight the content as follows:

   - **Human verification required** — one item per slice with `Human checkpoint: yes` in the tasks file, plus any log entry that explicitly flagged something for a human eye.
   - **Watch closely** — one item per log entry whose `Deviations:` field is non-empty, or whose `Notes:` describe an unusual decision, snag, or trade-off. Reference the slug so the reader can find the log entry.
   - **Standard checks** — routine verification items derived from the remaining slices (those with `Human checkpoint: no` and clean log entries). Keep these brief; they are the lowest-risk path.
   - **Open questions** — anything the log left unresolved. Omit the section if there are none.
   - **What was built** — 1–2 sentences synthesised from the slice slugs and log summaries.

   Do **not** invent items that aren't grounded in the tasks file or the log. The QA plan is a faithful read of what happened, not a generic checklist.

3. **Tell the user the path and stop.** Output exactly:

   ```
   QA plan written: {absolute path to docs/{feature}/{feature}.qa.md}
   ```

   Then **stop completely**. Do not offer to walk through the QA plan. Do not offer to run any of the checks. Do not suggest a next feature, a next slice, or any follow-up. Do not ask if the user wants anything else. The user will `/clear` when ready.

## Constraints

- **Never read slice code.** The orchestrator only opens the tasks file, the log file, and `git diff --name-only` output. Never `Read` an implementation file.
- **Never paraphrase the slice into the brief.** The minimal handoff is non-negotiable — the whole point of dispatch is to keep the slice's bytes out of the orchestrator's context.
- **Re-read the tasks file after every sub-agent finishes.** The agent updated its row; your in-memory copy is stale.
- **Default model for sub-agents is `sonnet`.** Override only if the slice spec explicitly calls for a different model.
- **Stop completely when the run is over.** Do not offer next steps, do not suggest features, do not continue. The user will `/clear` when ready.
