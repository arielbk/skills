# QA Plan Template

Write `docs/{feature}/{feature}.qa.md` after all slices are complete. Read `{feature}.tasks.md` and `{feature}.log.md` before writing.

## Structure

The doc has two halves:

1. **Already done by the agent** (checked off) — anything the agent ran itself: test suites, linters, typecheckers, build commands, CLI smoke checks. These go near the top, pre-checked, so the human can see at a glance what's already been verified.
2. **Still needs a human** (unchecked) — anything that genuinely requires eyes, a browser, a device, or judgement.

Only put an item in the "already done" section if the log shows the agent actually ran it and it passed. If a check was skipped or failed, it belongs in "Watch closely" or "Human verification required" instead.

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

Items from slices with `Human checkpoint: yes`, plus anything from the log that needs a human eye, browser, device, or judgement call.

- [ ] {item — be specific about what to look at and what "good" looks like}
- [ ] {item}

## Watch closely

Items where the log recorded deviations, snags, or unusual decisions. These are the most likely sources of subtle bugs — worth extra scrutiny during human verification.

- [ ] {item — reference the log entry if useful}

## Open questions

Anything unresolved at the end of implementation. If none, omit this section.
```
