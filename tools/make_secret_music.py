#!/usr/bin/env python3
"""Synthesizes the two loops behind the easter eggs (Settings > About): sounds/secret/nyan.ogg
and sounds/secret/disco.ogg. Both tunes are original; nothing is sampled. Needs numpy and ffmpeg.

    python3 tools/make_secret_music.py
"""
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

RATE = 32000
OUT = Path(__file__).resolve().parent.parent / "sounds" / "secret"


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def tone(kind, freq, dur, vol=1.0, decay=6.0):
    t = np.arange(int(dur * RATE)) / RATE
    ph = (freq * t) % 1.0
    if kind == "square":
        w = np.where(ph < 0.5, 1.0, -1.0)
    elif kind == "pulse":
        w = np.where(ph < 0.25, 1.0, -1.0)
    elif kind == "saw":
        w = 2 * ph - 1
    elif kind == "tri":
        w = 4 * np.abs(ph - 0.5) - 1
    else:
        w = np.sin(2 * np.pi * ph)
    attack = np.minimum(1, t / 0.004)
    return w * attack * np.exp(-decay * t) * vol


def noise(dur, vol=1.0, decay=40.0):
    t = np.arange(int(dur * RATE)) / RATE
    return np.random.default_rng(1).uniform(-1, 1, t.size) * np.exp(-decay * t) * vol


def kick(vol=1.0):
    t = np.arange(int(0.22 * RATE)) / RATE
    f = 140 * np.exp(-t * 22) + 45
    return np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t * 14) * vol


class Track:
    def __init__(self, seconds):
        self.buf = np.zeros(int(seconds * RATE) + RATE)

    def add(self, at, sig):
        i = int(at * RATE)
        self.buf[i:i + sig.size] += sig[:self.buf.size - i]

    def save(self, seconds, name):
        out = self.buf[:int(seconds * RATE)]
        out = out / max(1e-9, np.abs(out).max()) * 0.8
        with tempfile.TemporaryDirectory() as d:
            wav = Path(d) / "x.wav"
            with wave.open(str(wav), "wb") as w:
                w.setnchannels(1)
                w.setsampwidth(2)
                w.setframerate(RATE)
                w.writeframes((out * 32767).astype("<i2").tobytes())
            OUT.mkdir(parents=True, exist_ok=True)
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "3", str(OUT / name)], check=True)


def nyan():
    bpm, bars = 150, 8
    step = 60 / bpm / 2  # an eighth
    total = bars * 8 * step
    tr = Track(total)
    lead = [
        84, 86, 88, 86, 84, 81, 79, 81,
        84, 86, 88, 86, 84, 81, 79, 0,
        88, 91, 88, 86, 84, 86, 84, 81,
        79, 81, 84, 81, 79, 76, 79, 0,
        88, 88, 86, 84, 86, 86, 84, 81,
        79, 81, 84, 86, 88, 86, 84, 0,
        91, 88, 86, 88, 84, 86, 81, 84,
        79, 81, 79, 76, 72, 76, 79, 84,
    ]
    roots = [48, 45, 41, 43] * 2  # C Am F G
    for i, n in enumerate(lead):
        if n:
            tr.add(i * step, tone("pulse", hz(n), step * 0.95, 0.35, 5))
    for b in range(bars):
        r = roots[b]
        for k in range(8):
            tr.add((b * 8 + k) * step, tone("tri", hz(r - 12 + (12 if k % 2 else 0)), step * 0.9, 0.5, 4))
        for k in range(4):
            t0 = (b * 8 + k * 2) * step
            tr.add(t0, kick(0.7) if k % 2 == 0 else noise(0.12, 0.5, 25))
        for k in range(8):
            tr.add((b * 8 + k) * step, noise(0.04, 0.12, 80))
    tr.save(total, "nyan.ogg")


def disco():
    bpm, bars = 120, 8
    beat = 60 / bpm
    total = bars * 4 * beat
    tr = Track(total)
    chords = [(57, 60, 64), (62, 65, 69), (55, 59, 62), (60, 64, 67)] * 2  # Am Dm G C
    bass16 = [0, 12, 0, 0, 12, 0, 7, 0, 0, 12, 0, 0, 12, 0, 10, 12]
    for b in range(bars):
        root = chords[b][0] - 24
        for k in range(4):
            t0 = (b * 4 + k) * beat
            tr.add(t0, kick(0.9))
            tr.add(t0 + beat / 2, noise(0.18, 0.28, 18))  # open hat on the off-beat
            if k % 2:
                tr.add(t0, noise(0.16, 0.5, 22))
                tr.add(t0, tone("sine", 190, 0.12, 0.3, 30))  # clap/snare
        for s in range(16):
            tr.add((b * 4 + s / 4) * beat, tone("saw", hz(root + bass16[s]), beat / 4 * 0.85, 0.35, 8))
        for k in range(4):
            t0 = (b * 4 + k + 0.5) * beat
            for n in chords[b]:
                tr.add(t0, tone("pulse", hz(n + 12), beat * 0.3, 0.12, 9))
        # a little hook over the last two bars of every four
        if b % 4 >= 2:
            for k, n in enumerate([76, 79, 81, 79, 76, 74, 76, 0]):
                if n:
                    tr.add((b * 4 + k / 2) * beat, tone("square", hz(n), beat * 0.45, 0.16, 6))
    tr.save(total, "disco.ogg")


def story():
    """A slow music-box lullaby for the story intro (key "story")."""
    bpm, bars = 72, 8
    beat = 60 / bpm
    total = bars * 4 * beat
    tr = Track(total)
    chords = [(57, 60, 64), (53, 57, 60), (48, 52, 55), (55, 59, 62)] * 2  # Am F C G
    for b in range(bars):
        ch = chords[b]
        for k in range(8):  # rolling arpeggio, eighths
            n = ch[[0, 1, 2, 1, 0, 1, 2, 1][k]] + 12
            tr.add((b * 4 + k / 2) * beat, tone("sine", hz(n), beat * 1.2, 0.35, 3.2))
        tr.add(b * 4 * beat, tone("tri", hz(ch[0] - 12), beat * 3.5, 0.45, 0.9))
    hook = [(0, 76), (2, 79), (3, 76), (4, 72), (8, 74), (10, 77), (11, 74), (12, 71),
            (16, 72), (18, 76), (19, 79), (20, 84), (24, 83), (26, 79), (27, 76), (28, 79)]
    for pos, n in hook:  # the tune, a note per half beat from bar 3 on
        tr.add((8 + pos) * beat / 2 * 2 / 2 + 0, tone("sine", hz(n + 12), beat * 1.6, 0.3, 2.2))
    tr.save(total, "story.ogg")


def mania():
    """The song and its note chart for the rhythm game (key "mania"): sounds/secret/mania.ogg and
    mania.json ([time, lane, hold length] per note). Both come from the same lead line, so they match."""
    import json
    import random

    rng = random.Random(7)
    bpm, bars = 128, 24
    st = 60 / bpm / 4  # a sixteenth
    total = bars * 16 * st
    tr = Track(total)
    scale = [57, 60, 62, 64, 67, 69, 72, 74, 76, 79, 81, 84]  # A minor pentatonic
    chords = [(57, 60, 64), (53, 57, 60), (48, 52, 55), (55, 59, 62)]
    a = [[2] * 8, [3, 3, 2, 3, 3, 2], [4, 2, 2, 4, 4], [2, 2, 4, 2, 2, 4], [8, 4, 4], [6, 2, 4, 4]]
    b = [[1, 1, 2] * 4, [3, 3, 2, 3, 3, 2], [2] * 8, [2, 2, 4, 2, 2, 4], [1, 1, 2, 1, 1, 2, 2, 2, 4]]
    # Backing: pad all the way, drums and bass from bar 2
    for bar in range(bars):
        ch = chords[bar % 4]
        for n in ch:
            tr.add(bar * 16 * st, tone("sine", hz(n), 16 * st, 0.12, 0.6))
        if bar < 2:
            continue
        for k in range(4):
            t0 = (bar * 16 + k * 4) * st
            tr.add(t0, kick(0.85))
            tr.add(t0 + 2 * st, noise(0.06, 0.18, 60))
            if bar >= 4 and k % 2:
                tr.add(t0, noise(0.14, 0.45, 24))
        for k in range(8):
            tr.add((bar * 16 + k * 2) * st, tone("saw", hz(ch[0] - 24), 2 * st * 0.9, 0.25, 7))
    notes, idx = [], 5
    for bar in range(2, bars):
        pool = a if bar < 10 else b if bar < 18 else a + b
        pattern = [8, 8] if bar == bars - 1 else rng.choice(pool)
        pos = 0
        for ln in pattern:
            idx = max(1, min(len(scale) - 1, idx + rng.choice([-2, -1, -1, 1, 1, 2])))
            at = (bar * 16 + pos) * st
            hold = ln >= 6
            tr.add(at, tone("pulse", hz(scale[idx]), ln * st * 0.95, 0.3, 2.5 if hold else 5))
            notes.append([round(at, 3), idx % 4, round(ln * st * 0.9, 3) if hold else 0])
            pos += ln
    tr.save(total, "mania.ogg")
    (OUT / "mania.json").write_text(json.dumps({"length": round(total, 3), "notes": notes}, separators=(",", ":")))


if __name__ == "__main__":
    nyan()
    disco()
    story()
    mania()
