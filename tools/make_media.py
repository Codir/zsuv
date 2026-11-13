#!/usr/bin/env python3
"""Store-page media from the captured scenes (`./godot.sh capture` writes capture/trailer/):

  python tools/make_media.py [--src capture/trailer] [--out media] [--only trailer,shots,cover,gif]

  media/trailer/zsuv-trailer.mp4   1920x1080, 30 fps, H.264 + AAC (a generated wind bed)
  media/screenshots/NN-name.png           1920x1080
  media/cover.png                         630x500, the itch.io cover
  media/zsuv.gif                   480x270 loop for the itch page and the README

Everything is drawn at the game's own 480x270 and blown up with nearest-neighbour, so the
captions and the title are the same crisp pixels as the HUD, set in the game's font. The MP4 is
encoded by Blender's FFmpeg (tools/blender_encode.py). Needs Python 3 with Pillow and NumPy.
"""
import argparse
import os
import shutil
import subprocess
import sys
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(ROOT, "fonts", "Inconsolata-Variable.ttf")
FPS = 30
W, H = 480, 270
SCALE = 4
FADE = 12  # frames of dissolve between scenes
TRAILER_KBPS = 3500  # ~25 MB a minute

# scene, start (s), length (s), caption, caption from..to (s into the shot)
CUT = [
    ("01-valley", 0.0, 6.0, "A snowbound valley at dusk.", 1.4, 5.4),
    ("02-depot", 0.4, 4.0, "Load up at the depot.", 0.5, 3.7),
    ("03-road", 0.5, 5.0, "Follow the marker poles.", 0.8, 4.6),
    ("06-mud", 0.0, 5.6, "Mud? Engage 4x4. Lock the diff.", 0.4, 4.4),
    ("04-snow", 0.0, 4.3, "Deep snow fights every wheel.", 0.5, 4.0),
    ("05-ruts", 0.3, 3.4, "Every rut stays where you left it.", 0.3, 3.1),
    ("07-winch", 0.6, 6.0, "Stuck? Winch out.", 1.0, 5.6),
    ("08-map", 0.0, 3.6, "Read the paper map.", 0.4, 3.3),
    ("09-tower", 0.4, 5.6, "Drone batteries for the radio tower.", 0.6, 5.2),
    ("10-khutir", 0.0, 5.6, "Groceries for the lone khutir.", 0.8, 5.2),
    ("11-title", 0.0, 9.0, None, 0.0, 0.0),
]
# Where a caption sits (centre x, y), clear of the HUD's own lines; the rest sit at (240, 214).
CAPTION_AT = {"06-mud": (240, 196), "08-map": (372, 212)}

# scene, frame, file name
SHOTS = [
    ("01-valley", 205, "01-depot-at-dusk"),
    ("02-depot", 140, "02-loading-up"),
    ("03-road", 100, "03-marker-poles"),
    ("06-mud", 45, "04-mud-4x4-diff-lock"),
    ("04-snow", 90, "05-deep-snow"),
    ("07-winch", 100, "06-winch"),
    ("08-map", 30, "07-paper-map"),
    ("09-tower", 200, "08-radio-tower"),
    ("10-khutir", 175, "09-khutir"),
    ("11-title", 150, "10-valley-at-dusk"),
]

ORANGE = (240, 160, 40)
INK = (12, 12, 16)


def font(size, weight=700, width=100):
    f = ImageFont.truetype(FONT, size)
    f.set_variation_by_axes([weight, width])
    return f


def frames_of(src, scene):
    d = os.path.join(src, scene)
    return [os.path.join(d, f) for f in sorted(os.listdir(d)) if f.endswith(".png")]


def text_layer(lines, alpha, x=W // 2):
    """lines: [(text, font, y, colour, outline px)] centred on x; returns an RGBA 480x270 layer."""
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    if alpha <= 0:
        return layer
    d = ImageDraw.Draw(layer)
    d.fontmode = "1"  # no smoothing: hard pixels, like the HUD
    a = int(255 * alpha)
    for text, f, y, colour, outline in lines:
        for ox in range(-outline, outline + 1):
            for oy in range(-outline, outline + 1):
                if ox or oy:
                    d.text((x + ox, y + oy), text, font=f, fill=INK + (a,), anchor="mm")
        d.text((x + 1, y + outline + 1), text, font=f, fill=INK + (int(a * 0.8),), anchor="mm")
        d.text((x, y), text, font=f, fill=colour + (a,), anchor="mm")
    return layer


def caption(img, text, at, alpha):
    if not text or alpha <= 0:
        return img
    x, y = at
    f = font(13, 700)
    band = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    tw = ImageDraw.Draw(band).textlength(text, font=f)
    ImageDraw.Draw(band).rectangle([x - tw / 2 - 8, y - 9, x + tw / 2 + 8, y + 8], fill=(0, 0, 0, int(90 * alpha)))
    img = Image.alpha_composite(img.convert("RGBA"), band)
    return Image.alpha_composite(img, text_layer([(text, f, y, (242, 240, 230), 1)], alpha, x)).convert("RGB")


def title_card(img, t):
    """The end card over the last shot: title, line, where to find it."""
    def fade(t0):
        return min(1.0, max(0.0, (t - t0) / 0.6))
    lines = []
    if fade(1.8) > 0:
        img = Image.alpha_composite(img.convert("RGBA"), text_layer([("KHUTIR ROAD", font(44, 900, 112), 104, ORANGE, 2)], fade(1.8))).convert("RGB")
    if fade(3.2) > 0:
        lines.append(("a PSX winter delivery drive", font(13, 600), 140, (242, 240, 230), 1))
    img = Image.alpha_composite(img.convert("RGBA"), text_layer(lines, fade(3.2))).convert("RGB")
    if fade(4.6) > 0:
        img = Image.alpha_composite(img.convert("RGBA"), text_layer([("on itch.io", font(12, 700), 232, (255, 214, 90), 1)], fade(4.6))).convert("RGB")
    return img


def up(img):
    return img.resize((W * SCALE, H * SCALE), Image.NEAREST)


def make_trailer(src, out, blender):
    work = os.path.join(ROOT, "capture", "cut")
    shutil.rmtree(work, ignore_errors=True)
    os.makedirs(work)
    segs = []
    for scene, start, length, text, c0, c1 in CUT:
        fs = frames_of(src, scene)
        a = int(round(start * FPS))
        n = int(round(length * FPS))
        if len(fs) < a + n:
            print(f"  {scene}: {len(fs)} frames, wanted {a + n}; using what there is")
        segs.append((scene, fs[a:a + n], text, c0, c1))

    def render(si, i):
        scene, fs, text, c0, c1 = segs[si]
        img = Image.open(fs[i]).convert("RGB")
        t = i / FPS
        if text:
            img = caption(img, text, CAPTION_AT.get(scene, (W // 2, 214)), min(1.0, max(0.0, (t - c0) / 0.4), max(0.0, (c1 - t) / 0.4)))
        if scene == "11-title":
            img = title_card(img, t)
        return img

    starts, at = [], 0
    for _, fs, *_ in segs:
        starts.append(at)
        at += len(fs) - FADE
    total = at + FADE
    black = Image.new("RGB", (W, H), (0, 0, 0))
    for k in range(total):
        on = [(si, k - starts[si]) for si in range(len(segs)) if 0 <= k - starts[si] < len(segs[si][1])]
        img = render(*on[0])
        if len(on) > 1:
            img = Image.blend(img, render(*on[1]), (on[1][1] + 1) / (FADE + 1))
        if k < 18:
            img = Image.blend(black, img, k / 18)
        if k >= total - 30:
            img = Image.blend(img, black, (k - (total - 30) + 1) / 30)
        up(img).save(os.path.join(work, f"{k:05d}.jpg"), quality=95)
    seconds = total / FPS
    print(f"trailer: {total} frames, {seconds:.1f} s")
    wav = os.path.join(work, "wind.wav")
    write_wind(wav, seconds)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    subprocess.run([blender, "-b", "--factory-startup", "-P", os.path.join(ROOT, "tools", "blender_encode.py"), "--",
                    work, out, str(FPS), str(TRAILER_KBPS), wav], check=True, stdout=subprocess.DEVNULL)
    print("  ->", out, f"{os.path.getsize(out) / 1e6:.1f} MB")


def shaped_noise(n, rate, shape, rng):
    """White noise coloured in the frequency domain by shape(freqs)."""
    spec = np.fft.rfft(rng.standard_normal(n))
    spec *= shape(np.fft.rfftfreq(n, 1.0 / rate))
    x = np.fft.irfft(spec, n)
    return x / (np.abs(x).max() + 1e-9)


def write_wind(path, seconds, rate=48000):
    """A cold wind: a low rumble, a hiss and a faint whistle, all breathing with slow gusts."""
    n = int(seconds * rate)
    t = np.arange(n) / rate
    rng = np.random.default_rng(7)
    out = []
    for ch in range(2):
        gust = 0.55 + 0.45 * np.clip(sum(np.sin(2 * np.pi * f * t + rng.uniform(0, 6.3)) / (i + 1)
                                         for i, f in enumerate([0.07, 0.13, 0.23, 0.41])) * 0.6, -1, 1)
        rumble = shaped_noise(n, rate, lambda f: 1.0 / (1.0 + (f / 180.0) ** 2) / np.sqrt(np.maximum(f, 20.0)), rng)
        hiss = shaped_noise(n, rate, lambda f: np.exp(-((f - 2500.0) / 1800.0) ** 2), rng)
        whistle = shaped_noise(n, rate, lambda f: np.exp(-((f - 520.0) / 60.0) ** 2), rng)
        x = rumble * 0.55 * gust + hiss * 0.12 * gust ** 2 + whistle * 0.10 * np.clip(gust - 0.6, 0, 1) * 2.5
        out.append(x)
    x = np.stack(out, axis=1)
    x[:, 0], x[:, 1] = 0.75 * x[:, 0] + 0.25 * x[:, 1], 0.25 * x[:, 0] + 0.75 * x[:, 1]
    env = np.minimum(1.0, t / 1.5) * np.minimum(1.0, (seconds - t) / 2.5)
    x *= env[:, None]
    x *= 0.6 / (np.abs(x).max() + 1e-9)  # peaks at -4.4 dBFS: a bed, not a soundtrack
    pcm = (x * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(pcm.tobytes())


def make_shots(src, out):
    os.makedirs(out, exist_ok=True)
    for scene, frame, name in SHOTS:
        fs = frames_of(src, scene)
        img = Image.open(fs[min(frame, len(fs) - 1)]).convert("RGB")
        up(img).save(os.path.join(out, name + ".png"), optimize=True)
    print(f"screenshots: {len(SHOTS)} -> {out}")


def make_cover(src, out, scene="10-khutir", frame=175, x0=96):
    """itch.io cover, 630x500: a 315x250 window of a frame, doubled, the title over the sky."""
    img = Image.open(frames_of(src, scene)[frame]).convert("RGB").crop((x0, 20, x0 + 315, 270))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.fontmode = "1"
    for text, f, y, colour, o in [("KHUTIR", font(40, 900, 112), 30, ORANGE, 2), ("ROAD", font(40, 900, 112), 66, ORANGE, 2)]:
        for ox in range(-o, o + 1):
            for oy in range(-o, o + 1):
                if ox or oy:
                    d.text((157 + ox, y + oy), text, font=f, fill=INK + (255,), anchor="mm")
        d.text((158, y + o + 1), text, font=f, fill=INK + (200,), anchor="mm")
        d.text((157, y), text, font=f, fill=colour + (255,), anchor="mm")
    img = Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")
    img.resize((630, 500), Image.NEAREST).save(out, optimize=True)
    print("cover ->", out)


def make_gif(src, out):
    """A short loop: the road, the deep snow, the winch."""
    picks = [("03-road", 30, 2.2), ("04-snow", 20, 2.0), ("07-winch", 40, 2.2)]
    frames = []
    for scene, a, secs in picks:
        fs = frames_of(src, scene)
        frames += [Image.open(f).convert("RGB") for f in fs[a:a + int(secs * FPS):2]]  # 15 fps
    pal = [f.quantize(colors=64, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE) for f in frames]
    # GIF delays are whole centiseconds: 70, 70, 60 averages the 66.7 ms of 15 fps.
    durations = [60 if i % 3 == 2 else 70 for i in range(len(pal))]
    pal[0].save(out, save_all=True, append_images=pal[1:], duration=durations, loop=0, optimize=True, disposal=1)
    print("gif ->", out, f"{os.path.getsize(out) / 1e6:.1f} MB")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=os.path.join(ROOT, "capture", "trailer"))
    ap.add_argument("--out", default=os.path.join(ROOT, "media"))
    ap.add_argument("--only", default="trailer,shots,cover,gif")
    ap.add_argument("--blender", default=r"C:\Program Files\Blender Foundation\Blender 4.5\blender.exe")
    a = ap.parse_args()
    only = a.only.split(",")
    if "shots" in only:
        make_shots(a.src, os.path.join(a.out, "screenshots"))
    if "cover" in only:
        make_cover(a.src, os.path.join(a.out, "cover.png"))
    if "gif" in only:
        make_gif(a.src, os.path.join(a.out, "zsuv.gif"))
    if "trailer" in only:
        make_trailer(a.src, os.path.join(a.out, "trailer", "zsuv-trailer.mp4"), a.blender)


if __name__ == "__main__":
    sys.exit(main())
