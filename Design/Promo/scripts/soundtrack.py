"""Synthesises the film's soundtrack: one calm D major track with its effects on the cut points.

    python3 scripts/soundtrack.py          # needs numpy and ffmpeg; writes assets/audio/soundtrack.m4a

Everything is generated here and mixed offline into one file, so the film plays a single <audio>.
Event times are root-timeline seconds from SPEC.md · Sound; move them with the shots.
"""

import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

SR = 48000
LENGTH = 40.0
BEAT = 60 / 90
OUT = Path(__file__).resolve().parent.parent / "assets/audio/soundtrack.m4a"

rng = np.random.default_rng(7)
mix = np.zeros((2, int(SR * LENGTH)))


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def span(seconds):
    return np.arange(int(SR * seconds)) / SR


def add(at, mono, gain=1.0, pan=0.0):
    start = int(SR * at)
    end = min(start + len(mono), mix.shape[1])
    mono = mono[: end - start] * gain
    mix[0, start:end] += mono * np.sqrt((1 - pan) / 2)
    mix[1, start:end] += mono * np.sqrt((1 + pan) / 2)


def lowpass(signal, cutoff):
    """One-pole lowpass; cutoff may be a per-sample array."""
    alpha = 1 - np.exp(-2 * np.pi * np.broadcast_to(cutoff, signal.shape) / SR)
    out = np.empty_like(signal)
    level = 0.0
    for i, (x, a) in enumerate(zip(signal, alpha)):
        level += a * (x - level)
        out[i] = level
    return out


def pad(notes, seconds):
    t = span(seconds)
    tone = np.zeros_like(t)
    for note in notes:
        for detune in (-0.12, 0.0, 0.12):
            f = hz(note + detune)
            for n in range(1, 6):
                tone += np.sin(2 * np.pi * f * n * t + n) / (n * n)
    env = np.minimum(1, t / 1.2) * np.minimum(1, (seconds - t) / 1.4)
    return tone * env / (len(notes) * 3)


def pluck(note, seconds=1.2, bright=1.0):
    t = span(seconds)
    f = hz(note)
    tone = np.sin(2 * np.pi * f * t) + 0.35 * bright * np.sin(4 * np.pi * f * t) + 0.12 * bright * np.sin(6 * np.pi * f * t)
    return tone * np.exp(-t * 4.5) * np.minimum(1, t / 0.004)


def bell(note, seconds=2.5):
    t = span(seconds)
    f = hz(note)
    tone = sum(np.sin(2 * np.pi * f * r * t) * a * np.exp(-t * d) for r, a, d in ((1, 1, 1.6), (2.76, 0.45, 3.2), (5.4, 0.25, 5.5), (8.93, 0.12, 8)))
    return tone * np.minimum(1, t / 0.003)


def tap():
    t = span(0.06)
    click = np.sin(2 * np.pi * 2300 * t) * np.exp(-t * 140)
    noise = rng.standard_normal(len(t)) * np.exp(-t * 220)
    return click * 0.6 + (noise - lowpass(noise, 3000)) * 0.4


def whoosh(seconds=0.7, low=300, high=4000):
    t = span(seconds)
    shape = np.sin(np.pi * t / seconds) ** 2
    return lowpass(rng.standard_normal(len(t)), low + (high - low) * shape) * shape


def riser(seconds):
    t = span(seconds)
    sweep = np.sin(2 * np.pi * np.cumsum(hz(74) * (1 + t / seconds)) / SR)
    air = lowpass(rng.standard_normal(len(t)), 800 + 5000 * t / seconds)
    return (sweep * 0.25 + air) * (t / seconds) ** 2


def sparkle(at, count, gain):
    scale = (86, 88, 90, 93, 95, 98)
    for i in range(count):
        add(at + i * 0.07, pluck(scale[i % len(scale)], 0.6, 0.4), gain, pan=-0.5 + i / max(count - 1, 1))


chords = ((50, 62, 66, 69, 73, 76), (47, 59, 62, 66, 69, 73), (43, 55, 59, 62, 66, 71), (45, 57, 61, 64, 66, 71))
bar = BEAT * 4
for i in range(int(LENGTH // (bar * 2)) + 1):
    at = i * bar * 2
    if at >= 36:
        break
    notes = chords[i % 4]
    add(at, pad(notes[1:], bar * 2 + 1.2), 0.22 if at < 3.5 else 0.3)
    add(at, pad(notes[:1], bar * 2 + 1.2) * 2, 0.16)
add(33.0, pad((62, 66, 69, 73, 76), 7.0), 0.32)
add(33.0, pad((50,), 7.0) * 2, 0.18)

pattern = (0, 2, 4, 5, 4, 2, 3, 1)
t = 3.5
step = 0
while t < 33.0:
    notes = chords[int(t // (bar * 2)) % 4][1:]
    add(t, pluck(notes[pattern[step % 8] % len(notes)] + 12, 0.9, 0.6), 0.07, pan=0.3 * np.sin(step / 3))
    t += BEAT / 2
    step += 1

add(0.10, pluck(74, 1.6), 0.22)
add(0.10, pluck(81, 1.6), 0.12, pan=0.3)
add(0.85, whoosh(0.8), 0.18, pan=-0.2)
add(1.35, riser(1.25), 0.10)
add(2.58, bell(86, 3.0), 0.16, pan=0.3)
sparkle(2.62, 4, 0.05)

add(3.50, whoosh(0.9, 200, 1800), 0.14)
add(4.10, pluck(78, 1.0), 0.12)
add(5.50, tap(), 0.35)
add(5.68, whoosh(0.6, 400, 6000), 0.2, pan=0.2)
add(6.10, bell(74, 2.0), 0.08)
for i in range(6):
    add(6.95 + i * 0.05, pluck((74, 76, 78, 81, 83, 86)[i], 0.5, 0.3), 0.06, pan=-0.3 + i * 0.12)
add(8.40, tap(), 0.35)
add(8.50, pluck(81, 0.9), 0.1)
add(9.55, whoosh(1.6, 200, 1500), 0.08)
add(11.50, tap(), 0.35)
sparkle(12.10, 4, 0.05)
add(12.95, whoosh(2.4, 200, 1400), 0.07)
add(16.10, tap(), 0.35)
for i in range(0, 25, 3):
    add(16.50 + i * 0.04, pluck((81, 83, 86, 88, 90)[i % 5], 0.4, 0.3), 0.05, pan=-0.4 + i / 30)
add(18.80, tap(), 0.35)
sparkle(19.90, 5, 0.04)
add(22.10, tap(), 0.35)
add(23.10, tap(), 0.35)
add(24.35, bell(81, 2.4), 0.13, pan=0.2)

add(27.00, whoosh(0.9, 250, 2500), 0.14)
for i in range(5):
    add(27.20 + i * 0.28, pluck((74, 78, 81, 83, 86)[i], 0.7, 0.4), 0.08, pan=-0.4 + i * 0.2)

add(32.70, riser(0.4), 0.06)
add(33.05, pluck(74, 1.4), 0.18)
add(33.60, bell(93, 1.6), 0.06, pan=0.3)
add(34.20, pluck(81, 1.0), 0.12)
add(34.70, whoosh(0.9, 300, 2000), 0.07, pan=0.3)
add(35.60, tap(), 0.4)
add(35.70, bell(86, 3.5), 0.2)
sparkle(35.75, 6, 0.06)
add(38.00, bell(93, 2.0), 0.05)

# master: fade in and out, soft clip, peak at -1 dBFS
t = span(LENGTH)
mix *= np.minimum(1, t / 0.5) * np.clip((LENGTH - t) / 2.0, 0, 1)
mix = np.tanh(mix * 1.6)
mix *= 10 ** (-1 / 20) / np.abs(mix).max()

OUT.parent.mkdir(parents=True, exist_ok=True)
with tempfile.NamedTemporaryFile(suffix=".wav") as raw:
    with wave.open(raw.name, "wb") as out:
        out.setnchannels(2)
        out.setsampwidth(2)
        out.setframerate(SR)
        out.writeframes((mix.T * 32767).astype("<i2").tobytes())
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", raw.name, "-c:a", "aac", "-b:a", "256k", str(OUT)], check=True)
print(f"Wrote {OUT} ({LENGTH:.0f} s)")
