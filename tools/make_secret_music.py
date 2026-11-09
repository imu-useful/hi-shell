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


if __name__ == "__main__":
    nyan()
    disco()
