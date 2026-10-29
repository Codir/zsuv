#!/usr/bin/env python3
"""The game's sounds, cut from the CC0 recordings in sounds/source/ (docs/sound.md names them):

  python tools/make_sounds.py [--preview DIR]

  sounds/engine_idle.ogg      a 3.4 s loop of the diesel idle (BigSoundBank 1145), pitch 1 = 800 rpm
  sounds/engine_labour.ogg    the same cut driven into soft clipping, low mids up: the engine under load
  sounds/winch.ogg            a 3.5 s loop of the winch motor (BigSoundBank 0708)
  sounds/snow_NN.ogg          8 crunches cut from footsteps in snow (BigSoundBank 2890)
  sounds/mud_NN.ogg           16 squelches (rubberduck's 25 CC0 mud sfx), 0.12-0.4 s of them

Everything is 22,050 Hz mono OGG Vorbis, as a PSX would have it. A loop ends where its start
begins: the cut is placed where the waveform repeats best, and its last stretch is crossfaded
into the recording just before it. The two engine loops are one cut, sample for sample, so played
together at one pitch they never drift apart. Hits are levelled to one loudness; the game sets
how loud each one plays. --preview also writes each loop played four times over as a WAV, to
listen for the seam. Needs Python 3 with NumPy, SciPy and soundfile.
"""
import argparse
import glob
import os

import numpy as np
import soundfile as sf
from numpy.lib.stride_tricks import sliding_window_view
from scipy.signal import butter, resample_poly, sosfilt

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "sounds", "source")
OUT = os.path.join(ROOT, "sounds")
SR = 22050
QUALITY = 0.6  # Vorbis, 0..1

# recording, where to look for the loop (s), its length range (s), crossfade (s), linear fade?
ENGINE = ("bsb-1145-truck-engine.ogg", (20.0, 32.5), (3.0, 4.5), 0.08, True)
WINCH = ("bsb-0708-little-electric-winch.ogg", (15.0, 25.0), (3.0, 4.5), 0.25, False)
SNOW = "bsb-2890-footstep-in-the-snow-2.ogg"
SNOW_HITS = 8
SNOW_LEN = 0.35
MUD_LEN = (0.12, 0.4)  # seconds of squelch kept, of 0.08-0.53 s in the set

LOOP_RMS_DB = -16.0
HIT_RMS_DB = -16.0
PEAK_DB = -1.0


def load(name: str) -> np.ndarray:
    x, sr = sf.read(os.path.join(SRC, name), always_2d=True)
    assert sr == 48000, f"{name}: {sr} Hz"
    return resample_poly(x.mean(axis=1), 147, 320)  # 48 kHz -> 22.05 kHz


def db(x: np.ndarray) -> float:
    return 20.0 * np.log10(np.sqrt(np.mean(x * x)) + 1e-12)


def level(x: np.ndarray, rms_db: float) -> np.ndarray:
    """To rms_db, but with no peak above PEAK_DB."""
    gain = 10.0 ** ((rms_db - db(x)) / 20.0)
    gain = min(gain, 10.0 ** (PEAK_DB / 20.0) / (np.abs(x).max() + 1e-12))
    return x * gain


def envelope_db(x: np.ndarray, hop: float = 0.01) -> np.ndarray:
    n = int(SR * hop)
    k = len(x) // n
    return 20.0 * np.log10(np.sqrt((x[: k * n].reshape(k, n) ** 2).mean(axis=1)) + 1e-12)


def find_loop(x: np.ndarray, where, lengths, window: float = 0.08):
    """The start and length whose seam matches best: the stretch just past the loop's end
    correlates with its start, so the crossfade joins like with like."""
    f = int(window * SR)
    lo, hi = int(lengths[0] * SR), int(lengths[1] * SR)
    best = (-2.0, 0, 0)
    for start in np.arange(where[0], where[1] - lengths[1], 0.25):
        s = int(start * SR)
        w = x[s : s + f]
        v = sliding_window_view(x[s + lo : s + hi + f], f)
        c = v @ w / np.sqrt((v * v).sum(axis=1) * (w @ w) + 1e-12)
        i = int(c.argmax())
        if c[i] > best[0]:
            best = (float(c[i]), s, lo + i)
    return best


def make_loop(x: np.ndarray, start: int, length: int, fade: float, linear: bool) -> np.ndarray:
    """x[start : start+length], its first `fade` crossfaded with what follows its end, so the
    last sample runs on into the first."""
    f = int(fade * SR)
    t = np.linspace(0.0, 1.0, f, endpoint=False)
    fade_in, fade_out = (t, 1.0 - t) if linear else (np.sin(t * np.pi / 2), np.cos(t * np.pi / 2))
    y = x[start : start + length].copy()
    y[:f] = x[start : start + f] * fade_in + x[start + length : start + length + f] * fade_out
    return y


def labour(loop: np.ndarray) -> np.ndarray:
    """The engine under load: low mids up, driven into soft clipping, the fizz taken off.
    Filtered three times over and the middle kept, so the filters run on across the seam."""
    x = np.tile(loop, 3)
    lows = sosfilt(butter(2, [90.0, 400.0], "bandpass", fs=SR, output="sos"), x)
    y = x + lows * 1.5
    y = np.tanh(y / np.abs(y).max() * 4.0)
    y = sosfilt(butter(2, 4500.0, "lowpass", fs=SR, output="sos"), y)
    return y[len(loop) : 2 * len(loop)]


def snow_hits(x: np.ndarray) -> list:
    """The strongest SNOW_HITS footfalls with none closer than 0.9 s on either side, each from
    10 ms before its onset to SNOW_LEN, faded out."""
    x = sosfilt(butter(2, 120.0, "highpass", fs=SR, output="sos"), x)
    e = envelope_db(x)
    floor = np.percentile(e, 20)
    onsets = [i for i in range(1, len(e)) if e[i] > floor + 15 >= e[i - 1]]
    onsets = [i for j, i in enumerate(onsets) if j == 0 or i - onsets[j - 1] > 60]
    alone = [i for j, i in enumerate(onsets)
             if (j == 0 or i - onsets[j - 1] > 90) and (j == len(onsets) - 1 or onsets[j + 1] - i > 90)]
    alone.sort(key=lambda i: -e[i : i + 30].max())
    hits = []
    n = int(SNOW_LEN * SR)
    fade = np.linspace(1.0, 0.0, n) ** 2
    for i in sorted(alone[:SNOW_HITS]):
        s = max(i * int(0.01 * SR) - int(0.01 * SR), 0)
        hits.append(level(x[s : s + n] * fade, HIT_RMS_DB))
    return hits


def mud_hits() -> list:
    """The squelches whose sound lasts MUD_LEN, trimmed to it and faded out."""
    hits = []
    for p in sorted(glob.glob(os.path.join(SRC, "mud", "mud_*.ogg"))):
        x = load(os.path.relpath(p, SRC))
        e = envelope_db(x)
        on = np.where(e > e.max() - 30.0)[0]
        a, b = on.min() * int(0.01 * SR), (on.max() + 1) * int(0.01 * SR)
        if not MUD_LEN[0] <= (b - a) / SR <= MUD_LEN[1]:
            continue
        y = x[a : b + int(0.03 * SR)].copy()
        tail = int(0.03 * SR)
        y[-tail:] *= np.linspace(1.0, 0.0, tail)
        hits.append(level(y, HIT_RMS_DB))
    return hits


def write(name: str, y: np.ndarray) -> None:
    path = os.path.join(OUT, name)
    sf.write(path, y.astype(np.float32), SR, format="OGG", subtype="VORBIS", compression_level=1.0 - QUALITY)
    print(f"{name:20s} {len(y) / SR:5.2f} s  {db(y):6.1f} dB RMS  {os.path.getsize(path) // 1024:4d} KB")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--preview", help="also write each loop four times over as a WAV here")
    args = ap.parse_args()
    for old in glob.glob(os.path.join(OUT, "*.ogg")):
        os.remove(old)

    loops = {}
    for out, (name, where, lengths, fade, linear) in (("engine_idle", ENGINE), ("winch", WINCH)):
        x = load(name)
        c, start, length = find_loop(x, where, lengths)
        print(f"{out}: {start / SR:.2f} s + {length / SR:.3f} s, seam correlation {c:.3f}")
        loops[out] = make_loop(x, start, length, fade, linear)
    loops["engine_labour"] = labour(loops["engine_idle"])
    for out in ("engine_idle", "engine_labour", "winch"):
        y = level(loops[out], LOOP_RMS_DB)
        write(out + ".ogg", y)
        if args.preview:
            os.makedirs(args.preview, exist_ok=True)
            sf.write(os.path.join(args.preview, out + "_x4.wav"), np.tile(y, 4), SR)

    for i, y in enumerate(snow_hits(load(SNOW))):
        write(f"snow_{i + 1:02d}.ogg", y)
    for i, y in enumerate(mud_hits()):
        write(f"mud_{i + 1:02d}.ogg", y)


if __name__ == "__main__":
    main()
