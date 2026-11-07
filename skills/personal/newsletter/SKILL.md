---
name: newsletter
description: Run the monthly "AI in JS" section of the Team JavaScript Newsletter through its three phases — Gather (research dump), Scope (trim to a locked budget), Prose (draft to house voice). Use when the user says "/newsletter", "start this month's newsletter", "gather for the newsletter", "scope the newsletter", "draft the newsletter section", or names a newsletter edition month.
---

# AI in JS newsletter

Ariel writes the recurring **AI in JS** section of Infinum's Team JavaScript
Newsletter. One edition file per month holds all three phases, so the work
survives session boundaries.

## Constants

- **Edition file**: `Areas/AI/Newsletter/{YYYY-MM} {Month}.md` in the notes vault
- **Frontmatter tags**: `newsletter`, `ai-champ`
- **Phase headings**, in order: `# Gather`, `# Scope`, `# Prose`
- **Fixed sign-off**: *"If you're using AI in interesting ways, we'd love to hear about it."*

## The cardinal rule

**Agree the raw content first, then trim, then draft.** Do not rush to prose.
Each phase is its own session. A phase never re-opens the one before it — if
Scope is marked LOCKED, the Prose agent drafts and does not renegotiate.

## Detect the phase

Read the edition file (create it from the phase headings if absent) and pick up
where it left off:

| File state | Phase |
|---|---|
| Missing, or `# Gather` empty | **1 — Gather** |
| `# Gather` full, `# Scope` empty or unlocked | **2 — Scope** |
| `# Scope` marked LOCKED, `# Prose` empty | **3 — Prose** |
| `# Prose` drafted | Pre-send checks, then done |

State the detected phase before starting. If the user names a phase explicitly,
believe them.

## Phase 1 — Gather

Dump raw material, unfiltered. Volume is the point; judgement comes next phase.

1. Find the **last sent** edition to bound the window ("since 2026-06-08") and
   confirm the newsletter number and the AI-in-JS ordinal.
2. Sweep every source in [references/gather-sources.md](references/gather-sources.md),
   grouping finds under the section template's headings.
3. **Walk the dump with Ariel and fold in his own takes** — this is where the
   edition gets its point of view. Mark starred items (★) and note who shared
   what; contributor names are the community section's currency.
4. **Propose the section list** — which of the recurring `###` blocks this
   edition runs, and what lands in each. That is the edition's structure; do this
   before any talk of a theme.
5. **Only then, note a theme if one is actually there.** Most editions are a set
   of curated blocks with at most a light thread through the intro. If two or
   three items genuinely say the same thing, name it and check it against the
   retired frames in [references/voice.md](references/voice.md). If they don't,
   say so and move on — "no spine this edition" is a normal outcome, and hunting
   for one produces frames nobody asked for.
6. Do not trim yet. Park doubtful items under a "hold?" heading with the reason.

## Phase 2 — Scope

Distill. Invoke the `/scope` skill to run the interview, then write its result
into `# Scope` as a block ending with **`SCOPE — LOCKED ({date})`**. The block must carry:

- **Building** — the named `###` sections in final order, each with its specific
  items. This is the block's backbone: the section list *is* the plan.
- **Word budget per section**, summing to the target with a hard ceiling and a
  named first-cut ("if over, cut the Grok line first")
- **Theme, if there is one** — one optional line, in Ariel's words, plus where it
  shows up (usually the intro, sometimes the close). Write "no spine this
  edition" when there isn't one; that is a valid locked answer, not a gap
- **Not building** — everything dropped, *with the reason*, so it isn't
  re-litigated in Prose or re-gathered next month
- **Done when** — the acceptance line

Target ~300 words. See [references/voice.md](references/voice.md) for the
sent-length history and why the number pulls back rather than up.

## Phase 3 — Prose

1. **Read the last sent edition's `# Prose` first** to match voice. Don't invent
   a new format. See [references/voice.md](references/voice.md).
2. Re-read the LOCKED scope block and treat the budget as binding.
3. Draft into `# Prose` under a `## AI in JS — {Month} ({send date})` heading.
4. Word-count the draft before presenting it. Over the ceiling, apply the
   scope block's named first-cut.
5. **If the scope block names a theme**, keep it legible but light — a clause in
   the intro, sometimes an echo at the close, and *demonstrated* in between
   rather than restated. Sections that aren't on-theme are fine and normal; do
   not bend an item to fit. If the block says there's no spine, write the
   sections and don't manufacture one.

## Before send

- Confirm the newsletter number and AI-in-JS ordinal against the last sent edition
- Every Slack/blog reference links out; contributor names spelled right
- Any security item is framed so it can't be misread (name the exact product)
- Sign-off present, plus any one-off addition the scope block called for
- Superseded drafts kept under a `## Earlier draft (superseded {date})` heading
