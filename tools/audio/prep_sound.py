"""Prepares a sound file for the game (see sounds/README.md). Needs ffmpeg and numpy.

  Loop (seamless, mono, peak -1 dB):
    python tools/audio/prep_sound.py loop <in> <out.ogg> [--length 4] [--start auto] [--xfade 0.5] [--stereo]
  One-shot (trim the silence at the start, mono, peak -1 dB, optional max length with a short fade-out):
    python tools/audio/prep_sound.py shot <in> <out.ogg> [--max 2] [--fade 0.15] [--start 0] [--stereo]
  Info (channels, length, levels, loudness every 0.5 s):
    python tools/audio/prep_sound.py info <in>

Loops: picks the steadiest stretch of the file (or --start seconds), cuts --length seconds and crossfades the end into the
start (equal-power, --xfade seconds), so it loops without a click. Keep the original in sounds/_source.
"""
import argparse
import subprocess
import numpy as np

SR = 48000


def load(path, channels):
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", path, "-f", "f32le", "-ac", str(channels), "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, channels).astype(np.float64)


def save(path, x):
    ch = x.shape[1]
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f64le", "-ar", str(SR), "-ac", str(ch), "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "6", path], input=np.ascontiguousarray(x).tobytes(), check=True)


def db(v):
    return 20 * np.log10(max(v, 1e-9))


def rms_windows(m, w=0.5):
    n = int(w * SR)
    return np.array([np.sqrt((m[i:i + n] ** 2).mean()) for i in range(0, len(m) - n, n)])


def normalize(x, peak_db=-1.0):
    return x * (10 ** (peak_db / 20) / max(np.abs(x).max(), 1e-9))


def info(args):
    x = load(args.input, 2)
    m = x.mean(axis=1)
    print("length %.2f s, L/R correlation %.3f (near 1 = really mono, near 0 = wide, below 0 = careful)" % (
        len(x) / SR, np.corrcoef(x[:, 0], x[:, 1])[0, 1]))
    print("peak %.1f dB, rms %.1f dB" % (db(np.abs(x).max()), db(np.sqrt((x ** 2).mean()))))
    print("loudness every 0.5 s:", " ".join("%.0f" % db(r) for r in rms_windows(m)))


def loop(args):
    x = load(args.input, 2 if args.stereo else 1)
    n, f = int(args.length * SR), int(args.xfade * SR)
    if len(x) < n + f:
        raise SystemExit("file is shorter than length + xfade")
    if args.start == "auto":
        # the steadiest stretch: lowest loudness spread over the window, away from fades at the ends
        r = rms_windows(x.mean(axis=1))
        k = int((args.length + args.xfade) / 0.5) + 1
        best, start = None, 0
        for i in range(1, len(r) - k - 1):
            spread = np.std(db_arr(r[i:i + k]))
            if best is None or spread < best:
                best, start = spread, i * 0.5
    else:
        start = float(args.start)
    a = int(start * SR)
    seg = x[a:a + n + f]
    t = np.linspace(0, np.pi / 2, f)[:, None]
    out = seg[:n].copy()
    out[:f] = seg[:f] * np.sin(t) + seg[n:n + f] * np.cos(t)
    out = normalize(out)
    save(args.output, out)
    print("loop from %.2f s, %.2f s long, seam jump %.4f (typical step %.4f)" % (
        start, args.length, np.abs(out[0] - out[-1]).max(), np.abs(np.diff(out, axis=0)).mean()))


def db_arr(r):
    return 20 * np.log10(np.maximum(r, 1e-9))


def shot(args):
    x = load(args.input, 2 if args.stereo else 1)
    if args.start:
        x = x[int(args.start * SR):]
    level = np.abs(x).max(axis=1)
    above = np.nonzero(level > np.abs(x).max() * 10 ** (-40 / 20))[0]
    a = max(0, above[0] - int(0.005 * SR)) if len(above) else 0
    x = x[a:]
    if args.max and len(x) > args.max * SR:
        x = x[:int(args.max * SR)].copy()
        f = int(args.fade * SR)
        x[-f:] *= np.linspace(1, 0, f)[:, None]
    save(args.output, normalize(x))
    print("trimmed %.3f s at the start, %.2f s long" % (a / SR, len(x) / SR))


p = argparse.ArgumentParser()
sub = p.add_subparsers(dest="cmd", required=True)
pi = sub.add_parser("info")
pi.add_argument("input")
pl = sub.add_parser("loop")
pl.add_argument("input")
pl.add_argument("output")
pl.add_argument("--length", type=float, default=4.0)
pl.add_argument("--start", default="auto")
pl.add_argument("--xfade", type=float, default=0.5)
pl.add_argument("--stereo", action="store_true")
ps = sub.add_parser("shot")
ps.add_argument("input")
ps.add_argument("output")
ps.add_argument("--max", type=float, default=0)
ps.add_argument("--fade", type=float, default=0.15)
ps.add_argument("--start", type=float, default=0)
ps.add_argument("--stereo", action="store_true")
a = p.parse_args()
{"info": info, "loop": loop, "shot": shot}[a.cmd](a)
