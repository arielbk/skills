---
name: ralph
description: Ralph Wiggum loop variant of /implement — drives a feature's task DAG to completion by spawning a fresh sandboxed `claude -p` per iteration, each picking any unblocked slice, TDD-ing it, appending to the implement log, committing, and exiting. Loop terminates on `<promise>COMPLETE</promise>` sentinel, then spawns one final agent to write the QA plan. Use when user says "/ralph", "ralph this", or "ralph {feature}". Pass the feature name as an argument.
---

# Ralph

`/ralph` is an alternate execution mode for `/implement`. Same inputs (`docs/{feature}/{feature}.tasks.md`), same artefacts (`{feature}.log.md`, `{feature}.qa.md`), different runtime: instead of one orchestrator session that does or delegates every slice, a bash loop spawns a fresh sandboxed `claude -p` per iteration. Each iteration has its own context, its own quota, and exits after one slice. This trades coherent in-session narration for unbounded total context budget.

This skill's job is small: validate inputs, invoke the bundled `ralph.sh`, and report the outcome. The real work happens in the subprocesses.

**Resources:**
- [ralph.sh](ralph.sh) — the loop. Invoked by this skill, not by the user directly.
- [resources/iteration-prompt.md](resources/iteration-prompt.md) — the prompt template each iteration's `claude -p` receives.
- [resources/qa-prompt.md](resources/qa-prompt.md) — the prompt for the final QA-plan agent.

## Process

### 1. Identify the feature

**Argument passed** → look for `docs/{feature}/{feature}.tasks.md`. If missing, tell the user and stop.

**No argument** → scan `docs/` for directories containing `{name}.tasks.md` and ask the user which one.

### 2. Preflight

Check:
- `docs/{feature}/{feature}.tasks.md` exists.
- `docker` is on PATH and `docker sandbox` is configured. If `docker sandbox --help` fails, tell the user to set up the sandbox first and stop.
- `jq` is on PATH. ralph.sh pipes each iteration's `claude -p --output-format stream-json` through `jq` to extract a structured per-iteration result; without it the loop aborts immediately.
- A docker sandbox **already exists for this workspace** and the user has logged into it once (`docker sandbox run claude` → `/login` → complete OAuth → `/quit`). OAuth state lives inside the sandbox VM in plugin v0.12+, not on a host proxy, so a freshly-created sandbox is not logged in. `docker sandbox ls --json` should list a sandbox whose `workspaces` contains the current repo path. ralph.sh looks one up and aborts with instructions if none is found.
- The repo is a git repo with a clean-ish tree (uncommitted changes are fine, but warn the user — each iteration commits).

### 3. Run the loop

Invoke the bundled script via Bash:

```
bash {skill-dir}/ralph.sh {feature} {max-iterations}
```

Default `max-iterations` to `30` unless the user passed an explicit cap. Stream the output. The script:
- Loops up to `max-iterations` times.
- Each iteration calls `docker sandbox run claude --dangerously-skip-permissions --verbose -p --output-format stream-json "{rendered iteration-prompt}"`, then pipes the JSON stream through `jq`:
  - Live `assistant` text chunks are tee'd to the orchestrator's terminal as they arrive.
  - The trailing `result` event is captured and printed inside an `─── iteration N summary ───` block so the orchestrating agent has a clean, structured outcome per iteration.
- Sentinel-checks the captured `result` payload (not the full raw transcript) and breaks early when one fires:
  - `<promise>COMPLETE</promise>` → exit `0` (all slices done).
  - `<promise>STUCK` (substring match — reason text varies) → exit `76` (no pickable slice; human intervention needed).
- If `claude -p` exits without emitting a `result` event (crash, OAuth dropout, etc.), the summary block falls back to the tail of the raw stream for diagnostics.

Do not babysit individual iterations. Just let the script run and capture its exit code.

### 4. Generate the QA plan (only on clean completion)

**Only** if the loop exited `0` with `COMPLETE` in output: spawn one final `claude -p` using the prompt template in [resources/qa-prompt.md](resources/qa-prompt.md). This agent reads `{feature}.tasks.md` + `{feature}.log.md` and writes `docs/{feature}/{feature}.qa.md` in the same shape `/implement` produces.

For any other exit (STUCK at exit `76`, iteration cap at exit `75`, or anything else), do **not** generate QA. Instead, surface the current state of `{feature}.tasks.md` (slug + `Status:` for each slice) so the user can intervene. If the exit was STUCK, also surface the STUCK reason from the final iteration's stdout verbatim.

### 5. Report and stop

Tell the user:
- The outcome — one of: completed cleanly, halted on STUCK, or hit the iteration cap.
- For STUCK or cap exits: the slug + status table from step 4, plus the STUCK reason if applicable.
- The path to `{feature}.log.md` and (if generated) `{feature}.qa.md`.

Then **stop completely**. No next-step offers. The user will `/clear` when ready.

## Constraints

- **One slice per iteration.** Each `claude -p` invocation implements exactly one unblocked slice and exits. The sandbox enforces isolation; the prompt enforces single-slice scope.
- **Sandboxed and bypass-permissions only.** Never call `claude -p` without `docker sandbox run` and `--dangerously-skip-permissions`. The loop is fire-and-forget; safety comes from the sandbox.
- **Sentinels are canonical.** Loop exits on either terminal sentinel in the iteration's `result` payload — `<promise>COMPLETE</promise>` (all slices done) or `<promise>STUCK: ...</promise>` (no pickable slice — emitted when remaining slices are `in-progress`, `needs-review`, or `blocked`). The iteration prompt requires the sentinel be the last line of the reply, which puts it in the `result` event. No file-state parsing in bash.
- **QA only on clean completion.** Iteration-cap and STUCK exits do not produce a QA plan; they surface current slice statuses for human intervention.
- **No replacement for `/implement`.** `/ralph` coexists with `/implement` — they read the same tasks file and write the same log/QA artefacts.
