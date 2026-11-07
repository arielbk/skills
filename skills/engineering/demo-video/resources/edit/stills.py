#!/usr/bin/env python3
"""Extract review stills at every cut point of a built video, from the timeline.tsv build.py wrote.

  python3 -I stills.py <video.mp4> <timeline.tsv> <out_dir>

For each timeline row: a frame just after it starts, one just before it ends, and one 0.6 s after
its caption fades in. Files are named <seconds>-<beat>-<in|out|cap>.png so they sort by time.
The reviewer looks at every one: half-loaded pages, leaked internals, crushed colours, captions
landing at the same instant as new on-screen text, a zoom that crops what the caption points at.
"""
import os, shutil, subprocess, sys

FFMPEG = shutil.which("ffmpeg") or "/opt/homebrew/bin/ffmpeg"


def grab(video, t, out):
    subprocess.run([FFMPEG, "-nostdin", "-v", "error", "-y", "-ss", f"{max(0, t):.3f}", "-i", video,
                    "-frames:v", "1", out], check=True)


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    video, timeline, out = sys.argv[1:]
    os.makedirs(out, exist_ok=True)
    n = 0
    with open(timeline) as f:
        next(f)
        for line in f:
            beat, start, end, _cap, cap_on = (line.rstrip("\n").split("\t") + [""] * 5)[:5]
            s, e = float(start), float(end)
            shots = [(s + 0.07, "in"), (e - 0.07, "out")]
            if cap_on and float(cap_on) + 0.6 < e:
                shots.append((float(cap_on) + 0.6, "cap"))
            for t, kind in shots:
                grab(video, t, os.path.join(out, f"{t:07.2f}-{beat}-{kind}.png"))
                n += 1
    print(f"wrote {n} stills to {out}")


if __name__ == "__main__":
    main()
