# QA Plan Template

Write `docs/{feature}/{feature}.qa.md` after all slices are complete. Read `{feature}.tasks.md` and `{feature}.log.md` before writing.

## Structure

The doc has two halves:

1. **Already done by the agent** (checked off) — anything the agent ran itself: test suites, linters, typecheckers, build commands, CLI smoke checks. These go near the top, pre-checked, so the human can see at a glance what's already been verified.
2. **Still needs a human** (unchecked) — anything that genuinely requires eyes, a browser, a device, or judgement.

Only put an item in the "already done" section if the log shows the agent actually ran it and it passed. If a check was skipped or failed, it belongs in "Watch closely" or "Human verification required" instead.

## Human items must be self-contained runbooks

The human reading this doc does not have the context you have. They don't know how to start the app, which port it serves on, which command runs the worker, or how to reach a given screen. You do — you just built it. So every item in "Human verification required" must be a runbook the human can follow without thinking:

- **Exact commands**, copy-pasteable, with the working directory. Not "run the web app" — `cd apps/web && pnpm dev` (or whatever the repo actually uses).
- **Exact entry point**: the full URL including port (`http://localhost:3000/`), the device, the CLI invocation, the file to open.
- **Concrete steps**: what to click, type, or navigate to.
- **Pass criterion**: what "good" looks like, specifically enough that the human knows whether it passed.

Derive the commands and ports from what you actually ran and from the repo (`package.json` scripts, Makefile, README, compose files) — never invent or guess them. If you couldn't determine the real command, say so explicitly in the item rather than leaving a vague instruction.

Put commands shared by several items once in a **Setup** block at the top of the section, and have items reference it.

## Template

```markdown
# QA Plan: {Feature name}

## What was built

{1–2 sentences summarising what the feature delivers. Written for someone returning to this doc weeks later.}

## Already verified by the agent

These were run during implementation and passed. Listed for confidence, not action.

- [x] {command or check} — {one-line result, e.g. "all 47 tests pass"}
- [x] {command or check} — {result}

## Human verification required

Items from slices with `Human checkpoint: yes`, plus anything from the log that needs a human eye, browser, device, or judgement call. Each item is a runbook — exact commands, exact entry point, steps, and pass criterion. Never make the human figure out how to run the thing.

### Setup

Commands shared by the items below. Run once. Derive these from the repo — do not guess.

```bash
{e.g.}
cd apps/web
pnpm install        # if dependencies aren't installed
pnpm dev            # serves on http://localhost:3000
```

If an item needs a different environment (a device, a separate worker, a real external session), give that item its own setup inline instead of here.

- [ ] **{What to verify}**
  - Run: `{exact command, or "use the server from Setup"}`
  - Open: `{exact URL incl. port / route / screen / file}`
  - Do: {what to click, type, or navigate to}
  - Expect: {what "good" looks like — specific enough to judge pass/fail}
- [ ] **{What to verify}**
  - ...

## Watch closely

Items where the log recorded deviations, snags, or unusual decisions. These are the most likely sources of subtle bugs — worth extra scrutiny during human verification.

- [ ] {item — reference the log entry if useful}

## Open questions

Anything unresolved at the end of implementation. If none, omit this section.
```
