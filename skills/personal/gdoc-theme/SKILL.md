---
name: gdoc-theme
description: Create Google Docs in Ariel's house theme — Helvetica Neue, black body text, Infinum red (#D82828) as the only accent. Use when asked to make a Google Doc, put a note or markdown file into Google Docs, restyle an existing doc to match previous ones, or when the user refers to "the theme we used", "black text with red", or the Infinum doc look.
---

# Google Docs house theme

Authored HTML is imported through Drive rather than assembled with `docs.batchUpdate`
index arithmetic. The importer handles headings, nesting, bold and colour correctly;
`publish.py` then runs a fixup pass for the things HTML import cannot express
(the Title, callout boxes, monospace, heading spacing).

## Quick start

Write a **body fragment** (no `<html>`/`<head>`/`<style>` — the script adds the theme):

```html
<h1 class="doctitle">Doc Name</h1>
<p class="subtitle">One-line standfirst</p>

<h1>First section</h1>
<ul>
  <li><b>A bold lead-in</b> — then the detail</li>
  <li>Run <code>pnpm install</code> to see it. Nested bullets work to three levels.</li>
</ul>

<table class="callout"><tr><td><b>Practical</b> — the recurring block element,
drawn as a full-width tinted box.</td></tr></table>
```

Then publish:

```bash
# create
scripts/publish.py --html body.html --title "Doc Name"

# replace an existing doc's content, keeping the same URL
scripts/publish.py --html body.html --doc-id <fileId>

# restyle a live doc in place — content and hand edits untouched
scripts/publish.py --doc-id <fileId>
```

Both print the doc URL. Run from a writable directory — `gws` refuses `--upload`
paths outside the cwd, so the script stages its temp file there and deletes it after.

## The theme

| Element | Style |
|---|---|
| Body / everything | Helvetica Neue 11pt, black, 1.45 line height |
| Doc title | `h1.doctitle` → becomes Docs *Title*, 26pt bold |
| Standfirst | `p.subtitle` → 14pt grey `#666666` |
| Section | `h1` → 20pt black |
| Sub-section | `h2` → 14pt **red** |
| Item | `h3` → 13pt black |
| Stacked headings | a heading straight after another gets 8pt above, not full |
| Accent run | `<span class="red">` or `class="redb">` (bold) |
| Links | red + underlined, not Google blue |
| Pull quote | `<blockquote>` → indented italic `#333333` |
| Indented aside | `<p class="note">` — indent only, no box |
| Callout box | `<table class="callout">` → full-width `#F4F9FF` box |
| Inline code | `<code>…</code>` → Roboto Mono 10pt on `#F1F1F1` |

Headings render **not bold** — that is correct and matches the source docs.
Weight comes from size, not boldness.

### House colours

| Colour | Use |
|---|---|
| `#D82828` | Infinum red — the accent. `h2` and links, nothing else |
| `#F4F9FF` | Light blue block fill — callout backgrounds |
| `#F1F1F1` | Grey — inline code tint |
| `#666666` / `#333333` | Standfirst grey / pull-quote grey |

## Using the accent

Red is the only colour in the document, so it has to mean one thing. Pick a single
recurring element and mark every instance of it — section dividers (`h2`), or a
repeated label like `Practical — …`. Roughly 10–20 accents across a long document.
Do not redden arbitrary emphasis; that is what `<b>` is for.

## Callouts

A callout is a **single-cell table**, not a shaded paragraph:

```html
<table class="callout"><tr><td><b>Practical</b> — the body of the callout.</td></tr></table>
```

Paragraph shading has no inner padding, so a shaded paragraph leaves the text
hugging the tint edge and cannot be rescued. A table cell has real padding on all
four sides, and both the fill and the padding survive the import. This is also what
the house pen-test report does. Cell borders stay unset and render as none.

The box runs the full content width and aligns with the body text — no indent, so it
reads as a block rather than a quotation. Keep it to one recurring structural
element.

Two things the fixup has to correct, both handled automatically:

- **Air around the box.** A Docs table takes no margin, so `CALLOUT_GAP` points are
  applied to the paragraphs either side instead.
- **Lopsided padding.** The importer maps the cell's CSS padding onto *both* the
  cell padding and the inner paragraph's `spaceAbove`/`spaceBelow`, so it lands
  twice. Docs suppresses `spaceAbove` at the top of a cell but honours `spaceBelow`
  at the bottom, which makes an untreated callout visibly bottom-heavy. The fixup
  zeroes the inner paragraph spacing and lets the cell padding do the work.

## What survives the Drive HTML importer

Established by probe, not by assumption. Re-probe before trusting anything not listed.

| CSS | Result |
|---|---|
| `margin-bottom` | ✅ → `spaceBelow` |
| `margin-top` | ❌ **silently dropped** — use `padding-top` |
| `padding-top` / `padding-bottom` | ✅ → `spaceAbove` / `spaceBelow` |
| `margin-left`, `padding-left` | ✅ → `indentStart` (both, summed) |
| `line-height` | ✅ → `lineSpacing` |
| `color`, `font-size`, `font-weight` | ✅ |
| run `background-color` on `<span>` | ✅ → `textStyle.backgroundColor` |
| any CSS on `<code>` | ❌ dropped — `wrap()` rewrites `<code>` to a tinted `<span>` |
| `<td>` `background-color` | ✅ → `tableCellStyle.backgroundColor` |
| `<td>` `padding` | ⚠️ → cell padding **and** inner paragraph spacing (twice) |
| `font-family` on a run | ❌ stripped — must be set in the fixup |
| `border-*`, paragraph `background-color` | ❌ dropped — must be set in the fixup |

## Gotchas

- **`margin-top` does nothing.** The single most likely cause of a cramped-looking
  doc. Space above a block comes from `padding-top`.
- **Heading spacing is pinned in the fixup, not in CSS.** The importer folds a
  preceding `<ul>` or `<blockquote>`'s bottom margin into the next element, so a
  heading after a list would otherwise get no space at all. `HEADING_SPACE` in
  `publish.py` is the source of truth; the CSS values are a fallback.
- **A heading directly above another heading takes `STACKED_HEADING_ABOVE`,** not its
  usual space. A section heading and the first sub-heading under it are one unit;
  full separation leaves the sub-heading looking detached from its section.
- **Monospace works via the tint, not the font.** `font-family` is stripped on
  import but run `background-color` survives, so the `#F1F1F1` tint doubles as the
  marker the fixup looks for. Change the tint in `theme.css` and `CODE_TINT` in
  `publish.py` together or monospace stops being applied.
- **A callout can split across a page break** in PDF export. Harmless on screen;
  worth a manual page break if the doc is going to be printed.
- **The first heading is not a Title.** The importer makes it another `HEADING_1`.
  The fixup promotes it.
- **Heading colour lands on the named style, not the runs.** The importer maps
  `h2 { color }` onto the `HEADING_2` named style, so a red `h2` shows no
  `foregroundColor` on its text run. Auditing runs alone will under-count the red —
  check `namedStyles` too.
- **`ParagraphBorder.color` is an `OptionalColor`,** i.e. `{"color": {"rgbColor": …}}`.
  Reading it as a plain `Color` makes a red border look black in the JSON.
- **Updating replaces everything.** `--doc-id` **with** `--html` overwrites the body
  wholesale. Comments anchored to replaced text are orphaned; suggestions and manual
  edits are lost. Once a doc has been shared or hand-edited, the HTML source on disk
  is no longer the source of truth — reach for the restyle form below instead, and
  confirm before overwriting a doc someone else may have touched.
- **Restyling in place.** `--doc-id` **without** `--html` re-runs the fixup against
  the live document and imports nothing, so hand edits survive. Every fixup request
  is idempotent, so repeating it is safe. This is how to roll a theme change out to
  a doc that is already in circulation. Verify by diffing the extracted text before
  and after — it should be byte-identical.

## Checking your work

Read back what actually rendered rather than trusting the request:

```bash
gws docs documents get --params '{"documentId":"<id>"}' > doc.json
gws drive files export --params '{"fileId":"<id>","mimeType":"application/pdf"}' --output out.pdf
pdftoppm -png -r 110 -f 1 -l 2 out.pdf pg    # then Read the PNGs
```

Colour lives in `body.content[].paragraph.elements[].textRun.textStyle.foregroundColor.color.rgbColor`
as 0–1 floats — the house red is `{red: 0.847, green: 0.157, blue: 0.157}`. Fonts are
under `weightedFontFamily`, with defaults in the top-level `namedStyles`.
