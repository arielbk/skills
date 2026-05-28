---
name: ralph
description: Ralph Wiggum loop variant of /implement — drives a feature's task DAG to completion by spawning a fresh sandboxed `claude -p` (or `codex exec`) per iteration, each picking any unblocked slice, TDD-ing it, appending to the implement log, committing, and exiting. Loop terminates on `<promise>COMPLETE</promise>` sentinel, then spawns one final agent to write the QA plan. Use when user says "/ralph", "ralph this", "/ralph codex ...", or "ralph {feature}". Pass the feature name as an argument; pass `codex` (positional) or mention Codex to route to the Codex runtime.
---

# Ralph

`/ralph` is an alternate execution mode for `/implement`. Same inputs (`docs/{feature}/{feature}.tasks.md`), same artefacts (`{feature}.log.md`, `{feature}.qa.md`), different runtime: instead of one orchestrator session that does or delegates every slice, a bash loop spawns a fresh sandboxed agent per iteration. Each iteration has its own context, its own quota, and exits after one slice. This trades coherent in-session narration for unbounded total context budget.

Ralph has two runtimes, both host-native (no Docker, no per-project VM):
- **Claude (default)** — `ralph.sh`, runs `claude -p` wrapped in [Anthropic's sandbox runtime](https://github.com/anthropic-experimental/sandbox-runtime) (`@anthropic-ai/sandbox-runtime`), which confines the whole process with macOS Seatbelt / Linux bubblewrap. Auth comes from the host's existing Claude login — no in-sandbox `/login`.
- **Codex** — `ralph-codex.sh`, runs `codex exec --json -s workspace-write` directly on the host (Codex sandboxes itself).

This skill's job is small: pick the runtime, validate inputs, invoke the bundled script, and report the outcome. The real work happens in the subprocesses.

**Resources:**
- [ralph.sh](ralph.sh) — the Claude loop. Invoked by this skill, not by the user directly.
- [ralph-codex.sh](ralph-codex.sh) — the Codex loop. Same role, different runtime.
- [resources/iteration-prompt.md](resources/iteration-prompt.md) — the prompt template each iteration receives. Shared by both runtimes.
- [resources/qa-prompt.md](resources/qa-prompt.md) — the prompt for the final QA-plan agent. Shared by both runtimes.

## Process

### 1. Pick the runtime

Default to **Claude**. Route to **Codex** if either is true:
- The args contain `codex` as a positional token (e.g. `/ralph codex my-feature`, `/ralph my-feature codex`).
- The user's natural-language ask mentions Codex (e.g. "ralph this with codex", "run codex ralph on X").

Strip `codex` from the args before extracting the feature name. The remaining positional is the feature.

### 2. Identify the feature

**Argument passed** → look for `docs/{feature}/{feature}.tasks.md`. If missing, tell the user and stop.

**No argument** → scan `docs/` for directories containing `{name}.tasks.md` and ask the user which one.

### 3. Preflight

Always check:
- `docs/{feature}/{feature}.tasks.md` exists.
- `jq` is on PATH. Both scripts pipe each iteration's JSON stream through `jq` to extract a structured per-iteration result; without it the loop aborts immediately.
- The repo is a git repo with a clean-ish tree (uncommitted changes are fine, but warn the user — each iteration commits).

Claude runtime only:
- The sandbox runtime is reachable: either `srt` is on PATH or `npx` is (the script falls back to `npx -y @anthropic-ai/sandbox-runtime`, which fetches+caches the package on first use). If neither is present, tell the user to `npm i -g @anthropic-ai/sandbox-runtime` and stop.
- `claude` is on PATH and the **host** is already logged in (`claude -p 'say hi'` works). The sandbox runs on the host and reuses host credentials — there is no separate sandbox login. ralph.sh runs a one-shot `READY` probe through the sandbox before iterating, so a logged-out host or a broken sandbox launch fails during preflight, not on iteration 1.
- Sandbox policy is generated per-run and scoped to this repo (repo dir + `~/.claude` writable, `*.anthropic.com` network). If a slice's feedback loop needs more (e.g. a package registry to install deps), point `RALPH_SRT_SETTINGS` at your own settings file — see the sandbox-runtime README for the schema.

Codex runtime only:
- `codex` is on PATH. Auth is not pre-checked — `codex exec` fails loudly on iteration 1 if the user is not logged in (`codex login`).

### 4. Run the loop

Invoke the runtime's bundled script via Bash:

```
# Claude (default)
bash {skill-dir}/ralph.sh {feature} {max-iterations}

# Codex
bash {skill-dir}/ralph-codex.sh {feature} {max-iterations}
```

Default `max-iterations` to `30` unless the user passed an explicit cap. Stream the output. Both scripts:
- Loop up to `max-iterations` times, each iteration spawning a fresh agent (`claude -p` under the sandbox runtime for `ralph.sh`; `codex exec --json -s workspace-write` on the host for `ralph-codex.sh`).
- Pipe the iteration's JSON stream through `jq`:
  - Live agent text is tee'd to the orchestrator's terminal as it arrives.
  - A per-iteration result payload is captured and printed inside an `─── iteration N summary ───` block.
- Sentinel-check the captured result payload (not the full raw transcript) and break early when one fires:
  - `<promise>COMPLETE</promise>` → exit `0` (all slices done).
  - `<promise>STUCK` (substring match — reason text varies) → exit `76` (no pickable slice; human intervention needed).
- Iteration-cap → exit `75`.
- Fall back to the tail of the raw stream for diagnostics if no result is captured (crash, auth dropout, etc.).

Do not babysit individual iterations. Just let the script run and capture its exit code.

### 5. Generate the QA plan (only on clean completion)

**Only** if the loop exited `0` with `COMPLETE` in output: spawn one final agent (same runtime that ran the loop — `claude -p` for the Claude path, `codex exec` for the Codex path) using the prompt template in [resources/qa-prompt.md](resources/qa-prompt.md). This agent reads `{feature}.tasks.md` + `{feature}.log.md` and writes `docs/{feature}/{feature}.qa.md` in the same shape `/implement` produces.

For any other exit (STUCK at exit `76`, iteration cap at exit `75`, or anything else), do **not** generate QA. Instead, surface the current state of `{feature}.tasks.md` (slug + `Status:` for each slice) so the user can intervene. If the exit was STUCK, also surface the STUCK reason from the final iteration's stdout verbatim.

### 6. Report and stop

Tell the user:
- The outcome — one of: completed cleanly, halted on STUCK, or hit the iteration cap.
- For STUCK or cap exits: the slug + status table from step 4, plus the STUCK reason if applicable.
- The path to `{feature}.log.md` and (if generated) `{feature}.qa.md`.

Then **stop completely**. No next-step offers. The user will `/clear` when ready.

## Constraints

- **One slice per iteration.** Each agent invocation implements exactly one unblocked slice and exits. The sandbox enforces isolation; the prompt enforces single-slice scope.
- **Sandboxed only.** Never call `claude -p --dangerously-skip-permissions` without wrapping it in the sandbox runtime (`srt`/`npx @anthropic-ai/sandbox-runtime`). Never call `codex exec` without `-s workspace-write` (or stronger user-approved restriction). The loop is fire-and-forget; safety comes from the sandbox.
- **Never halt for a human.** Ralph is AFK. `needs-review` is a *settled* status the loop steps past, not a stop — all human-review items are collected into the QA plan at the end. Human checkpoints are `/implement`'s concern. The only non-completion halt is STUCK (a genuine dead-end), and an orphaned `in-progress` slice from a crashed iteration is reclaimed, never treated as STUCK.
- **Sentinels are canonical.** Loop exits on either terminal sentinel in the iteration's `result` payload — `<promise>COMPLETE</promise>` (every slice settled: `done` or `needs-review`) or `<promise>STUCK: ...</promise>` (a genuine dead-end: a `blocked` slice, or a `not-started` slice gated behind one). An orphaned `in-progress` slice is reclaimed by the next iteration, not a STUCK trigger. The iteration prompt requires the sentinel be the last line of the reply, which puts it in the `result` event. No file-state parsing in bash.
- **QA only on clean completion.** Iteration-cap and STUCK exits do not produce a QA plan; they surface current slice statuses for human intervention.
- **No replacement for `/implement`.** `/ralph` coexists with `/implement` — they read the same tasks file and write the same log/QA artefacts.
