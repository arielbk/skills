---
name: demo-video
description: Produce a short, music-cut demo video of a web app or tool for someone who has never seen it — orchestrating sub-agents through clean slate, beat sheet, browser recording, data-driven editing, frame review and final cleanup. Bundles an ffmpeg + Swift edit toolkit (bar-aligned music, captions, cards, punch-ins). Use when the user says "/demo-video", "make a demo video", "record a demo", "screen-record a walkthrough", or wants a product walkthrough video cut to music.
---

# Demo video

Make a 2–3 minute video that shows a newcomer what a product does, in the product's real UI, cut to
music. You are the **orchestrator**: each stage runs in a fresh sub-agent with a written brief; you
keep the plan, relay decisions to the user and read only reports and small markdown artefacts —
never clips, frames or edit code.

> Free-form questions only, in plain chat. Ask the user for framing; don't invent the pitch.

## Before starting

1. Agree the story with the user: audience, runtime, the one thing the viewer should take away.
   Framing and copy come from **the user's own words** (a talk script, pitch, README). Look or ask.
2. Create a run directory (`<task docs>/demo/run-YYYY-MM-DD/`) and write `BRIEF.md`: product,
   running URLs, accounts/repos the agents may touch, known-broken things to skip, and the rules
   below. Layout and brief contents: [pipeline.md](resources/pipeline.md).

## Pipeline

Each stage is one sub-agent; brief details are in [pipeline.md](resources/pipeline.md).

1. **Clean slate.** Inventory leftovers from earlier runs first (`logs/cleanup-before.md`); **the
   user confirms destructive steps**; then clean and verify.
2. **Script.** `SCRIPT.md` beat sheet: one beat = one idea = one clip, real UI labels read from the
   code, exact texts to paste, short captions, **WAIT** beats marked, optional beats ranked.
3. **Record.** `agent-browser` at 1440x900, one clip per beat, never record a wait. Writes
   `RECORDING.md` with trim hints and a list of external artefacts created. Gotchas (logged-in
   profile, screen lock, doubled clicks, stray tabs): [recording.md](resources/recording.md).
4. **Edit.** Choose music with the user, then `segments.tsv` + `project.json` -> `build.py`.
   [editing.md](resources/editing.md), [music.md](resources/music.md), toolkit
   [edit/README.md](resources/edit/README.md).
5. **Review.** A fresh agent frame-checks every cut point (`stills.py`) against the content rules.
   Fix and rebuild as a new version until it passes.
6. **User review** of each version with a changes table. Iterate.
7. **Clean slate again, only after the user approves the video**, using RECORDING.md's artefact
   list. Not before: re-shoots must stay possible.

Hand-offs between stages are files in the run directory. If a stage reports a blocker (no logged-in
browser, a broken flow, a locked screen), stop and surface it to the user rather than working around
it.

## Rules for every agent

- The video shows **no** model names, scores, pipeline internals, prompts, "Generated with Claude
  Code", `Co-authored-by:` lines, settings, login or token pages, or terminal output. Frame-check
  every cut point.
- Touch only the external resources named in BRIEF.md. Never print secrets. Don't change the
  product's code; log problems instead.
- Captions say what the screen shows, with the product's actual labels. Avoid wording that invites a
  side question. No decorative emoji.
- Keep every version (`--tag vN`); the build is re-runnable from its data files.

## Editing in one screen

- Reading holds ≈ 3 words/s + 1.5 s; never speed up text being read; stagger captions and new
  on-screen text; eased 1.3–1.6x punch-ins on what to read; captions ≤10 words.
- Explainer intro cards over the track's sparse intro, hard cut into the product on the drop; acts
  start on phrase starts; break bars saved for the 1–2 key moments; end on the track's own outro.
- Cards: one idea each, bold ink line + smaller grey line, generous whitespace.
- Colour: agent-browser WebM is full-range BT.601; decode it as such and encode limited BT.709
  (the toolkit does this).

## Reference

- [pipeline.md](resources/pipeline.md) — run layout, BRIEF.md, every stage's brief and outputs
- [recording.md](resources/recording.md) — agent-browser setup, gotchas, RECORDING.md format
- [editing.md](resources/editing.md) — pacing, captions, zooms, cards, content rules, changes table
- [music.md](resources/music.md) — sourcing, previews, drop/bar analysis, the music map
- [edit/README.md](resources/edit/README.md) — running `build.py`, `analyze_music.py`, `stills.py`
- [example-twice.md](resources/example-twice.md) — a full worked run with its v4 config
