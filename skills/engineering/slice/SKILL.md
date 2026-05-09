---
name: slice
description: Break aligned work into vertical tracer-bullet slices with explicit dependencies, outside-in API sketches, and per-slice feedback loops. Writes a docs/{feature}/{feature}.tasks.md DAG agents can work through. Use after /grill-me, or when the user wants to slice a plan into orchestrate-able tasks. Trigger phrases - "slice this", "break this into tasks", "/slice".
---

# Slice

Turn aligned work into a small DAG of vertical slices in `docs/{feature}/{feature}.tasks.md`. Each slice is end-to-end, has an outside-in API sketch, an explicit feedback loop, and an explicit dependency list — so an agent can pick any unblocked slice and run it.

This is NOT an issue-tracker tool. Output is a local markdown file the agent updates statuses on as work progresses.

> **Free-form questions only.** Any question this skill asks the user MUST be plain text in the chat. Do NOT use the `AskUserQuestion` multi-choice UI under any circumstance.

See [task-template.md](resources/task-template.md) for the exact slice format and status enum.

## Process

### 1. Check alignment

Look at the conversation context. Is there a clear goal, scope, and rough constraints?

- **Yes** → continue.
- **No, but the user passed a one-line prompt as an argument** → use that as the brief and continue.
- **No** → suggest the user run `/grill-me` first to align, then come back. Stop.

### 2. Explore the codebase if needed

If you do not yet understand the current shape of the code in the area being changed, look at it now. Skip if the brief is greenfield or you've already explored.

### 3. Derive the feature slug

Generate a kebab-case slug from the overall plan (e.g. `login-flow`, `checkout-redesign`). Confirm with the user if ambiguous.

### 4. Draft a slice DAG

Aim for **3–8 slices**.

<slice-rules>
- Each slice is a **vertical tracer bullet** — a thin path through every layer end-to-end.
- A completed slice is demoable or verifiable on its own.
- Slices form a DAG via `Depends on:`. Independent slices are valuable.
- Think outside-in: start from the consumer-facing surface, work inwards.
- Every slice has a feedback loop. If the only loop is "it looks right," the slice is under-specified.
</slice-rules>

### 5. Propose the draft and confirm

Show the user the draft slice list (title + one-line summary + deps). The user has likely just come out of `/grill-me` and is alignment-fatigued — assume they want to confirm and move on, not start another interrogation.

After the draft, surface a short **"Things to think about"** list calling out anything that is genuinely *not* cut-and-dry — at most 2–3 bullets. Each bullet is a one-line note, not a question. Pick from categories like:

- **Boundaries** — "Slices 2 and 3 share a lot of context; could merge if you'd rather."
- **Outside-in** — "Slice N's surface reads like an internal helper — flag if the consumer is different."
- **Feedback loops** — "Slice N relies on a manual eyeball check; there might be a cheap automated alternative."
- **Dependencies** — "Slice 4 depends on 2 but the schema change isn't used until 5; could run independently."
- **Checkpoint placement** — "No human checkpoints across the run; flag if anything user-facing should get one."
- **Missing slice** — "Nothing covers X; flag if that's a gap."

If nothing is genuinely uncertain, omit the section. Don't manufacture concerns.

End with a single confirmation prompt: "Look right, or want to adjust anything?" The user can sign off, push back on a specific bullet (which can become a back-and-forth), or rework the draft. Default mode is sign-off.

### 6. Write the file

Create `docs/{feature}/` if it doesn't exist. If `docs/{feature}/{feature}.tasks.md` already exists, ask before overwriting.

Load [task-template.md](resources/task-template.md) and use it to format each slice consistently.

### 7. Stop

Tell the user the tasks file is at `docs/{feature}/{feature}.tasks.md`, and that they can run `/dispatch {feature}` or `/implement {feature}` in a fresh session when ready. Then stop completely — do not offer to implement, offer to start a slice, or suggest what comes next. The user will `/clear` and continue when they're ready.

## File structure

```
docs/
  {feature}/
    {feature}.tasks.md   ← this skill writes this
    {feature}.prd.md     ← written by /to-prd
    {feature}.log.md     ← written by /implement
    {feature}.qa.md      ← written by /implement at end
```

## File template

```markdown
# {Plan title}

{1–2 sentence summary of what this plan delivers and why.}

## Slices

### `{slice-slug}` — {Slice title}

**Status:** not-started

**Outside-in:** {consumer-facing surface}

**Feedback loop:** {how we know this slice works}

**Human checkpoint:** yes | no

**Depends on:** {slug} | none
```
