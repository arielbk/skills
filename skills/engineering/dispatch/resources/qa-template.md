# QA Plan Template

Write `docs/{feature}/{feature}.qa.md` after all slices are complete. Read `{feature}.tasks.md` and `{feature}.log.md` before writing.

```markdown
# QA Plan: {Feature name}

## What was built

{1–2 sentences summarising what the feature delivers.}

## Human verification required

Items from slices with `Human checkpoint: yes`, plus anything from the log that needs a human eye.

- [ ] {item}
- [ ] {item}

## Watch closely

Items where the log recorded deviations, snags, or unusual decisions. These are the most likely sources of subtle bugs.

- [ ] {item — reference the log entry if useful}

## Standard checks

Routine verification across completed slices.

- [ ] {item}

## Open questions

Anything unresolved at the end of implementation. If none, omit this section.
```
