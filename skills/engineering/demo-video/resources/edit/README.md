# Edit toolkit

Data-driven editor for a demo video: recorded clips + a cut list + a music bed -> one MP4. macOS only
(the text renderer uses AppKit). Needs `ffmpeg` (Homebrew is fine, no drawtext needed) and `swiftc`
(Xcode command line tools). Python is stdlib only; run every script with `python3 -I`.

| File | What it does |
|---|---|
| `build.py` | Plans and builds the video from `project.json` + `segments.tsv` |
| `render.swift` | Draws captions and card layers as PNGs (compiled on first build into `<work>/.bin/render`) |
| `analyze_music.py` | Finds a track's drop, tempo, bar grid, break and outro bars |
| `stills.py` | Pulls review stills at every cut point of a built video |
| `project.json` | Template config: paths, music numbers, intro/end cards, acts, music map |
| `segments.tsv` | Template cut list; its header comments document every column |

Run the scripts in place from the skill. Copy `project.json` and `segments.tsv` into the run's
`edit/` directory and edit them there; the scripts stay generic.

## Run

```bash
T=<skill dir>/resources/edit
python3 -I $T/analyze_music.py music/track.mp3            # drop, bpm, bars -> project.json "music"
python3 -I $T/build.py edit/project.json --plan           # act timing, bar fit, caption warnings
python3 -I $T/build.py edit/project.json --tag v1         # -> <output>-v1.mp4 and <output>-v1-silent.mp4
python3 -I $T/stills.py demo-v1.mp4 edit/timeline.tsv stills/v1
```

`--tag vN` refuses to overwrite an existing version and snapshots `project.json`, `segments.tsv`,
`timeline.tsv` and `build-info.json` into `edit/versions/vN/`, so every cut stays reproducible. A
full build of a ~3 min video takes about 4 minutes; `--plan` is instant, so iterate on the plan.

## project.json

Paths are relative to the project file.

| Key | Meaning |
|---|---|
| `brand.name`, `brand.logo` | Wordmark and logo for `brand` card layers (logo optional) |
| `clips`, `segments`, `output`, `work` | Clip dir, cut list, output MP4, scratch dir (default `.work`) |
| `fps`, `crossfade_frames` | Default 30 and 10 (crossfade between beats inside an act) |
| `music.file/bpm/beats_per_bar/drop/end/loudness` | From `analyze_music.py`; `end` = track end in s; loudness default -18 LUFS |
| `intro_cards` | `{"at": s, "layers": [[kind, text, appear_s], ...]}`; times are video seconds = track seconds. They must cover up to the drop; put card changes and second lines on the intro bar marks |
| `acts` | `{"name", "beats": [beat ids in play order], "bars": n}`. Each act starts on a bar line; `--plan` suggests a bar count when the fit is off by more than a bar |
| `end_card` | `{"bars": n, "layers": [...]}`, plays over the last `n` bars of the map |
| `music_map` | Source bar (0 = drop) for every video bar after the drop: ints or `"a-b"` ranges. Length must equal the acts' bars + end card bars. Omit it to play the track straight through |
| `layout.head_y`, `layout.sub_y` | Card line centres in px (default 405 / 500) |

Layer kinds: `head` (large bold ink), `sub` (smaller grey), `brand` (logo + wordmark; text overrides
the name). Each layer fades in at its time with a small upward drift; intro cards fade their text out
0.25 s before the next card.

## What the build does

1. Each segment: trim, optional speed-up, decode full-range BT.601 to RGB (agent-browser WebM is
   full range; without this, `#fafafa` greys crush to white), pillarbox if narrower than 1440x900,
   freeze `hold` seconds, optional eased zoom, caption fade-in, then limited-range BT.709 with tags.
2. Rows of one beat hard-cut together; beats crossfade inside an act. Each act is stretched or
   squeezed to its bar count by adjusting the beats' last segments (holds), with inner crossfade
   midpoints snapped to the beat grid. `lock=bar` makes a segment end exactly on a bar line.
3. Intro cards fill exactly the frames before the drop, so the cut into the product lands on it.
4. Music is rebuilt per `music_map` with 30 ms crossfades at every jump. If the map ends on the
   track's last bar, its own decay plays out after the end card; otherwise it fades over one bar.
   Then it is gained to the loudness target.
5. Writes `timeline.tsv` (every segment's start/end and caption time, the reviewer's index) and
   `<work>/build-info.json` (drop frame, seams, act starts, measured loudness).

## Colour check

If a light UI looks blown out or too dark, check the source: `ffprobe -show_streams clip.webm | grep
color`. The decode assumes full range BT.601 (what agent-browser writes). For clips from another
recorder that are limited range, change `DECODE` in `build.py` to `in_range=tv`. Compare a still of
a light grey panel against a screenshot of the same page.

## Music previews

To let the user pick a track by ear, mux the current silent cut with each candidate, aligned so the
candidate's drop sits on the cut into the product (`D` = that track's drop, `V` = the build's drop
frame / fps from `build-info.json`):

```bash
ffmpeg -i demo-v1-silent.mp4 -ss $(echo "$D - $V" | bc) -i candidate.mp3 \
  -map 0:v -map 1:a -c:v copy -c:a aac -shortest previews/demo_<track>.mp4
```

(If `D < V`, use `-itsoffset $(echo "$V - $D" | bc)` before `-i candidate.mp3` instead of `-ss`.)
