#!/usr/bin/env python3
"""Find a track's drop, tempo, bar grid and per-bar energy (stdlib + ffmpeg only).

  python3 -I analyze_music.py <track.mp3> [--bpm 88] [--drop 11.229] [--beats-per-bar 4]

Prints: drop onset (ms precision, the first kick after the sparse intro), tempo candidates, the
pre-drop bar marks (where intro cards change), the track end, and one row per bar after the drop
with low-band and full-band energy so you can spot break bars (quiet), variations and the outro.
Pass --bpm/--drop to override a wrong guess (half/double tempo is the usual miss) and re-print the
grid. Always confirm the drop by ear: listen to a preview cut on it.
"""
import array, math, shutil, subprocess, sys

SR = 8000
FFMPEG = shutil.which("ffmpeg") or "/opt/homebrew/bin/ffmpeg"


def decode(path, af=None):
    cmd = [FFMPEG, "-nostdin", "-v", "error", "-i", path, "-ac", "1", "-ar", str(SR)]
    if af:
        cmd += ["-af", af]
    raw = subprocess.run(cmd + ["-f", "s16le", "-"], capture_output=True, check=True).stdout
    a = array.array("h")
    a.frombytes(raw)
    return a


def ms_energy(x):
    """Sum of squares per 1 ms block."""
    n = SR // 1000
    return [sum(v * v for v in x[i:i + n]) / (n * 32768.0 ** 2) for i in range(0, len(x) - n + 1, n)]


def window(e, i, w):
    return sum(e[max(0, i):max(0, i + w)])


def db(v):
    return 10 * math.log10(v + 1e-12)


def find_drop(low, full):
    """Biggest sustained jump in low-band energy (1.5 s after vs 1.5 s before), refined to the ms on
    the full band: find the first hit's peak, then walk back to where its attack starts (15 dB down)."""
    W = 1500
    cands = []
    for t in range(1000, len(low) - W, 10):
        before = window(low, t - W, W) / W + 1e-9
        after = window(low, t, W) / W
        cands.append((after / before, t))
    cands.sort(reverse=True)
    picked = []
    for score, t in cands:
        if all(abs(t - u) > 3000 for _, u in picked):
            picked.append((score, t))
        if len(picked) == 3:
            break
    out = []
    for score, t in picked:
        e = lambda i: db(window(full, i, 2) / 2)
        top = max(e(i) for i in range(t - 150, t + 150))
        pk = next(i for i in range(t - 150, t + 150) if e(i) > top - 6)      # first hit, not the loudest
        onset = next((i + 1 for i in range(pk, pk - 150, -1) if e(i) < e(pk) - 15), pk)
        out.append((onset / 1000.0, score))
    return out


def tempo(low, drop_ms, lo=60, hi=180):
    """Comb score: mean low-band onset strength on the beat grid anchored at the drop."""
    flux = [0.0] * len(low)
    for i in range(10, len(low)):
        flux[i] = max(0.0, db(window(low, i - 5, 5)) - db(window(low, i - 15, 10) / 2))
    span = min(len(low), drop_ms + 60000)
    scores = []
    bpm = lo
    while bpm <= hi:
        step = 60000.0 / bpm
        hits, k = [], 0
        while drop_ms + k * step < span - 15:
            c = int(drop_ms + k * step)
            hits.append(max(flux[c - 12:c + 13]))
            k += 1
        scores.append((sum(hits) / max(1, len(hits)), round(bpm, 2)))
        bpm += 0.05
    scores.sort(reverse=True)
    out = []
    for s, b in scores:
        if all(abs(b - c) > 1.0 for _, c in out):
            out.append((s, b))
        if len(out) == 4:
            break
    return out


def track_end(full):
    """Last ms where the 50 ms energy is above -80 dBFS (keeps the natural decay)."""
    for i in range(len(full) - 50, 0, -10):
        if db(window(full, i, 50) / 50) > -80:
            return (i + 50) / 1000.0
    return len(full) / 1000.0


def main():
    a = sys.argv[1:]
    if not a or a[0].startswith("-"):
        sys.exit(__doc__)
    opt = lambda k: float(a[a.index(k) + 1]) if k in a else None
    low = ms_energy(decode(a[0], "lowpass=f=150,lowpass=f=150"))
    full = ms_energy(decode(a[0]))
    drops = find_drop(low, full)
    print("drop candidates (s, jump ratio):", ", ".join(f"{d:.3f} ({r:.1f}x)" for d, r in drops))
    drop = opt("--drop") or drops[0][0]
    tc = tempo(low, int(drop * 1000))
    print("tempo candidates (bpm, score):", ", ".join(f"{b:.2f} ({s:.2f})" for s, b in tc))
    bpm = opt("--bpm") or tc[0][1]
    bpb = int(opt("--beats-per-bar") or 4)
    beat = 60.0 / bpm
    bar = bpb * beat
    end = track_end(full)
    bars = int((end - drop) / bar + 1e-6)
    print(f"\nusing drop {drop:.3f}s, {bpm:.2f} bpm, {bpb}/4 -> beat {beat:.4f}s, bar {bar:.4f}s")
    print(f"track end {end:.3f}s -> {bars} whole bars after the drop (0-{bars - 1}), "
          f"tail after the last bar {end - (drop + bars * bar):.3f}s")
    marks = [drop - k * bar for k in range(1, 20) if drop - k * bar >= -0.05]
    print("intro bar marks (s):", ", ".join(f"{m:.2f}" for m in sorted(marks)))
    print("\nbar  start_s   low_dB  full_dB")
    ref_l = max(db(window(low, int((drop + i * bar) * 1000), int(bar * 1000)) / (bar * 1000)) for i in range(bars))
    ref_f = max(db(window(full, int((drop + i * bar) * 1000), int(bar * 1000)) / (bar * 1000)) for i in range(bars))
    for i in range(bars):
        s = int((drop + i * bar) * 1000)
        n = int(bar * 1000)
        l = db(window(low, s, n) / n) - ref_l
        f = db(window(full, s, n) / n) - ref_f
        flag = "  <- drop-out (outro?)" if l < -10 else "  <- lighter (break/variation?)" if l < -3 else ""
        print(f"{i:3d}  {drop + i * bar:7.3f}  {l:7.1f}  {f:7.1f}{flag}")


if __name__ == "__main__":
    main()
