# Pipeline: stage briefs

Every stage is a fresh sub-agent. Each brief points it at `BRIEF.md` (the shared facts), names its
inputs and outputs by absolute path, and asks for a short report. The orchestrator reads reports
and the small markdown artefacts, never clips or code.

## Run directory

```
<run>/                       e.g. <task docs>/demo/run-YYYY-MM-DD/
  BRIEF.md                   shared facts and rules (orchestrator writes it)
  SCRIPT.md                  beat sheet + captions (script agent)
  RECORDING.md               what was actually captured (recorder)
  clips/  frames/  logs/     WebM clips, stills, notes (cleanup-before.md, recorder-issues.md, ...)
  music/  previews/          candidate tracks, one preview cut per track
  edit/                      project.json, segments.tsv, timeline.tsv, versions/vN/
  <name>-vN.mp4              every version kept
```

## BRIEF.md (write it before any agent runs)

- What the product is, in one paragraph, and where its README/spec live.
- The run directory and what goes where.
- Facts established: running URLs (never start a second stack; if a port stops answering, stop and
  report), test accounts/repos/workspaces that may be touched, logged-in browser profile, things
  known to be broken that must be skipped (and not fixed).
- Rules for all agents: touch only the named external resources; never print secrets or `.env`;
  don't change application code (record problems in `logs/`); the content rules from SKILL.md;
  browser automation via `agent-browser` at 1440x900; finish with a short report.

## 1. Clean slate (before recording)

Goal: the product and every external system it touches look like a first-time user's.

1. **Inventory first, no changes.** List everything left from earlier runs: comments, PRs, branches,
   issues, records, uploaded files, app state, settings. Write `logs/cleanup-before.md` with IDs.
2. Propose a plan (what to delete/close/reset, and anything ambiguous, such as a branch that is also
   the head of a human-authored PR). **The user confirms destructive steps.**
3. Execute, then verify and append an "After (verified)" section: counts that are now zero, app
   state empty, settings at their demo values.

## 2. Script (beat sheet)

Inputs: BRIEF, the product's README/spec, the user's own framing (talk script, pitch, notes).

- Audience: a newcomer. State a target runtime (2–3 min is typical) and a hard range.
- **Read real UI labels from the code** (components, copy files), list them in a "UI reference"
  section, and quote them exactly in each beat so the recorder can click by text.
- One beat = one idea = one clip: `### Bnn · Surface · what happens · target s [running total]`,
  then Screen (URL, exact element), Actions, exact text to type/paste, Caption (≤10 words).
- Mark beats that contain a wait (webhook, job, AI run, deploy) as **WAIT**, with how to tell the
  wait is over (an API field, a UI state).
- Mark optional beats and which to drop first. Add ordering notes and alternatives.
- List anything that must never be on screen in this product (attribution footers, settings that
  name a model, a token page) and where it lurks.
- Flag open blockers for the user (for example: no logged-in browser for a private site).

## 3. Recorder

Read [recording.md](recording.md) before starting. Output: `clips/NN-slug.webm`, `RECORDING.md`.

## 4. Editor

Inputs: RECORDING.md, SCRIPT.md, clips. Read [editing.md](editing.md) and [music.md](music.md).

1. Write `edit/segments.tsv` from the trim hints; fill `project.json`.
2. `build.py --plan` until acts fit their bars and there are no caption warnings.
3. Build `--tag vN`, run `stills.py`, look at the stills yourself before handing over.
4. Report as a table of changes from the previous version (see editing.md).

## 5. Reviewer (frame check)

A fresh agent that did not edit. Inputs: the video, `timeline.tsv`, the stills, SCRIPT.md, the
content rules. It checks every cut point and caption still for:

- leaked internals: model names, scores, pipeline/step names, attribution lines, settings, login or
  token pages, terminal output, a half-loaded or error page, the recording tool's chrome
- a caption arriving at the same instant as new on-screen text, or gone before it can be read
- a zoom that crops away what the caption points at; text sped up while being read
- crushed or shifted colours against a reference screenshot; black or duplicate frames
- wording that invites a side question or contradicts what is on screen

It returns `pass` or a numbered list of findings with timestamps. Fix, rebuild as vN+1, re-review.

## 6. User review, then clean slate again

Show the user the version, the changes table and any reviewer notes. Iterate. **Only after the user
approves the video** run the clean-slate stage again, using the "external artefacts created" list in
RECORDING.md as the inventory. Cleaning earlier would make re-shoots impossible.
