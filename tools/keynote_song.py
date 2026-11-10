#!/usr/bin/env python3
"""Sets up a song of your own for the keynote easter egg (Settings > About, key "keynote").

    python3 tools/keynote_song.py ~/Music/song.m4a

It finds the tempo and the beat, where the drums come in and the biggest breakdown -> drop, and
writes sounds/secret/keynote-song.json. The show then speeds up to the song's tempo (every slide
still starts on a bar) and plays a cut of it through mpv: the song from two bars before the drums
come in (the drums arrive with the logo), the last two bars before the drop under "One more
thing…", and from the drop on for the finale, which loops. Remove the json to get the show's own
track back. The song and the json stay on this machine (both are in .gitignore): a song is
somebody's music, so it never goes into the repository. Needs numpy, ffmpeg and (to play) mpv.
"""
import json
import subprocess
import sys
from pathlib import Path

import numpy as np

RATE = 11025
HOP = 110
WINDOW = 1024
OUT = Path(__file__).resolve().parent.parent / "sounds" / "secret" / "keynote-song.json"

# The show's timeline in beats (Keynote.qml runs at 120 BPM, a beat every 0.5 s)
SHOW_BEATS = 84  # 42 s of slides before "One more thing…"
BREAK_BARS = 2  # "One more thing…" (4 s)
LOOP_BARS = 16  # the finale's loop


def decode(path: Path) -> np.ndarray:
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(RATE), "-f", "f32le", "-"],
                         check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32)


def bass_envelope(x: np.ndarray) -> np.ndarray:
    """The low band's energy (where the kick lives), one value per hop."""
    taper = np.hanning(WINDOW)
    frames = range(0, len(x) - WINDOW, HOP)
    return np.array([np.abs(np.fft.rfft(x[i:i + WINDOW] * taper))[2:15].sum() for i in frames])


def beat_grid(low: np.ndarray, fps: float) -> tuple[float, float]:
    """(bpm, the first beat in seconds) that line up best with the bass onsets."""
    onsets = np.concatenate([[0], np.maximum(0, np.diff(np.log1p(low)))])

    def score(bpm: float, phase: float) -> float:
        idx = (np.arange(phase, len(onsets) / fps, 60 / bpm) * fps).astype(int)
        return float(onsets[idx[idx < len(onsets)]].sum())

    centered = onsets - onsets.mean()
    corr = np.correlate(centered, centered, "full")[len(onsets) - 1:]
    lag = max(range(int(fps * 60 / 200), int(fps * 60 / 90)), key=lambda k: corr[k])
    rough = 60 * fps / lag
    phases = lambda b: np.arange(0, 60 / b, 0.005)  # noqa: E731
    bpm = max(np.arange(rough - 2, rough + 2, 0.01), key=lambda b: max(score(b, p) for p in phases(b)))
    phase = max(np.arange(0, 60 / bpm, 0.002), key=lambda p: score(bpm, p))
    return float(bpm), float(phase)


def analyze(path: Path) -> dict:
    x = decode(path)
    fps = RATE / HOP
    low = bass_envelope(x)
    bpm, phase = beat_grid(low, fps)
    bar = 4 * 60 / bpm
    count = int((len(low) / fps - phase) / bar)
    level = np.array([low[int((phase + b * bar) * fps):int((phase + (b + 1) * bar) * fps)].mean() for b in range(count)])
    level /= level.mean()

    kick_in = next((b for b in range(1, count) if level[b] > 0.5), 2)
    start = max(0, kick_in - 2)
    show_end = start + SHOW_BEATS // 4
    # The drop: quiet bars, then loud ones, with the jump right on the bar; the sharpest such turn
    # after the slides' part
    drops = [(level[d:d + 4].mean() - level[d - 4:d].mean() + level[d] - level[d - 1], d) for d in range(max(show_end + 2, 4), count - LOOP_BARS)
             if level[d - 4:d].mean() < 0.7 and level[d:d + 4].mean() > 1.0]
    drop = max(drops)[1] if drops else show_end + BREAK_BARS
    # A build-up can start a bar early; the drop is where it gets loud (full level) for real
    for _ in range(2):
        if drops and level[drop] < 1.0 <= level[drop + 1]:
            drop += 1

    at = lambda b: round(phase + b * bar, 3)  # noqa: E731
    segments = [[at(start), round(SHOW_BEATS * 60 / bpm, 3)],
                [at(drop - BREAK_BARS), round((BREAK_BARS + LOOP_BARS) * bar, 3)]]
    loop_a = round(segments[0][1] + BREAK_BARS * bar, 3)
    return {"file": str(path.resolve()), "bpm": round(bpm, 3), "segments": segments,
            "loop": [loop_a, round(loop_a + LOOP_BARS * bar, 3)]}


def main() -> None:
    if len(sys.argv) != 2 or not Path(sys.argv[1]).is_file():
        sys.exit(__doc__)
    profile = analyze(Path(sys.argv[1]))
    OUT.write_text(json.dumps(profile, indent=2) + "\n")
    s, loop = profile["segments"], profile["loop"]
    sys.stdout.write(f"{profile['bpm']} BPM; the cut: {s[0][0]} s for {s[0][1]} s, then {s[1][0]} s for {s[1][1]} s; "
                     f"the drop at {loop[0]} s of the cut, looping to {loop[1]} s; wrote {OUT}\n")

if __name__ == "__main__":
    main()
