# Delegation Handoff

Load this file when you (the orchestrator) are about to delegate a slice to a sub-agent. It tells you when delegation is the right call and how to compose the spawn message.

## When to delegate

**Inline is the default.** You do slice work yourself. Delegate only when one of these signals applies:

- **Context is heavy.** You've completed several slices, you've read a lot of code, and your context is getting crowded. Delegating the next slice keeps the orchestrator lean for the rest of the run.
- **Cold-area slice.** This slice touches code you haven't loaded yet. If the slice is self-contained (its work doesn't need to be referenced by later slices in *your* context), delegating means you never pay the load cost — the sub-agent reads it, works on it, and the only artifact you keep is the log entry.

If neither signal applies, run the slice inline.

Do not delegate just because the slice "feels big" or "feels risky." Inline gives you full context for review and follow-up; delegation is for token economy, not for offloading hard problems.

## Pick the agent type

- **`slice-agent` custom agent available** → spawn `subagent_type: slice-agent`. Its role, required reads, output contract, and model are baked into its system prompt — the brief carries only paths.
- **Not available** → spawn a generic sub-agent (`model: "sonnet"`, no worktree) pointed at `resources/slice-prompt.md`, the same role definition in file form.

## Spawn message

Resolve these absolute paths first:

- `TASKS_PATH` = `docs/{feature}/{feature}.tasks.md`
- `LOG_PATH` = `docs/{feature}/{feature}.log.md`
- `TDD_LOOP_PATH` = absolute path to this skill's `resources/tdd-loop.md`
- `LOG_FORMAT_PATH` = absolute path to this skill's `resources/log-format.md`
- `SLICE_PROMPT_PATH` = absolute path to this skill's `resources/slice-prompt.md` (fallback path only)
- `{slug}` = the slice's slug from the tasks file

### slice-agent brief

```
You are working the `{slug}` slice of the `{feature}` feature.

Tasks file: {TASKS_PATH}
Log file: {LOG_PATH}
TDD loop resource: {TDD_LOOP_PATH}
Log format resource: {LOG_FORMAT_PATH}
```

### Generic-agent brief (fallback)

```
You are a slice agent for the `{slug}` slice of the `{feature}` feature.

First, read `{SLICE_PROMPT_PATH}` — it defines your role, required reads, and output contract.

Then locate your slice (by slug `{slug}`) in the tasks file at `{TASKS_PATH}` and proceed per the role definition. Append your log entry to `{LOG_PATH}`.

End your reply with exactly one `<status>` tag.
```

Either way, that is the entire brief. **Do not** paste the slice's outside-in text, feedback loop, code snippets, or any other tasks-file content — the whole point of the minimal handoff is to keep the slice's bytes out of your context. The sub-agent reads the tasks file itself and locates its slice by slug.

## Change-request re-spawn

If a previously-delegated slice came back `needs-review`, the user reviewed it, and the user asked for changes — spawn a **fresh** sub-agent (same agent-type selection as above) with the user's feedback inlined verbatim. Append this to the brief:

```
A previous attempt was reviewed by the user and requires changes.

User feedback (verbatim):
{user feedback verbatim}

Read the prior log entry for this slug in the log file to understand what was already attempted, then address the feedback. Append a new log entry.
```

Never inline-fix work that was originally delegated — you don't have the slice's context, and reading the slice's code now would defeat the original delegation.
