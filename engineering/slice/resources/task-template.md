# Task Template

Use this template for each slice in `docs/{feature}/{feature}.tasks.md`.

---

```markdown
### `{slice-slug}` — {Slice title}

**Status:** not-started

**Outside-in:** {Consumer-facing surface — API call, URL, component prop, CLI flag. Not the internal implementation.}

**Feedback loop:** {How we know this slice works. Specific test name, "manual: what to check", or "human review: who/what".}

**Human checkpoint:** yes | no

**Depends on:** {slug}, {slug} | none
```

---

## Status enum

| Value | Meaning |
|---|---|
| `not-started` | Not yet started |
| `in-progress` | Agent is actively working on it |
| `done` | Complete |
| `blocked` | Cannot proceed — dependency or external issue |
| `needs-review` | Done, waiting on human feedback before continuing |

## Example

```markdown
### `auth-route-skeleton` — Auth route skeleton

**Status:** not-started

**Outside-in:** `POST /api/auth/login` returns `{ token }` or `{ error }`

**Feedback loop:** Integration test: `POST /api/auth/login` with valid credentials returns 200 with token

**Human checkpoint:** no

**Depends on:** none
```
