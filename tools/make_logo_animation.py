#!/usr/bin/env python3
"""Renders the animated logo for the README (docs/logo-animated*.webp) from the three layers in
common/icons/logo-{hand,arcs,word}.png, with the same timing as common/widgets/AnimatedLogo.qml.
Run from the repo root: python3 tools/make_logo_animation.py"""
import math

import numpy as np
from PIL import Image

W, H = 360, 327
SS = 2  # supersampling for smooth rotation
WRIST = (165, 172)
FPS = 24
# (hand angle, arcs opacity), 260 ms each, as in AnimatedLogo.qml
SWINGS = [(16, 1.0), (-9, 0.7), (13, 1.0), (-6, 0.6), (8, 0.8), (0, 0.4)]
START, SWING_MS, HOLD, OUT = 450, 260, 2200, 350
TAIL = 600  # transparent, before the loop restarts


def out_cubic(t):
    return 1 - (1 - t) ** 3


def inout_sine(t):
    return -(math.cos(math.pi * t) - 1) / 2


def clamp(t):
    return max(0.0, min(1.0, t))


def wave_state(t):
    """Hand angle, arcs opacity and arcs push at time t (ms)."""
    angle, opacity, push = 0.0, 0.0, 0.0
    for i, (a, flash) in enumerate(SWINGS):
        t0 = START + i * SWING_MS
        if t < t0:
            break
        p = clamp((t - t0) / SWING_MS)
        target_push = 8 if a > 0 else 0
        if p < 1:
            return (angle + (a - angle) * inout_sine(p),
                    opacity + (flash - opacity) * out_cubic(p),
                    push + (target_push - push) * out_cubic(p))
        angle, opacity, push = a, flash, target_push
    return angle, opacity, push


def load(name, invert):
    im = Image.open(f"common/icons/logo-{name}.png").convert("RGBA")
    if invert:  # the layers are light-on-dark; this makes the dark-on-light version
        a = np.asarray(im).astype(int)
        neutral = (a[..., :3].max(axis=2) - a[..., :3].min(axis=2)) < 40
        a[..., :3][neutral] = 255 - a[..., :3][neutral]
        im = Image.fromarray(a.astype("uint8"), "RGBA")
    return im.resize((W * SS, H * SS), Image.LANCZOS)


def with_opacity(im, o):
    a = np.asarray(im).copy()
    a[..., 3] = (a[..., 3] * clamp(o)).astype("uint8")
    return Image.fromarray(a, "RGBA")


def frame(layers, t, fade=1.0):
    hand, arcs, word = layers
    canvas = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    word_y = 14 * (1 - out_cubic(clamp(t / 700))) * SS
    canvas.alpha_composite(with_opacity(word, out_cubic(clamp(t / 600))), (0, int(round(word_y))))
    angle, arcs_opacity, push = wave_state(t)
    rotated = hand.rotate(-angle, resample=Image.BICUBIC, center=(WRIST[0] * SS, WRIST[1] * SS))
    canvas.alpha_composite(with_opacity(rotated, out_cubic(clamp(t / 500))))
    canvas.alpha_composite(with_opacity(arcs, arcs_opacity), (int(round(push * SS)), 0))
    if fade < 1:
        canvas = with_opacity(canvas, fade)
    return canvas.resize((W, H), Image.LANCZOS)


def render(path, invert):
    layers = [load(n, invert) for n in ("hand", "arcs", "word")]
    waving_end = START + len(SWINGS) * SWING_MS
    step = 1000 / FPS
    frames, durations = [], []
    t = 0.0
    while t < waving_end:
        frames.append(frame(layers, t))
        durations.append(round(step))
        t += step
    frames.append(frame(layers, waving_end))  # the pause: one frame, held
    durations.append(HOLD)
    for i in range(1, int(OUT / step) + 1):
        frames.append(frame(layers, waving_end, 1 - i * step / OUT))
        durations.append(round(step))
    frames.append(Image.new("RGBA", (W, H), (0, 0, 0, 0)))
    durations.append(TAIL)
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=durations, loop=0,
                   quality=75, alpha_quality=80, method=6)
    print(path, len(frames), "frames")


render("docs/logo-animated-dark.webp", invert=False)  # for dark backgrounds
render("docs/logo-animated.webp", invert=True)  # for light backgrounds
