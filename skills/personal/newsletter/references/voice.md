# House voice and section template

## Section template

The recurring taxonomy. **"From the community"** and **"At the frontier"** are the
signature sections — they appear every edition and are what the audience turns up
for. The rest flex.

```
Intro (+ through-line) → New models → Tool updates (Cursor / Claude Code)
→ From the community → At the frontier → Heads-up / Security (as needed) → Sign-off
```

Headings are `###` under a `## AI in JS — {Month} ({send date})` heading. Rename a
section when the framing earns it — July ran "Steering agents from your phone"
and "From the community: local models" instead of the generic labels, because the
beat was a workflow rather than a changelog.

Fixed sign-off, italicised, after a `---`:

> *If you're using AI in interesting ways, we'd love to hear about it.*

## Length

Measured from **sent** editions, not vault drafts:

| Edition | Words |
|---|---|
| Jan | ~253 |
| Feb | ~367 |
| Mar | ~341 |
| #42 (Apr) | ~350 |
| #43 (Jun) | ~400 |
| #44 (Jul) | ~300 |

The section crept up toward 400. The whole point of "AI in JS" is cutting through
the noise, so **the default is to pull back toward ~300, not to match the last
edition.** Set a hard ceiling ~20 words above target.

## Voice

- **Chunky bullet-paragraphs.** New models is a tight bullet list, one line each.
  Narrative sections are 2–4 sentence paragraphs, not bullets.
- **Bold the proper noun** that opens an item — **GPT-5.6 Sol**, **Remote Control**.
- **Link out, always** — Slack permalinks for community items, vendor blog or
  changelog for releases, article URL for thinkpieces. Inline markdown links.
- **Name people.** Community items credit the person who shared or built the
  thing. It's an internal newsletter; the names are half the value.
- **"From the community" covers reading, not just building.** An outside article
  or post worth someone's time belongs here alongside in-house tools and
  experiments — say in a line why it's worth opening, and link it.
- **Concrete numbers over adjectives** — "under half the tokens, half the time,
  a third the cost" beats "much more efficient".
- **Honest, not promotional.** "Sonnet 5 underwhelmed" ships as-is. Lukewarm takes
  are the credibility.
- **Dry, no hype, occasional dry aside** — "Human in the loop, minus the desk."
  One per edition, at most.
- **Second person, present tense.** Speak to a JS dev deciding what to try Monday.
- **No em-dash pile-ups, no "delve", no "in the ever-evolving landscape".**

## Themes (optional)

**Most editions do not need a spine.** The format is a short intro plus four to
six curated `###` blocks — that is what the audience turns up for, and the sent
editions bear it out. Where a theme exists it lives in the intro sentence and
sometimes the close, and is *demonstrated* by the blocks rather than imposed on
them. Blocks that sit off-theme are normal.

Do not go hunting for a frame. If two or three items genuinely converge, name it
and check it against the retired list below. If they don't, write "no spine this
edition" in the scope block and move on — a manufactured spine costs words and
bends items out of shape.

Past themes, all retired:

- **Feb** — the bottleneck moved from implementation to ideas
- **Apr** — AI sped up dev; QA and design are now the bottleneck
- **Jun** — autonomy: agents running longer with less hand-holding
- **Jul** — not the smartest, just smart enough, faster, cheaper (+ decentralization)

**Check any candidate theme against this list.** July had a strong Geoffrey Litt
piece ("understanding is the new bottleneck") lined up for the close and dropped
it — a third bottleneck-moves frame would have read as repetitive. A frame is
retired for a good while once used.

A candidate that doesn't win the edition isn't wasted — park it in the edition
file as a future candidate. The material behind a good frame rarely goes stale
as fast as the news does.
