"""A placeholder incoming-shell whistle (sounds/malak/shell_whistle.ogg) until a real one exists: a falling sine sweep
with a slight warble, a breath of filtered noise round it, louder towards the end, a short fade. Needs ffmpeg + numpy.

    python tools/audio/make_whistle.py sounds/malak/shell_whistle.ogg [--length 0.8]
"""
import argparse
import subprocess
import numpy as np

SR = 48000


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--length", type=float, default=0.8)
    a = ap.parse_args()
    n = int(a.length * SR)
    t = np.arange(n) / SR
    u = t / a.length
    # the pitch falls from ~2600 Hz to ~700 Hz, faster at the end (the shell gets close), with a little warble
    freq = 2600 * (700 / 2600) ** (u ** 1.4) * (1 + 0.012 * np.sin(2 * np.pi * 23 * t))
    phase = 2 * np.pi * np.cumsum(freq) / SR
    tone = np.sin(phase) + 0.25 * np.sin(2 * phase)
    # air: white noise, crudely band-limited round the tone by a moving average
    rng = np.random.default_rng(7)
    noise = rng.standard_normal(n)
    noise = np.convolve(noise, np.ones(6) / 6, mode="same")
    env = (0.25 + 0.75 * u ** 1.6) * np.minimum(1, (1 - u) / 0.06) * np.minimum(1, u / 0.02)
    x = (tone * 0.8 + noise * 0.18) * env
    x = x / np.max(np.abs(x)) * 10 ** (-1 / 20)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f64le", "-ar", str(SR), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "6", a.out], input=x.astype(np.float64).tobytes(), check=True)
    print("wrote", a.out, a.length, "s")


if __name__ == "__main__":
    main()
