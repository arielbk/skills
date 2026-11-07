# Worked example: Twice (2026-11-07)

Twice is a POC that watches PR review comments on GitHub, groups repeated corrections into topics,
and turns a recurring one into a lint-rule PR. The demo shows a newcomer the full loop across two
demo repos. Run directory: `~/.trace/tasks/review-to-lint-poc/demo/run-2026-11-07/` (BRIEF.md,
SCRIPT.md, RECORDING.md, logs/, edit/). Final cut: `twice-demo.mp4` (v4), 3:23.

## How each stage went

| Stage | What happened | Lesson baked into the skill |
|---|---|---|
| Clean slate | Inventory found 5 old comments, an open bot PR and 8 leftover branches in two repos; the user confirmed, the agent closed/deleted and verified zero remained, then reset app state | Inventory first, user confirms, verify after |
| Script | 21 beats with UI labels copied from `web/src/components`; WAIT beats for webhooks and the rule run; a "never scroll to the PR footer" note (tool attribution) | Real labels from code; WAIT beats; list where internals lurk |
| Recorder | Chrome Default profile wasn't logged in to GitHub, the user's browser couldn't be attached; the user logged in once in `~/.agent-browser/gh-profile`. Clicks doubled after `record start`, so GitHub was driven through the DOM. The screen locked mid-run and Chrome stopped painting; recording resumed after unlock with caffeinate. 20 clips, 309 s raw | Dedicated profile, `close --all`, keyboard/DOM input, caffeinate |
| Recorder | The product named the topic "Prefer Guard Clauses", not the scripted "Prefer Early Returns"; RECORDING.md flagged it so captions matched the screen | Record what the product actually said |
| Recorder | The squash-merge dialog showed `Co-authored-by:` with a model name for ~18 s; the trim hint gave exact seconds and the edit cut straight from the button click to the merged state | Note internals with seconds; cut around them |
| Editor v1–v2 | Light greys (#fafafa) crushed to white until the WebM was decoded as full range; captions needed CoreText because Homebrew ffmpeg lacks drawtext | Explicit full-range decode, BT.709 tags, Swift renderer |
| Editor v3–v4 | Four Pixabay tracks, one preview each; the user picked "Jazzy Hip Hop Boom Bap" (88 BPM, drop 11.229 s, break bar 7, variation 19, outro 22–23). v3's single intro card with three lines became three one-idea cards on the intro's bar marks; the story became five acts on phrase starts; break bars placed before "Add a lint rule" and "Merged"; the end card plays over the track's outro | Music map, acts on phrases, break bars for key moments, one idea per card |
| Copy | Intro and end copy came from the user's own talk ("Same correction twice? That's a harness problem.", "Guardrails for conventions. Reviews for architecture."). "Meanwhile, a different team" became "Later, another project" | User's words; avoid side questions |
| Order | The cross-repo beat moved after the merge so the video ends on the bot saying the other repo already enforces the rule: a stronger payoff than "goes quiet" | End on the strongest proof |
| Cleanup | Deferred until the user approved v4; RECORDING.md lists every comment ID, the rule PR #11 and its merge SHA | Final clean slate after approval |

## The v4 config

`edit/project.json` equivalent (the toolkit reproduces the original v4 frame for frame):

```json
{
  "brand": { "name": "Twice", "logo": "<repo>/brand/twice-logo-rounded.png" },
  "clips": "../clips",
  "output": "../twice-demo.mp4",
  "music": { "file": "../music/jazzy-hip-hop-boom-bap_Music_Unlimited.mp3",
             "bpm": 88, "drop": 11.229, "end": 77.256 },
  "intro_cards": [
    { "at": 0.0,  "layers": [["head", "Same correction twice?", 0.30], ["sub", "That's a harness problem.", 0.98]] },
    { "at": 3.73, "layers": [["brand", "", 3.73], ["sub", "turns repeated review comments into guardrails.", 4.08]] },
    { "at": 7.82, "layers": [["head", "Conventions get checked.", 7.82], ["sub", "Reviews focus on architecture.", 8.50]] }
  ],
  "acts": [
    { "name": "1 first comment -> topic",             "beats": ["B01", "B02", "B03"], "bars": 12 },
    { "name": "2 decoy -> 2nd PR -> recurring",       "beats": ["B04", "B05", "B07", "B08", "B09"], "bars": 20 },
    { "name": "3 add rule -> rule PR -> proof",       "beats": ["B12-13", "B14", "B15", "B16"], "bars": 15 },
    { "name": "4 merge -> resolved",                  "beats": ["B17", "B18"], "bars": 7 },
    { "name": "5 another project -> already a check", "beats": ["B10", "B11", "B11b"], "bars": 14 }
  ],
  "end_card": { "bars": 2, "layers": [["brand", "", 0.0], ["sub", "Guardrails for conventions. Reviews for architecture.", 0.68]] },
  "music_map": ["0-6", 15, "8-11", "8-15", "8-15", "12-14", 7, "8-15", "8-14", 7, "8-13", "8-15", "16-23"]
}
```

Reading the map: act 1 plays bars 0–6, swaps the break (bar 7) for bar 15 to save it, then 8–11;
act 2 ends on the break (7) so act 3 opens with "Add a lint rule" on a fresh phrase; act 4 starts
on the break so "Merged" (`lock=bar` on B17) lands on the downbeat after it; act 5 rides 8–15 then
the variation and outro (16–23) under the end card.

A few `segments.tsv` rows from the run, showing the patterns:

```
B02  02-gh-first-comment.webm         3.5  8.5  1.5  0                        0.3  A reviewer asks for early returns.
B02  02-gh-first-comment.webm         8.5  15.5 1    0    1>1.5@800,600@0+1.0 =    A reviewer asks for early returns.
B02  02b-gh-first-comment-posted.webm 6.0  9.0  1    5.8  1.5@790,330         =    A reviewer asks for early returns.
B17  17-gh-merge.webm                 1.5  4.6  1    0                        0.5  A maintainer merges it.          bar
B17  17-gh-merge.webm                 26.0 29.0 1    0.8  1>1.3@530,250@0.2+1.0 =  A maintainer merges it.
```

The page load and scroll run at 1.5x, the comment being written plays at 1x with a punch-in, the
posted comment holds 5.8 s for reading while staying zoomed across the cut; the merge cuts from
the button click (4.6 s) straight to the merged state (26.0 s), skipping the dialog with attribution.
