#!/usr/bin/env python3
"""Build a demo video from recorded clips, a cut list (segments.tsv) and a music bed.

  python3 -I build.py <project.json> --plan         print the act/bar plan and warnings, build nothing
  python3 -I build.py <project.json> --tag v3       build <output>-v3.mp4 (+ -silent) and snapshot the inputs
  python3 -I build.py <project.json>                build <output>.mp4 (+ -silent), no snapshot

Everything project-specific lives in project.json and segments.tsv (see README.md next to this file).
Video: intro cards over the track's sparse intro, hard cut into the first clip on the drop, then story
acts (beats crossfade inside an act, hard cuts on bar lines between acts), then the end card over the
track's own outro. Music: the track is rebuilt bar by bar from `music_map` so each act starts on a
phrase start; every seam sits on a bar line with a 30 ms crossfade; loudness normalised.

Colour: agent-browser WebM is full-range BT.601. It is decoded explicitly as full range (otherwise
light greys like #fafafa crush to white) and encoded as limited-range BT.709 with matching tags.
"""
import json, math, os, re, shutil, subprocess, sys

HERE = os.path.dirname(os.path.realpath(__file__))
FFMPEG = shutil.which("ffmpeg") or "/opt/homebrew/bin/ffmpeg"

ENC_BASE = ["-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p", "-an",
            "-color_range", "tv", "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709"]
DECODE = "scale=in_range=full:in_color_matrix=bt601:out_range=full,format=rgb24"
TOYUV = ("scale=in_range=full:out_range=tv:out_color_matrix=bt709,format=yuv420p,"
         "setparams=range=tv:colorspace=bt709:color_primaries=bt709:color_trc=bt709")
W, H = 1440, 900
CARD_OUT = 0.25          # s: a card's text fades out this long before the next card's mark
READ_WPS, READ_PAD = 3.0, 1.5


# ---------------------------------------------------------------- config
class P:
    """Project config, resolved from project.json. Paths are relative to the project file."""

    def __init__(self, path):
        self.file = os.path.abspath(path)
        self.dir = os.path.dirname(self.file)
        with open(self.file) as f:
            c = json.load(f)
        rel = lambda p: os.path.normpath(os.path.join(self.dir, p)) if p else ""
        self.clips = rel(c.get("clips", "../clips"))
        self.segments = rel(c.get("segments", "segments.tsv"))
        self.output = rel(c["output"])
        self.work = rel(c.get("work", ".work"))
        self.brand = c.get("brand", {}).get("name", "")
        self.logo = rel(c.get("brand", {}).get("logo", ""))
        self.fps = int(c.get("fps", 30))
        self.xf = int(c.get("crossfade_frames", 10))
        lay = c.get("layout", {})
        self.head_y, self.sub_y = int(lay.get("head_y", 405)), int(lay.get("sub_y", 500))
        m = c["music"]
        self.music = rel(m["file"])
        self.bpm = float(m["bpm"])
        self.drop = float(m["drop"])
        self.track_end = float(m["end"])
        self.loudness = float(m.get("loudness", -18))
        self.beat = 60.0 / self.bpm
        self.bar = int(m.get("beats_per_bar", 4)) * self.beat
        self.drop_frame = math.ceil(self.drop * self.fps)          # first clip frame
        self.audio_delay = self.drop_frame / self.fps - self.drop  # puts the drop exactly on that frame
        self.fb = self.bar * self.fps                                # frames per bar
        self.track_bars = int((self.track_end - self.drop) / self.bar + 1e-6)
        self.acts = [(a["name"], a["beats"], int(a["bars"])) for a in c["acts"]]
        self.intro = [(float(k["at"]), [tuple(l) for l in k["layers"]]) for k in c.get("intro_cards", [])]
        end = c.get("end_card", {})
        self.end_bars = int(end.get("bars", 2))
        self.end_layers = [tuple(l) for l in end.get("layers", [["brand", "", 0.0]])]
        total_bars = sum(a[2] for a in self.acts) + self.end_bars
        mm = c.get("music_map")
        self.music_map = expand_map(mm) if mm else list(range(total_bars))
        if len(self.music_map) != total_bars:
            sys.exit(f"music_map has {len(self.music_map)} bars, acts + end card need {total_bars}")
        if max(self.music_map) >= self.track_bars:
            sys.exit(f"music_map uses bar {max(self.music_map)}, the track has bars 0-{self.track_bars - 1} after the drop")
        # Ending on the track's last bar lets its own decay play out; otherwise fade over one bar.
        self.outro_ending = self.music_map[-1] == self.track_bars - 1
        self.enc = ENC_BASE + ["-r", str(self.fps)]

    def bar_frame(self, v):
        """Frame where video bar v (0 = the drop) starts."""
        return round(self.drop_frame + v * self.fb)


def expand_map(mm):
    """[0, "8-15", 7] -> [0, 8, 9, ..., 15, 7]."""
    out = []
    for x in mm:
        if isinstance(x, str) and "-" in x:
            a, b = (int(v) for v in x.split("-"))
            out += list(range(a, b + 1))
        else:
            out.append(int(x))
    return out


# ---------------------------------------------------------------- helpers
def run(cmd):
    r = subprocess.run(cmd, stdin=subprocess.DEVNULL, capture_output=True, text=True)
    if r.returncode != 0:
        sys.stderr.write(" ".join(cmd) + "\n" + r.stderr)
        sys.exit(1)
    return r


def ff(*args):
    return run([FFMPEG, "-nostdin", "-v", "error", "-y", *args])


class Renderer:
    def __init__(self, p):
        self.bin = os.path.join(p.work, ".bin", "render")
        src = os.path.join(HERE, "render.swift")
        if not os.path.exists(self.bin) or os.path.getmtime(src) > os.path.getmtime(self.bin):
            os.makedirs(os.path.dirname(self.bin), exist_ok=True)
            run(["swiftc", "-O", src, "-o", self.bin])

    def __call__(self, *args):
        run([self.bin, *args])


# ---------------------------------------------------------------- segments
COLS = ["beat", "clip", "in", "out", "speed", "hold", "zoom", "cap_at", "pos", "caption", "lock"]


def load_segments(p, strict):
    segs = []
    with open(p.segments) as f:
        for n, line in enumerate(f, 1):
            line = line.rstrip("\n")
            if not line.strip() or line.startswith("#") or line.startswith("beat\t"):
                continue
            c = dict(zip(COLS, (line.split("\t") + [""] * len(COLS))[:len(COLS)]))
            if not os.path.exists(os.path.join(p.clips, c["clip"])):
                msg = f"segments.tsv:{n} {c['beat']}: missing clip {c['clip']}"
                if strict:
                    sys.exit(msg)
                print("warn", msg)
            s = dict(beat=c["beat"], clip=c["clip"], tin=float(c["in"]), tout=float(c["out"]),
                     speed=float(c["speed"] or 1), hold=float(c["hold"] or 0), zoom=c["zoom"].strip(),
                     cap_at=c["cap_at"].strip(), pos=c["pos"].strip(), caption=c["caption"].strip(),
                     lock=c["lock"].strip())
            if s["zoom"]:
                zoom_filter(s["zoom"], p.fps)                  # validate early
            s["base_frames"] = round((s["tout"] - s["tin"]) / s["speed"] * p.fps)
            s["hold_frames"] = round(s["hold"] * p.fps)
            segs.append(s)
    return segs


def zoom_filter(spec, fps):
    """'z0>z1@cx,cy@t0+dur' (eased punch-in) or 'z@cx,cy' (constant) -> zoompan on a 2x upscale.
    cx,cy are 1440x900 frame px; t0/dur are segment seconds."""
    m = re.fullmatch(r"([\d.]+)(?:>([\d.]+))?@([\d.]+),([\d.]+)(?:@([\d.]+)\+([\d.]+))?", spec)
    if not m:
        sys.exit(f"bad zoom spec {spec!r}")
    z0 = float(m.group(1)); z1 = float(m.group(2) or z0)
    cx, cy = float(m.group(3)), float(m.group(4))
    t0 = float(m.group(5) or 0); dur = float(m.group(6) or 1)
    q = f"min(1,max(0,((on/{fps})-{t0})/{dur}))"
    e = f"({q})*({q})*(3-2*({q}))"                    # smoothstep ease
    z = f"{z0}+({z1 - z0})*{e}"
    zmax = max(z0, z1)
    k = "1" if (z0 == z1) or zmax <= 1.0001 else f"((zoom-1)/{zmax - 1})"
    X = f"({W / 2}+({cx}-{W / 2})*{k})"              # centre drifts toward the target as zoom grows
    Y = f"({H / 2}+({cy}-{H / 2})*{k})"
    x = f"max(0,min(iw-iw/zoom,2*{X}-iw/zoom/2))"
    y = f"max(0,min(ih-ih/zoom,2*{Y}-ih/zoom/2))"
    return f"scale={2 * W}:{2 * H}:flags=lanczos,zoompan=z='{z}':x='{x}':y='{y}':d=1:s={W}x{H}:fps={fps}"


def encode_segment(p, render, s, idx):
    n = s["frames"]
    out = os.path.join(p.work, "seg", f"{idx:03d}-{s['beat']}.mp4")
    src = os.path.join(p.clips, s["clip"])
    pad = max(0, n - s["base_frames"]) / p.fps + 2
    # Scale to 1440x900 inside a pad so narrow clips (phone-width) are pillarboxed, not stretched.
    fit = (f"scale={W}:{H}:force_original_aspect_ratio=decrease,"
           f"pad={W}:{H}:(ow-iw)/2:(oh-ih)/2:color=0xf9f9f7")
    v = (f"[0:v]trim=start={s['tin']}:end={s['tout']},setpts=(PTS-STARTPTS)/{s['speed']},{DECODE},{fit},"
         f"fps={p.fps},tpad=stop_mode=clone:stop_duration={pad:.3f},trim=end_frame={n},setpts=PTS-STARTPTS")
    if s["zoom"]:
        v += "," + zoom_filter(s["zoom"], p.fps)
    v += "[v0]"
    args = ["-i", src]
    if s["caption"]:
        cap = os.path.join(p.work, "cap", f"{idx:03d}.png")
        render("caption", cap, s["caption"], s["pos"] or "bottom")
        args += ["-loop", "1", "-framerate", str(p.fps), "-t", f"{n / p.fps:.4f}", "-i", cap]
        c = ("[1:v]format=rgba[c]" if s["cap_at"] in ("", "=")
             else f"[1:v]format=rgba,fade=t=in:st={float(s['cap_at'])}:d=0.35:alpha=1[c]")
        fc = f"{v};{c};[v0][c]overlay=0:0:format=rgb:shortest=1,{TOYUV}[o]"
    else:
        fc = f"{v};[v0]{TOYUV}[o]"
    ff(*args, "-filter_complex", fc, "-map", "[o]", "-frames:v", str(n), *p.enc, out)
    return out


# ---------------------------------------------------------------- planning
def plan(p, segs):
    """Fit each act to its bar count: spread the slack over its beats' last segments, snap inner
    crossfade midpoints to the beat grid, let the act's last beat absorb the remainder exactly."""
    by_beat = {}
    for s in segs:
        by_beat.setdefault(s["beat"], []).append(s)
    unused = set(by_beat) - {b for a in p.acts for b in a[1]}
    if unused:
        print("warn: beats in segments.tsv but in no act:", ", ".join(sorted(unused)))
    acts, v = [], 0
    grid = p.beat * p.fps
    for name, beat_names, bars in p.acts:
        start, end = p.bar_frame(v), p.bar_frame(v + bars)
        missing = [b for b in beat_names if b not in by_beat]
        if missing:
            print(f"warn: act {name!r} lists beats with no segments: {', '.join(missing)}")
        beats = [dict(name=b, segs=by_beat[b]) for b in beat_names if b in by_beat]
        if not beats:
            sys.exit(f"act {name!r} has no segments")
        t = start
        for bi, b in enumerate(beats):
            for s in b["segs"]:
                s["frames"] = s["base_frames"] + s["hold_frames"]
                if s["lock"] == "bar":           # end exactly on the bar line nearest the natural end
                    vb = round((t + s["base_frames"] - p.drop_frame) / p.fb)
                    s["frames"] = p.bar_frame(vb) - t
                t += s["frames"]
            if bi < len(beats) - 1:
                t -= p.xf
        natural = t - start
        delta = (end - start) - natural
        share = delta / len(beats)
        t, carry = start, 0.0
        for bi, b in enumerate(beats):
            last = b["segs"][-1]
            frames = sum(s["frames"] for s in b["segs"])
            b["start"] = t
            if bi < len(beats) - 1:
                want = frames + share + carry
                mid = t + want - p.xf / 2
                k = round((mid - p.drop_frame) / grid)
                adj = round(p.drop_frame + k * grid + p.xf / 2 - t) - frames
                if last["frames"] + adj < 1:
                    adj = round(want - frames)
                carry = want - (frames + adj)
                t += frames + adj - p.xf
            else:
                adj = end - (t + frames)
                t = end
            if last["frames"] + adj < p.fps // 2:
                sys.exit(f"act {name!r}: {bars} bars is far too short for its beats (natural "
                         f"{natural / p.fps:.1f}s = {natural / p.fb:.1f} bars)")
            last["frames"] += adj
            b["adj"] = adj
            b["frames"] = sum(s["frames"] for s in b["segs"])
        acts.append(dict(name=name, beats=beats, bars=bars, v0=v, start=start, end=end,
                         natural=natural, delta=delta))
        v += bars
    end_start = p.bar_frame(v)
    tail = round((p.track_end - (p.drop + p.track_bars * p.bar)) * p.fps) if p.outro_ending else 0
    total = p.bar_frame(v + p.end_bars) + tail
    return acts, end_start, total


def caption_runs(acts, fps):
    """(caption, seconds on screen) for each run of segments showing the same caption."""
    runs = []
    for a in acts:
        for b in a["beats"]:
            for s in b["segs"]:
                if not s["caption"]:
                    continue
                on = s["frames"] / fps
                if s["cap_at"] not in ("", "="):
                    on -= float(s["cap_at"])
                if s["cap_at"] == "=" and runs and runs[-1][0] == s["caption"]:
                    runs[-1][1] += on
                else:
                    runs.append([s["caption"], on])
    return runs


def report(p, acts, end_start, total):
    fps = p.fps
    for a in acts:
        warn = ""
        if abs(a["delta"]) > p.fb:
            warn = f"  <- suggest {max(1, round(a['natural'] / p.fb))} bars"
        print(f"act {a['name'][:38]:38s} bars {a['v0']:3d}-{a['v0'] + a['bars'] - 1:3d} "
              f"start {a['start'] / fps:7.3f}s src bar {p.music_map[a['v0']]:2d}  natural {a['natural'] / fps:6.2f}s "
              f"-> {(a['end'] - a['start']) / fps:6.2f}s ({a['delta'] / fps:+.2f}s){warn}")
        for b in a["beats"]:
            print(f"     {b['name']:8s} start {b['start'] / fps:7.3f}s  adj {b['adj'] / fps:+.2f}s")
    print(f"end card {end_start / fps:.3f}s, total {total / fps:.3f}s"
          + ("" if p.outro_ending else "  (music_map does not end on the track's last bar: 1-bar fade out)"))
    for cap, secs in caption_runs(acts, fps):
        words = len(cap.split())
        need = words / READ_WPS + READ_PAD
        if words > 10:
            print(f"warn caption has {words} words, keep it short: {cap!r}")
        if secs < need:
            print(f"warn caption on screen {secs:.1f}s, needs ~{need:.1f}s: {cap!r}")


# ---------------------------------------------------------------- cards
def layer_png(p, render, kind, text, tag):
    out = os.path.join(p.work, f"layer-{tag}.png")
    if kind == "brand":
        render("layer", out, "brand", str(p.head_y), p.logo, text or p.brand)
    elif kind == "head":
        render("layer", out, "head", str(p.head_y), text)
    elif kind == "sub":
        render("layer", out, "sub", str(p.sub_y), text)
    else:
        sys.exit(f"unknown card layer kind {kind!r} (brand | head | sub)")
    return out


def card_video(p, render, layers, frames, t0, tag, fade_out=None):
    """Background + layers. Each layer fades in at its time with a 12 px upward drift; fade_out
    (card-local seconds) fades the text back to the background before the next card."""
    out = os.path.join(p.work, f"card-{tag}.mp4")
    bg = os.path.join(p.work, "layer-bg.png")
    if not os.path.exists(bg):
        render("layer", bg, "bg", "0")
    dur = f"{frames / p.fps:.4f}"
    args = ["-loop", "1", "-framerate", str(p.fps), "-t", dur, "-i", bg]
    fc, prev = ["[0:v]format=rgb24[b0]"], "b0"
    for i, (kind, text, at) in enumerate(layers, start=1):
        png = layer_png(p, render, kind, text, f"{tag}-{i}")
        args += ["-loop", "1", "-framerate", str(p.fps), "-t", dur, "-i", png]
        st = max(0.0, float(at) - t0)
        fo = f",fade=t=out:st={fade_out:.3f}:d={CARD_OUT}:alpha=1" if fade_out is not None else ""
        fc.append(f"[{i}:v]format=rgba,fade=t=in:st={st:.3f}:d=0.45:alpha=1{fo}[l{i}]")
        q = f"min(1,max(0,(t-{st:.3f})/0.5))"
        fc.append(f"[{prev}][l{i}]overlay=x=0:y='12*(1-({q})*(2-({q})))':format=rgb:eval=frame[b{i}]")
        prev = f"b{i}"
    fc.append(f"[{prev}]{TOYUV}[o]")
    ff(*args, "-filter_complex", ";".join(fc), "-map", "[o]", "-frames:v", str(frames), *p.enc, out)
    return out


def build_intro(p, render):
    """Sequential cards covering exactly the pre-drop frames, so the cut into the first clip lands on
    the drop. The last card stays fully on screen until that cut."""
    if not p.intro:
        sys.exit("intro_cards is empty: the intro must cover the track up to the drop")
    marks = [round(c[0] * p.fps) for c in p.intro] + [p.drop_frame]
    files = []
    for i, (t, layers) in enumerate(p.intro):
        a, b = marks[i], marks[i + 1]
        fo = (b - a) / p.fps - CARD_OUT if i < len(p.intro) - 1 else None
        files.append(card_video(p, render, layers, b - a, a / p.fps, f"intro{i + 1}", fade_out=fo))
    out = os.path.join(p.work, "intro.mp4")
    concat(p, files, p.drop_frame, out)
    return out, [(marks[i] / p.fps, marks[i + 1] / p.fps) for i in range(len(p.intro))]


def concat(p, files, frames, out, extra=()):
    args = []
    for f in files:
        args += ["-i", f]
    fc = "".join(f"[{i}:v]" for i in range(len(files))) + f"concat=n={len(files)}:v=1:a=0[v]"
    ff(*args, "-filter_complex", fc, "-map", "[v]", "-frames:v", str(frames), *p.enc, *extra, out)


# ---------------------------------------------------------------- music
def build_music(p, total_s, out_wav):
    """Concatenate source bars per music_map (track intro first); 30 ms crossfade centred on every
    jump, then gain to the target integrated loudness."""
    h = 0.015
    runs = []
    for b in p.music_map:
        if runs and runs[-1][1] == b - 1:
            runs[-1][1] = b
        else:
            runs.append([b, b])
    pieces = []
    for i, (a, b) in enumerate(runs):
        s = 0.0 if i == 0 else p.drop + a * p.bar - h
        e = p.track_end if i == len(runs) - 1 else p.drop + (b + 1) * p.bar + h
        pieces.append((s, e))
    seams, v = [], 0
    for i, (a, b) in enumerate(runs[:-1]):
        v += b - a + 1
        seams.append(dict(video_s=round(p.bar_frame(v) / p.fps, 3), video_bar=v, jump=f"{b}->{runs[i + 1][0]}"))
    inputs, fc = [], []
    for i, (a, b) in enumerate(pieces):
        inputs += ["-i", p.music]
        fc.append(f"[{i}:a]atrim=start={a:.6f}:end={b:.6f},asetpts=PTS-STARTPTS[p{i}]")
    prev = "p0"
    for i in range(1, len(pieces)):
        fc.append(f"[{prev}][p{i}]acrossfade=d={2 * h}:c1=tri:c2=tri[x{i}]")
        prev = f"x{i}"
    d = p.audio_delay * 1000
    fade = 0.25 if p.outro_ending else p.bar
    fc.append(f"[{prev}]adelay={d:.3f}|{d:.3f},atrim=end={total_s:.6f},"
              f"afade=t=out:st={total_s - fade:.4f}:d={fade:.4f}[bed]")
    raw = out_wav.replace(".wav", "-raw.wav")
    ff(*inputs, "-filter_complex", ";".join(fc), "-map", "[bed]", "-ar", "48000", "-c:a", "pcm_s16le", raw)
    r = subprocess.run([FFMPEG, "-nostdin", "-hide_banner", "-i", raw, "-af",
                        f"loudnorm=I={p.loudness}:TP=-1.5:LRA=11:print_format=json", "-f", "null", "-"],
                       capture_output=True, text=True)
    meas = json.loads(r.stderr[r.stderr.rfind("{"):r.stderr.rfind("}") + 1])
    gain = p.loudness - float(meas["input_i"])
    ff("-i", raw, "-af", f"volume={gain:.2f}dB", "-c:a", "pcm_s16le", out_wav)
    return dict(measured_i=float(meas["input_i"]), gain_db=round(gain, 2), seams=seams)


# ---------------------------------------------------------------- main
def main():
    argv = sys.argv[1:]
    if not argv or argv[0].startswith("-"):
        sys.exit(__doc__)
    p = P(argv[0])
    tag = argv[argv.index("--tag") + 1] if "--tag" in argv else ""
    dry = "--plan" in argv
    segs = load_segments(p, strict=not dry)
    acts, end_start, total = plan(p, segs)
    report(p, acts, end_start, total)
    if dry:
        return
    for path, what in ((p.music, "music file"), (p.logo, "logo")):
        if path and not os.path.exists(path):
            sys.exit(f"missing {what}: {path}")

    stem, ext = os.path.splitext(p.output)
    stem += f"-{tag}" if tag else ""
    out_music, out_silent = stem + (ext or ".mp4"), stem + "-silent" + (ext or ".mp4")
    if tag and os.path.exists(out_music):
        sys.exit(f"{out_music} exists; pick a new --tag so earlier versions are kept")

    if os.path.isdir(p.work):                      # fresh intermediates; keep the compiled renderer
        for x in os.listdir(p.work):
            if x != ".bin":
                y = os.path.join(p.work, x)
                shutil.rmtree(y) if os.path.isdir(y) else os.remove(y)
    for d in ("seg", "cap", "beat", "act"):
        os.makedirs(os.path.join(p.work, d), exist_ok=True)
    render = Renderer(p)
    intro, card_times = build_intro(p, render)
    end = card_video(p, render, p.end_layers, total - end_start, 0.0, "end")

    idx, act_files = 0, []
    for ai, a in enumerate(acts):
        beat_files = []
        for b in a["beats"]:
            files = []
            for s in b["segs"]:
                idx += 1
                files.append(encode_segment(p, render, s, idx))
            lst = os.path.join(p.work, "beat", f"{idx:03d}-{b['name']}.txt")
            with open(lst, "w") as f:
                f.writelines(f"file '{x}'\n" for x in files)
            bf = lst[:-4] + ".mp4"
            ff("-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", bf)
            beat_files.append((bf, b["frames"]))
        af = os.path.join(p.work, "act", f"act{ai + 1}.mp4")
        args, fc = [], []
        for x, _ in beat_files:
            args += ["-i", x]
        prev, acc = "[0:v]", beat_files[0][1]
        for j in range(1, len(beat_files)):
            fc.append(f"{prev}[{j}:v]xfade=transition=fade:duration={p.xf / p.fps:.4f}:"
                      f"offset={(acc - p.xf) / p.fps:.4f}[x{j}]")
            prev = f"[x{j}]"
            acc += beat_files[j][1] - p.xf
        if fc:
            ff(*args, "-filter_complex", ";".join(fc), "-map", prev,
               "-frames:v", str(a["end"] - a["start"]), *p.enc, af)
        else:
            shutil.copy(beat_files[0][0], af)
        act_files.append(af)

    concat(p, [intro] + act_files + [end], total, out_silent, extra=("-movflags", "+faststart"))
    wav = os.path.join(p.work, "music.wav")
    music = build_music(p, total / p.fps, wav)
    ff("-i", out_silent, "-i", wav, "-map", "0:v", "-map", "1:a", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k",
       "-shortest", "-movflags", "+faststart", out_music)

    timeline = os.path.join(p.dir, "timeline.tsv")
    with open(timeline, "w") as f:
        f.write("beat\tstart\tend\tcaption\tcaption_on\n")
        for i, (t0, t1) in enumerate(card_times):
            txt = " / ".join(x[1] or p.brand for x in p.intro[i][1])
            f.write(f"CARD{i + 1}\t{t0:.2f}\t{t1:.2f}\t{txt}\t{t0:.2f}\n")
        for a in acts:
            for b in a["beats"]:
                t = b["start"]
                for s in b["segs"]:
                    n = s["frames"]
                    con = "" if not s["caption"] else (
                        f"{t / p.fps:.2f}" if s["cap_at"] in ("", "=") else f"{t / p.fps + float(s['cap_at']):.2f}")
                    f.write(f"{b['name']}\t{t / p.fps:.2f}\t{(t + n) / p.fps:.2f}\t{s['caption']}\t{con}\n")
                    t += n
        end_txt = " / ".join(x[1] or p.brand for x in p.end_layers)
        f.write(f"END\t{end_start / p.fps:.2f}\t{total / p.fps:.2f}\t{end_txt}\t{end_start / p.fps:.2f}\n")

    info = dict(output=out_music, total_s=round(total / p.fps, 3), drop_frame=p.drop_frame,
                drop_track_s=p.drop, audio_delay_ms=round(p.audio_delay * 1000, 3), bpm=p.bpm,
                bar_s=p.bar, end_card_start_s=round(end_start / p.fps, 3), intro_cards=card_times, **music,
                acts=[dict(act=a["name"], start_s=round(a["start"] / p.fps, 3), first_video_bar=a["v0"],
                           bars=a["bars"], source_bar_at_start=p.music_map[a["v0"]]) for a in acts])
    with open(os.path.join(p.work, "build-info.json"), "w") as f:
        json.dump(info, f, indent=1)
    if tag:
        snap = os.path.join(p.dir, "versions", tag)
        os.makedirs(snap, exist_ok=True)
        for src in (p.file, p.segments, timeline, os.path.join(p.work, "build-info.json")):
            shutil.copy(src, snap)
    print(json.dumps({k: v for k, v in info.items() if k != "seams"}, indent=1))
    print("wrote", out_music, "and", out_silent)


if __name__ == "__main__":
    main()
