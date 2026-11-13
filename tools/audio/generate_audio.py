#!/usr/bin/env python3
"""
Math Rings — original, offline sound identity.

All effects are synthesized here (no third-party samples).  The runtime loads
the WAVs through the central AudioService and can fall back to live Web Audio
synthesis if a file is unavailable.  Run:

    python3 tools/audio/generate_audio.py
"""
from __future__ import annotations

import math
import os
import struct
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SFX = os.path.join(ROOT, "assets", "audio", "sfx")
AMB = os.path.join(ROOT, "assets", "audio", "ambience")
SR = 22050
rng = np.random.default_rng(20261108)


def t(dur: float) -> np.ndarray:
    return np.arange(int(SR * dur), dtype=np.float64) / SR


def fade(x: np.ndarray, attack: float = 0.006, release: float = 0.03) -> np.ndarray:
    n = len(x)
    a = max(1, int(attack * SR))
    r = max(1, int(release * SR))
    env = np.ones(n)
    env[:a] = np.linspace(0, 1, a)
    env[-r:] *= np.linspace(1, 0, r)
    return x * env


def norm(x: np.ndarray, peak: float = 0.82) -> np.ndarray:
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 1e-9 else x


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    a = math.exp(-2.0 * math.pi * cutoff / SR)
    y = np.empty_like(x)
    z = 0.0
    for i, v in enumerate(x):
        z = (1 - a) * v + a * z
        y[i] = z
    return y


def highpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    return x - lowpass(x, cutoff)


def bandpass(x: np.ndarray, lo: float, hi: float) -> np.ndarray:
    return highpass(lowpass(x, hi), lo)


def sine(freq, dur, phase=0.0, wobble=0.0):
    tt = t(dur)
    f = freq + wobble * np.sin(2 * math.pi * 3.1 * tt)
    return np.sin(2 * math.pi * f * tt + phase)


def noise(dur):
    return rng.normal(0, 1, int(SR * dur))


def bell(freq, dur, decay=5.0, detune=1.003):
    tt = t(dur)
    env = np.exp(-decay * tt)
    return (np.sin(2 * math.pi * freq * tt) + 0.55 * np.sin(2 * math.pi * freq * 2.01 * tt)
            + 0.25 * np.sin(2 * math.pi * freq * detune * 3.02 * tt)) * env


def bubble(freq=520, dur=0.18):
    tt = t(dur)
    f = freq + 900 * tt / dur
    env = np.exp(-9 * tt)
    return np.sin(2 * math.pi * f * tt) * env


def add_at(dst, src, at):
    i = int(at * SR)
    n = min(len(src), len(dst) - i)
    if n > 0:
        dst[i:i + n] += src[:n]
    return dst


def write(name, x, *, peak=0.8, stereo=False):
    x = norm(np.nan_to_num(x), peak)
    path = os.path.join(SFX if not stereo else AMB, name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = np.clip(x, -1, 1)
    pcm = (data * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("wrote", os.path.relpath(path, ROOT), f"{len(x)/SR:.2f}s")


# ---------------------------------------------------------------------------
# Kecrekan
# ---------------------------------------------------------------------------

def bead_slide():
    dur = 1.0
    tt = t(dur)
    n = bandpass(noise(dur), 380, 2600) * 0.55
    # wooden body resonance, amplitude follows a gentle hand-motion wobble
    wood = np.sin(2 * math.pi * 190 * tt) * 0.12 + np.sin(2 * math.pi * 310 * tt) * 0.06
    wob = 0.55 + 0.45 * np.sin(2 * math.pi * 2.2 * tt)
    x = (n + wood) * wob
    # make the loop seamless
    nf = int(0.06 * SR)
    x[:nf] *= np.linspace(0, 1, nf)
    x[-nf:] *= np.linspace(1, 0, nf)
    write("bead_slide.wav", fade(x, 0.01, 0.02), peak=0.55)


def bead_snap():
    dur = 0.24
    tt = t(dur)
    click = highpass(noise(dur), 1600) * np.exp(-55 * tt)
    wood = np.sin(2 * math.pi * 220 * tt) * np.exp(-20 * tt)
    glass = np.sin(2 * math.pi * 1040 * tt) * np.exp(-9 * tt) * 0.45
    x = click * 0.7 + wood * 0.55 + glass
    write("bead_snap.wav", fade(x, 0.001, 0.05))


def group_five():
    dur = 0.95
    x = np.zeros(int(SR * dur))
    for i, f in enumerate([523.25, 659.25, 783.99, 1046.5]):
        add_at(x, bell(f, 0.8, 5.5) * (0.55 - i * 0.05), i * 0.075)
    add_at(x, bandpass(noise(0.3), 3000, 8000) * np.exp(-10 * t(0.3)) * 0.10, 0.16)
    write("group_five.wav", fade(x, 0.003, 0.1))


def reset_sound():
    dur = 1.1
    tt = t(dur)
    sweep = np.sin(2 * math.pi * (760 - 560 * tt / dur) * tt) * np.exp(-2.5 * tt) * 0.4
    wash = bandpass(noise(dur), 250, 1800) * np.exp(-1.2 * tt) * 0.35
    x = sweep + wash
    for at in [0.08, 0.22, 0.36, 0.55, 0.72]:
        add_at(x, bubble(380 + 200 * at, 0.14) * 0.25, at)
    write("reset.wav", fade(x, 0.01, 0.12))


# ---------------------------------------------------------------------------
# Gameplay / rewards
# ---------------------------------------------------------------------------

def pearl_collect():
    dur = 0.55
    x = bell(1318.5, dur, 7.0) * 0.6 + bell(1760, dur, 9.0) * 0.25
    add_at(x, bandpass(noise(0.18), 4000, 9000) * np.exp(-16 * t(0.18)) * 0.12, 0.02)
    write("pearl.wav", fade(x, 0.002, 0.08))


def correct():
    dur = 0.85
    x = np.zeros(int(SR * dur))
    add_at(x, bell(659.25, 0.6, 6.0) * 0.55, 0)
    add_at(x, bell(987.77, 0.65, 5.0) * 0.55, 0.12)
    add_at(x, bell(1318.5, 0.7, 5.0) * 0.35, 0.24)
    write("correct.wav", fade(x, 0.003, 0.12))


def wrong():
    dur = 0.38
    tt = t(dur)
    f = 210 - 55 * tt / dur
    x = np.sin(2 * math.pi * f * tt) * np.exp(-6 * tt) * 0.5
    x += np.sin(2 * math.pi * (f * 2) * tt) * np.exp(-8 * tt) * 0.12
    write("wrong.wav", fade(x, 0.006, 0.1), peak=0.55)


def mission_complete():
    dur = 3.0
    x = np.zeros(int(SR * dur))
    notes = [523.25, 659.25, 783.99, 1046.5, 1318.5, 1567.98]
    for i, f in enumerate(notes):
        add_at(x, bell(f, 1.4, 3.4) * (0.48 - i * 0.035), i * 0.14)
    add_at(x, bandpass(noise(0.9), 3500, 9000) * np.exp(-3.0 * t(0.9)) * 0.10, 0.55)
    for i, at in enumerate([0.9, 1.1, 1.35, 1.65, 1.9]):
        add_at(x, bubble(700 + i * 120, 0.16) * 0.12, at)
    write("mission_complete.wav", fade(x, 0.005, 0.5))


def chest_open():
    dur = 1.5
    tt = t(dur)
    creak = bandpass(noise(dur), 180, 900) * (0.3 + 0.7 * np.exp(-1.6 * tt)) * 0.35
    creak *= (0.6 + 0.4 * np.sin(2 * math.pi * 9 * tt))
    x = creak
    add_at(x, bell(1046.5, 1.0, 4.0) * 0.5, 0.42)
    add_at(x, bell(1568, 1.1, 4.5) * 0.3, 0.52)
    add_at(x, bandpass(noise(0.5), 3000, 10000) * np.exp(-5 * t(0.5)) * 0.12, 0.5)
    write("chest_open.wav", fade(x, 0.01, 0.2))


def star():
    dur = 0.75
    x = bell(1760, dur, 5.0) * 0.6 + bell(2637, dur, 7.0) * 0.22
    write("star.wav", fade(x, 0.002, 0.1))


def unlock():
    dur = 2.2
    tt = t(dur)
    sweep = np.sin(2 * math.pi * (260 + 700 * tt / dur) * tt) * np.exp(-1.1 * tt) * 0.35
    x = sweep + bandpass(noise(dur), 800, 6000) * np.exp(-2.0 * tt) * 0.18
    for i, f in enumerate([523.25, 783.99, 1046.5, 1568]):
        add_at(x, bell(f, 1.2, 3.5) * 0.35, 0.55 + i * 0.13)
    write("unlock.wav", fade(x, 0.01, 0.3))


def bubble_sfx():
    write("bubble.wav", bubble(640, 0.22), peak=0.5)


def ui_tap():
    dur = 0.16
    tt = t(dur)
    x = highpass(noise(dur), 1200) * np.exp(-32 * tt) * 0.5
    x += np.sin(2 * math.pi * 620 * tt) * np.exp(-28 * tt) * 0.25
    write("ui_tap.wav", fade(x, 0.001, 0.04), peak=0.6)


def whoosh():
    dur = 0.7
    x = bandpass(noise(dur), 300, 2200) * (np.sin(np.pi * t(dur) / dur) ** 2) * 0.5
    write("whoosh.wav", fade(x, 0.01, 0.08), peak=0.5)


# ---------------------------------------------------------------------------
# Jarimatika hands
# ---------------------------------------------------------------------------

def hand_tap():
    dur = 0.2
    tt = t(dur)
    x = highpass(noise(dur), 900) * np.exp(-36 * tt) * 0.35
    x += np.sin(2 * math.pi * 300 * tt) * np.exp(-22 * tt) * 0.28
    write("hand_tap.wav", fade(x, 0.001, 0.05), peak=0.6)


def finger_move(up=True):
    dur = 0.32
    tt = t(dur)
    f = (240 + 520 * tt / dur) if up else (760 - 520 * tt / dur)
    x = np.sin(2 * math.pi * f * tt) * np.exp(-5 * tt) * 0.35
    x += bandpass(noise(dur), 600, 3200) * np.exp(-8 * tt) * 0.12
    write("finger_up.wav" if up else "finger_down.wav", fade(x, 0.004, 0.07), peak=0.55)


def hand_success():
    dur = 1.15
    x = np.zeros(int(SR * dur))
    for i, f in enumerate([659.25, 830.61, 987.77, 1318.5]):
        add_at(x, bell(f, 0.9, 4.5) * 0.4, i * 0.09)
    add_at(x, bandpass(noise(0.35), 3500, 9000) * np.exp(-8 * t(0.35)) * 0.08, 0.2)
    write("hand_success.wav", fade(x, 0.003, 0.16))


# ---------------------------------------------------------------------------
# Ambience
# ---------------------------------------------------------------------------

def ambience():
    dur = 24.0
    n = int(SR * dur)
    tt = np.arange(n) / SR
    # Deep, slow water bed.
    bed = (np.sin(2 * math.pi * 55 * tt + 0.3 * np.sin(2 * math.pi * 0.07 * tt))
           + 0.55 * np.sin(2 * math.pi * 82.5 * tt + 0.4 * np.sin(2 * math.pi * 0.05 * tt))
           + 0.25 * np.sin(2 * math.pi * 110 * tt))
    bed *= 0.13
    # Filtered current noise with a slow swell.
    current = bandpass(rng.normal(0, 1, n), 120, 900)
    swell = 0.55 + 0.45 * np.sin(2 * math.pi * 0.035 * tt - 1.1)
    current = current * swell * 0.075
    # Distant friendly whale-like calls.
    calls = np.zeros(n)
    for at, base in [(3.2, 196), (11.5, 174), (19.0, 220)]:
        cd = 2.6
        ct = np.arange(int(SR * cd)) / SR
        env = np.sin(np.pi * ct / cd) ** 2
        f = base + 18 * np.sin(2 * math.pi * 0.45 * ct)
        call = (np.sin(2 * math.pi * f * ct) + 0.25 * np.sin(2 * math.pi * f * 2 * ct)) * env * 0.05
        add_at(calls, call, at)
    # Sparse bubbles.
    bubbles = np.zeros(n)
    for _ in range(46):
        at = rng.uniform(0, dur - 0.3)
        f = rng.uniform(420, 980)
        add_at(bubbles, bubble(f, rng.uniform(0.08, 0.2)) * rng.uniform(0.03, 0.10), at)
    x = bed + current + calls + bubbles
    # Loop-safe crossfade: blend the tail into the head, then drop the tail.
    # The new end is the sample immediately before the tail, so playback loops
    # continuously into the blended head.
    cf = int(1.2 * SR)
    head = x[:cf].copy()
    tail = x[-cf:].copy()
    blended = head * np.linspace(0, 1, cf) + tail * np.linspace(1, 0, cf)
    x = x[:-cf]
    x[:cf] = blended
    write("ocean_ambience.wav", x, peak=0.55, stereo=True)


def main():
    os.makedirs(SFX, exist_ok=True)
    os.makedirs(AMB, exist_ok=True)
    bead_slide()
    bead_snap()
    group_five()
    reset_sound()
    pearl_collect()
    correct()
    wrong()
    mission_complete()
    chest_open()
    star()
    unlock()
    bubble_sfx()
    ui_tap()
    whoosh()
    hand_tap()
    finger_move(True)
    finger_move(False)
    hand_success()
    ambience()


if __name__ == "__main__":
    main()
