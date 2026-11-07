# Editing

The toolkit is in [edit/](edit/README.md): `build.py` (plan + build from `project.json` and
`segments.tsv`), `render.swift` (captions and cards; Homebrew ffmpeg has no drawtext/subtitles),
`analyze_music.py`, `stills.py`. Work only through the data files so every version rebuilds.

## Pacing and text

- **Reading holds:** any text the viewer must read (a comment, a reply, a result) stays on screen for
  about **3 words/s + 1.5 s**. Use `hold` (freeze the last frame) rather than slowing the clip. Cap
  very long texts at 8–10 s when the caption already carries the point.
- **Never speed up text being read.** `speed` 1.5 is for scrolls and page loads only.
- **Stagger** captions and new on-screen text: never at the same instant. Let the screen change
  land, then fade the caption in 0.3–1.2 s later (`cap_at`), or put the caption up first and let the
  screen change follow.
- **Short captions:** one idea, ≤10 words (aim for 5–8). `build.py --plan` warns on long captions
  and on captions shorter on screen than their reading time.
- Captions sit in the lower third; use `pos=top` when the lower third holds what is being read.
- **Punch-ins:** eased 1.3–1.6x zooms toward what the viewer should read (`1>1.5@cx,cy@t0+dur`),
  starting after the cut, about 1 s long. Continue a zoom across a hard cut with a constant
  `1.5@cx,cy`. Check stills that the zoom keeps the whole text in frame.
- Cut page loads and spinners that aren't the point. A wait the story needs ("it's working") gets
  2–4 s at most.
- Hard cuts inside a beat; short crossfades between beats; hard cuts on bar lines between acts.

## Cards

- One idea per card. Two-level hierarchy: a bold ink line (`head`) and a smaller grey line (`sub`),
  or the logo + wordmark (`brand`) with a `sub` line. Generous whitespace; nothing else on the card.
- Intro: two or three explainer cards over the track's sparse intro: the problem, what the product
  does, the outcome. Lines appear on the intro's bar marks; then a hard cut into the product on the
  drop. End card: brand + the one-line promise, over the track's own outro.
- Copy comes from the user's words (their talk, pitch, README). Ask or look; don't invent the pitch.

## Content rules (frame-check every cut)

- No model names, scores, confidence, pipeline/step names, prompts, "Generated with Claude Code",
  `Co-authored-by:` lines, settings panels, login or token pages, terminal output.
- Cut around dialogs and footers that carry attribution; keep any glimpse under 0.5 s and unreadable,
  or crop/blur.
- Avoid wording that raises side questions (in the Twice cut, "another team" became "another
  project": "team" made viewers wonder whether that other team should be told it was already
  handled elsewhere, a question the demo doesn't need to raise). Captions must match what is on screen (the product's actual labels and names).
- Don't present the tool's heuristics as facts it didn't produce.

## Story structure

- Acts, not a list of clips: setup -> first reaction -> the habit/problem recurring -> the one key
  action -> the result -> the payoff. Each act starts on a musical phrase start (see music.md).
- Save the music's break bars for the one or two key moments (the main click, the "it's done" state).
- End on the strongest proof the product works, then the end card.

## Iteration

- Keep every version: `build.py --tag vN` writes `<name>-vN.mp4` and snapshots the inputs to
  `edit/versions/vN/`. Never overwrite a version the user has seen.
- Report each version as a table of changes, for example:

| Where | Before (v3) | After (v4) | Why |
|---|---|---|---|
| 0:00–0:11 | one card, three lines | three cards, one idea each | easier to read on the beat |
| B10 caption | "a different team" | "another project" | "team" raised a side question |

- Include runtime, anything left undone, and the review-stills path.
