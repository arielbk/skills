# Music

## Source

- Royalty-free only, with a licence that allows use in a published video (Pixabay Music works).
  Note the track name, artist and licence URL in `music/SOURCES.md`.
- Pixabay blocks `curl` (403). Download through the browser (`agent-browser` with a download
  path, or ask the user to download), into `music/`.
- Pick 3–4 candidates that fit the product's tone (an instrumental with a sparse intro, a clear
  drop, a steady groove and a real outro is easiest to cut to). Make **one preview per candidate**
  (silent cut + track aligned on the drop, see [edit/README.md](edit/README.md#music-previews)) and
  let the user pick by ear. Don't pick for them.

## Analyse

```bash
python3 -I <skill>/resources/edit/analyze_music.py music/track.mp3
```

- **Drop**: onset of the first hit after the sparse intro, to the ms. Confirm by ear; the script gives
  three candidates. Half/double tempo is the usual tempo miss: pass `--bpm` to re-print the grid.
- **Bars**: bar length = beats per bar x 60 / bpm. The table shows each bar's energy relative to the
  loudest: "lighter" bars are breaks or variations, "drop-out" bars at the end are the outro.
- **Intro bar marks**: the times before the drop where intro cards change and second lines appear.
- Write `bpm`, `drop`, `end` into `project.json`.

## Fit the story to the track

- Intro cards play over the track's intro; the first product frame is the drop (the build puts the
  drop exactly on that frame).
- Split the story into **acts that start on phrase starts** (in 4/4 hip-hop/pop, usually every 4 or 8
  bars, or wherever the loop restarts). `--plan` tells you each act's natural length in bars.
- `music_map` lists the source bar for every video bar. Repeat the groove sections to make the bed as
  long as the story; keep the loop's own pattern (if kicks alternate over 2 bars, jump even -> odd).
- **Save the break bars** for the 1–2 key moments: place a break bar right before the key action or
  result so it lands on the downbeat after the break (use `lock=bar` on that segment).
- **Bar-aligned seams** only; the build crossfades 30 ms at each jump.
- **End on the track's own outro**: end the map with the track's last bars so the end card plays over
  them and the natural decay finishes the video (no fade-out).
- Loudness -18 LUFS integrated (the default), true peak under -1.5 dBTP.
- Listen to the result at every seam; if one clicks or stumbles, move it a bar.
