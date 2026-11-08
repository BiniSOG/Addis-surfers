#!/usr/bin/env python3
"""Synthesises the Addis Surfers soundtrack and sound effects.

Everything here is original and generated from code (no samples), so the
audio is royalty-free and reproducible:

    python3 tools/generate_audio.py        # needs numpy, scipy and ffmpeg

Music is written in Ethiopian *qenet* (pentatonic modes):
  * "Merkato Run" (gameplay) - Ambassel mode, 6/8 eskista groove with kebero
    drums, krar (lyre) ostinato, masenqo (one-string fiddle) and washint
    (flute) melodies.
  * "Tezeta" (menu)          - Tezeta minor mode, slow krar arpeggios with a
    washint melody and a soft drone.
"""

from __future__ import annotations

import os
import subprocess
import tempfile
import wave

import numpy as np
from scipy.signal import butter, fftconvolve, lfilter, sosfilt

SR = 44100
RNG = np.random.default_rng(1913)
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")

# Qenet (semitones above the tonic).
AMBASSEL = [0, 1, 5, 7, 8]
TEZETA_MINOR = [0, 2, 3, 7, 8]
TEZETA_MAJOR = [0, 2, 4, 7, 9]
BATI_MAJOR = [0, 4, 5, 7, 11]

# The main soundtrack (tools/source/addis_groove_source.mp3) is in G major at
# ~126 bpm, so gameplay sounds are tuned to G to sit inside the music.
TRACK_ROOT = 67  # G4
G_MAJOR_PENTA = [0, 2, 4, 7, 9]


def midi_to_hz(m: float) -> float:
    return 440.0 * 2 ** ((m - 69) / 12)


def degree_hz(scale: list[int], root_midi: int, d: int) -> float:
    octave, idx = divmod(d, len(scale))
    return midi_to_hz(root_midi + 12 * octave + scale[idx])


def bandpass(x, lo, hi, order=2):
    sos = butter(order, [lo, hi], btype="band", fs=SR, output="sos")
    return sosfilt(sos, x)


def lowpass(x, f, order=2):
    return sosfilt(butter(order, f, btype="low", fs=SR, output="sos"), x)


def highpass(x, f, order=2):
    return sosfilt(butter(order, f, btype="high", fs=SR, output="sos"), x)


def env_exp(n, tau):
    t = np.arange(n) / SR
    return np.exp(-t / tau)


# --------------------------------------------------------------------------
# Instruments


def krar(freq: float, dur: float, amp: float = 1.0, bright: float = 0.6) -> np.ndarray:
    """Plucked lyre string (Karplus-Strong)."""
    n = int(dur * SR)
    period = max(2, int(round(SR / freq - 0.5)))
    burst = RNG.uniform(-1, 1, period)
    burst = lowpass(burst, 1500 + 6000 * bright)
    x = np.zeros(n)
    x[: min(period, n)] = burst[: min(period, n)]
    decay = 0.9965
    a = np.zeros(period + 2)
    a[0] = 1.0
    a[period] = -0.5 * decay
    a[period + 1] = -0.5 * decay
    y = lfilter([1.0], a, x)
    # Body resonance + a little buzz, typical of the krar.
    y = 0.8 * y + 0.35 * bandpass(y, 180, 900)
    fade = np.ones(n)
    tail = min(n, int(0.04 * SR))
    fade[-tail:] = np.linspace(1, 0, tail)
    y *= fade
    return amp * y / (np.max(np.abs(y)) + 1e-9)


def _phrase_curves(notes, step, glide=0.05, scoop=True):
    """Builds per-sample frequency and amplitude curves for a legato phrase.

    notes: list of (freq or None for rest, length in steps).
    """
    total = sum(l for _, l in notes)
    n = int(total * step * SR)
    f = np.zeros(n)
    a = np.zeros(n)
    pos = 0
    prev = None
    for freq, length in notes:
        m = int(length * step * SR)
        seg = slice(pos, min(n, pos + m))
        ln = seg.stop - seg.start
        if freq is None:
            f[seg] = prev or 220
            a[seg] = 0
            prev = None
        else:
            start = prev if prev else (freq / 2 ** (1.5 / 12) if scoop else freq)
            g = min(ln, int(glide * SR))
            curve = np.full(ln, freq)
            if g > 0:
                curve[:g] = start * (freq / start) ** np.linspace(0, 1, g)
            f[seg] = curve
            env = np.ones(ln)
            att = min(ln, int(0.03 * SR))
            env[:att] = np.linspace(0.55 if prev else 0.0, 1, att)
            rel = min(ln, int(0.05 * SR))
            env[-rel:] *= np.linspace(1, 0.75, rel)
            # Gentle vibrato that grows on long notes.
            t = np.arange(ln) / SR
            vib_depth = np.clip((t - 0.18) / 0.4, 0, 1) * 0.009
            f[seg] *= 1 + vib_depth * np.sin(2 * np.pi * 5.6 * t)
            a[seg] = env
            prev = freq
        pos += m
    # Close the phrase.
    rel = int(0.08 * SR)
    a[-rel:] *= np.linspace(1, 0, rel)
    return f, a


def masenqo(notes, step, amp=1.0) -> np.ndarray:
    """Bowed one-string fiddle: rich, nasal sawtooth with slides."""
    f, a = _phrase_curves(notes, step, glide=0.07)
    phase = 2 * np.pi * np.cumsum(f) / SR
    y = np.zeros_like(f)
    for k in range(1, 18):
        y += np.sin(k * phase) / k * (1.0 if k < 6 else 0.7)
    # Bow noise.
    y += 0.08 * bandpass(RNG.standard_normal(len(y)), 1500, 5000) * a
    y = 0.45 * y + 0.9 * bandpass(y, 700, 1500) + 0.5 * bandpass(y, 2200, 3200)
    y *= a
    return amp * y / (np.max(np.abs(y)) + 1e-9)


def washint(notes, step, amp=1.0) -> np.ndarray:
    """Bamboo flute: airy sine with breath and chiff."""
    f, a = _phrase_curves(notes, step, glide=0.04, scoop=False)
    phase = 2 * np.pi * np.cumsum(f) / SR
    y = np.sin(phase) + 0.22 * np.sin(2 * phase) + 0.08 * np.sin(3 * phase)
    breath = bandpass(RNG.standard_normal(len(y)), 900, 4500) * 0.12
    y = (y + breath) * a
    return amp * y / (np.max(np.abs(y)) + 1e-9)


def kebero_dum(amp=1.0) -> np.ndarray:
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    freq = 55 + 65 * np.exp(-t / 0.05)
    phase = 2 * np.pi * np.cumsum(freq) / SR
    y = np.sin(phase) * env_exp(n, 0.2)
    click = bandpass(RNG.standard_normal(n), 300, 2000) * env_exp(n, 0.008) * 0.6
    return amp * (y + click)


def kebero_ka(amp=1.0) -> np.ndarray:
    n = int(0.18 * SR)
    noise = bandpass(RNG.standard_normal(n), 700, 3500) * env_exp(n, 0.035)
    tone = np.sin(2 * np.pi * 320 * np.arange(n) / SR) * env_exp(n, 0.05)
    y = 0.8 * noise + 0.6 * tone
    return amp * y / (np.max(np.abs(y)) + 1e-9)


def clap(amp=1.0) -> np.ndarray:
    n = int(0.2 * SR)
    y = np.zeros(n)
    for i, off in enumerate([0, 0.009, 0.018]):
        s = int(off * SR)
        burst = RNG.standard_normal(n - s) * env_exp(n - s, 0.012 if i < 2 else 0.06)
        y[s:] += burst
    y = bandpass(y, 900, 3200)
    return amp * y / (np.max(np.abs(y)) + 1e-9)


def shaker(amp=1.0) -> np.ndarray:
    n = int(0.07 * SR)
    y = highpass(RNG.standard_normal(n), 5000) * env_exp(n, 0.018)
    return amp * y / (np.max(np.abs(y)) + 1e-9)


def drone(freq, dur, amp=1.0) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for k, g in [(1, 1), (2, 0.5), (3, 0.25), (4, 0.12)]:
        y += g * np.sin(2 * np.pi * freq * k * t * (1 + 0.0015 * np.sin(2 * np.pi * 0.3 * t)))
    y = lowpass(y, 1200)
    return amp * y / (np.max(np.abs(y)) + 1e-9)


# --------------------------------------------------------------------------
# Mixing helpers


class Track:
    def __init__(self, seconds: float):
        self.length = int(seconds * SR)
        self.buf = np.zeros(self.length + int(4 * SR))

    def add(self, sound: np.ndarray, at: float, gain: float = 1.0):
        s = int(at * SR)
        e = min(len(self.buf), s + len(sound))
        self.buf[s:e] += gain * sound[: e - s]

    def render(self, reverb=0.18) -> np.ndarray:
        y = self.buf.copy()
        if reverb > 0:
            n = int(1.4 * SR)
            ir = RNG.standard_normal(n) * env_exp(n, 0.35)
            ir = lowpass(ir, 5000)
            ir /= np.sqrt(np.sum(ir**2))
            wet = fftconvolve(y, ir)[: len(y)]
            y = y + reverb * wet
        # Fold the tail back onto the start so the loop is seamless.
        tail = y[self.length :]
        out = y[: self.length].copy()
        out[: len(tail)] += tail[: self.length]
        out = np.tanh(out / (np.max(np.abs(out)) + 1e-9) * 1.4)
        return out / np.max(np.abs(out)) * 0.89


def write_mp3(path: str, y: np.ndarray, bitrate: str):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    # Android's MediaPlayer fails to open extremely short MP3s ("error (1,
    # MIN_INT)"), so pad every effect to at least 0.3 s with silence.
    min_len = int(0.3 * SR)
    if len(y) < min_len:
        y = np.concatenate([y, np.zeros(min_len - len(y))])
    pcm = (np.clip(y, -1, 1) * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wav_path = tmp.name
    with wave.open(wav_path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-codec:a", "libmp3lame",
         "-b:a", bitrate, path],
        check=True,
    )
    os.remove(wav_path)
    print(f"wrote {os.path.relpath(path, ROOT)}  ({os.path.getsize(path) // 1024} KB)")


# --------------------------------------------------------------------------
# Gameplay theme: "Merkato Run" (Ambassel, 6/8)


def merkato_run() -> np.ndarray:
    scale, root = AMBASSEL, 64  # E4
    eighth = 60 / (104 * 3)  # dotted quarter = 104 bpm
    bar = 6 * eighth
    bars = 32
    tr = Track(bars * bar)
    hz = lambda d: degree_hz(scale, root, d)  # noqa: E731

    # Kebero eskista groove + shaker drive.
    for b in range(bars):
        t0 = b * bar
        intro = b < 2
        for i in range(6):
            t = t0 + i * eighth
            if not intro:
                tr.add(shaker(), t, 0.10 if i % 3 else 0.16)
            if i in (0, 3):
                tr.add(kebero_dum(), t, 0.85 if i == 0 else 0.7)
            elif i in (2, 5):
                tr.add(kebero_ka(), t, 0.42)
            elif i == 4 and not intro:
                tr.add(kebero_ka(), t, 0.18)
        if b % 4 == 3 and not intro:  # little fill
            tr.add(kebero_ka(), t0 + 5.5 * eighth, 0.3)
        if 18 <= b < 30:  # hand claps in the last section
            for i in (0, 2, 3, 5):
                tr.add(clap(), t0 + i * eighth, 0.20)

    # Krar ostinato (two bars on the tonic, two on the fourth degree area).
    pattern = [0, 3, 2, 5, 3, 2]
    for b in range(bars):
        shift = 0 if (b // 2) % 2 == 0 else 2
        if b % 8 in (6, 7):
            shift = 1 if b % 8 == 6 else 0
        for i, d in enumerate(pattern):
            dd = d + shift - 5  # one octave lower
            accent = 1.0 if i in (0, 3) else 0.7
            tr.add(krar(hz(dd), eighth * 2.2, bright=0.55), b * bar + i * eighth, 0.30 * accent)

    def phrase(spec):
        return [(None if d is None else hz(d), l) for d, l in spec]

    A = [
        (5, 3), (4, 1), (3, 2),
        (4, 2), (3, 1), (2, 3),
        (3, 2), (2, 1), (1, 2), (2, 1),
        (0, 6),
        (2, 1), (3, 1), (4, 1), (5, 3),
        (6, 2), (5, 1), (4, 3),
        (3, 2), (4, 1), (3, 1), (2, 1), (1, 1),
        (0, 5), (None, 1),
    ]
    B = [
        (7, 3), (6, 3),
        (5, 2), (6, 1), (5, 3),
        (4, 1), (5, 1), (4, 1), (3, 3),
        (2, 6),
        (3, 1), (4, 1), (5, 1), (6, 1), (5, 2),
        (4, 3), (3, 3),
        (2, 2), (1, 1), (2, 3),
        (0, 5), (None, 1),
    ]
    tr.add(masenqo(phrase(A), eighth), 2 * bar, 0.55)
    tr.add(washint(phrase(B), eighth), 10 * bar, 0.50)
    tr.add(masenqo(phrase(A), eighth), 18 * bar, 0.55)
    tr.add(washint(phrase([(d + 5 if d is not None else None, l) for d, l in A]), eighth),
           18 * bar, 0.22)
    # Turnaround: short call and response.
    turn = [(5, 2), (4, 1), (3, 3), (4, 2), (3, 1), (2, 3), (1, 3), (0, 3), (None, 6)]
    tr.add(masenqo(phrase(turn), eighth), 26 * bar, 0.5)
    tr.add(drone(hz(-10), bars * bar, 1.0), 0, 0.07)
    return tr.render(reverb=0.16)


# --------------------------------------------------------------------------
# Menu theme: "Tezeta" (Tezeta minor, slow 4/4)


def tezeta() -> np.ndarray:
    scale, root = TEZETA_MINOR, 62  # D4
    beat = 60 / 76
    bar = 4 * beat
    bars = 14
    tr = Track(bars * bar)
    hz = lambda d: degree_hz(scale, root, d)  # noqa: E731

    roots = [0, 0, 0, 0, 0, 0, 2, 2, 0, 0, 3, 3, 2, 0]
    arp = [0, 2, 4, 5, 4, 2, 3, 2]
    for b in range(bars):
        for i, d in enumerate(arp):
            dd = d + roots[b] - 5
            tr.add(krar(hz(dd), beat * 1.6, bright=0.45), b * bar + i * beat / 2,
                   0.36 if i % 4 == 0 else 0.25)
        tr.add(kebero_dum(), b * bar, 0.35)
        tr.add(kebero_dum(), b * bar + 2.5 * beat, 0.18)
        tr.add(kebero_ka(), b * bar + 2 * beat, 0.12)

    melody = [
        (5, 2), (4, 1), (3, 1),
        (4, 3), (3, 1),
        (2, 1), (3, 1), (2, 1), (1, 1),
        (0, 4),
        (3, 2), (4, 1), (5, 1),
        (6, 3), (5, 1),
        (4, 1), (5, 1), (4, 1), (3, 1),
        (2, 4),
        (5, 2), (6, 1), (7, 1),
        (6, 2), (5, 2),
        (4, 1), (3, 1), (2, 1), (1, 1),
        (0, 3), (None, 1),
    ]
    tr.add(washint([(None if d is None else hz(d), l) for d, l in melody], beat), 2 * bar, 0.55)
    tr.add(drone(hz(-5), bars * bar), 0, 0.12)
    tr.add(drone(hz(-3), bars * bar), 0, 0.05)
    return tr.render(reverb=0.28)


# --------------------------------------------------------------------------
# Sound effects


def sfx_coin():
    a = krar(midi_to_hz(88), 0.12, bright=0.9)
    b = krar(midi_to_hz(93), 0.3, bright=0.9)
    y = np.zeros(int(0.32 * SR))
    y[: len(a)] += a * 0.7
    s = int(0.055 * SR)
    y[s : s + len(b)] += b[: len(y) - s]
    return y


def _pluck_run(degrees, root, spacing, length=0.35, bright=0.85, gain=0.55, scale=None):
    scale = scale or G_MAJOR_PENTA
    total = int((spacing * len(degrees) + length) * SR)
    y = np.zeros(total)
    for i, d in enumerate(degrees):
        k = krar(degree_hz(scale, root, d), length, bright=bright)
        s0 = int(i * spacing * SR)
        e = min(total, s0 + len(k))
        y[s0:e] += k[: e - s0] * gain
    return y


def sfx_jump():
    """Quick upward G-major flick plus a little air."""
    y = _pluck_run([0, 2, 4], TRACK_ROOT, 0.035, length=0.25)
    n = len(y)
    y += bandpass(RNG.standard_normal(n), 1500, 6000) * env_exp(n, 0.05) * 0.25
    return y


def sfx_super_jump():
    """Super-jump shoes: a springy two-octave sweep with a bassy boing."""
    y = _pluck_run([0, 1, 2, 3, 4, 5, 6, 7], TRACK_ROOT - 12, 0.03, length=0.3, gain=0.5)
    n = len(y)
    t = np.arange(n) / SR
    f = 70 + 160 * (1 - np.exp(-t / 0.08))
    y += np.sin(2 * np.pi * np.cumsum(f) / SR) * env_exp(n, 0.18) * 0.7
    return y


def sfx_roll():
    """Downward G-major tumble over a whoosh."""
    n = int(0.32 * SR)
    noise = RNG.standard_normal(n)
    w = np.zeros(n)
    for i in range(6):
        seg = slice(i * n // 6, (i + 1) * n // 6)
        w[seg] = bandpass(noise[seg], 300 + 1800 * (1 - i / 6), 900 + 2500 * (1 - i / 6))
    y = w * np.hanning(n) * 0.6
    p = _pluck_run([4, 2, 0], TRACK_ROOT - 12, 0.05, length=0.2, bright=0.6, gain=0.45)
    y[: len(p)] += p[:n]
    return y


def sfx_land():
    """Landing after flying: a soft kebero thump on G."""
    d = kebero_dum()
    n = int(0.4 * SR)
    y = d[:n] * 0.9
    k = krar(midi_to_hz(TRACK_ROOT - 24), 0.4, bright=0.4)
    y[: len(k)] += k[:n] * 0.4
    return y


def sfx_magnet():
    """Magnet on: shimmering, tremolo'd G-major arpeggio."""
    y = _pluck_run([5, 7, 9, 7, 9, 12], TRACK_ROOT, 0.045, length=0.4, bright=1.0, gain=0.4)
    t = np.arange(len(y)) / SR
    return y * (0.7 + 0.3 * np.sin(2 * np.pi * 18 * t))


def sfx_fly():
    """Jetpack takeoff: a rising whoosh that blooms into a G major chord."""
    n = int(1.2 * SR)
    t = np.arange(n) / SR
    noise = RNG.standard_normal(n)
    whoosh = np.zeros(n)
    for i in range(10):
        seg = slice(i * n // 10, (i + 1) * n // 10)
        whoosh[seg] = bandpass(noise[seg], 200 + 250 * i, 600 + 600 * i)
    y = whoosh * np.minimum(1, t / 0.4) * env_exp(n, 0.6) * 0.6
    chord = _pluck_run([0, 2, 4, 5], TRACK_ROOT, 0.02, length=0.8, gain=0.35)
    s0 = int(0.35 * SR)
    y[s0 : s0 + len(chord)] += chord[: n - s0]
    return y


def sfx_swipe():
    n = int(0.12 * SR)
    return bandpass(RNG.standard_normal(n), 2000, 7000) * np.hanning(n) * 0.5


def sfx_crash():
    y = np.zeros(int(0.7 * SR))
    d = kebero_dum()
    y[: len(d)] += d
    n = len(y)
    y += lowpass(RNG.standard_normal(n), 2500) * env_exp(n, 0.12) * 0.8
    t = np.arange(n) / SR
    f = 420 * np.exp(-t / 0.25) + 70
    y += np.sin(2 * np.pi * np.cumsum(f) / SR) * env_exp(n, 0.25) * 0.4
    return y


def sfx_powerup():
    y = np.zeros(int(0.7 * SR))
    for i, d in enumerate([0, 1, 2, 3, 4, 5]):
        k = krar(degree_hz(G_MAJOR_PENTA, TRACK_ROOT, d), 0.4, bright=0.85)
        s = int(i * 0.06 * SR)
        e = min(len(y), s + len(k))
        y[s:e] += k[: e - s] * 0.6
    return y


def sfx_gem():
    n = int(0.9 * SR)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for ratio, g, tau in [(1, 1, 0.5), (2.76, 0.5, 0.25), (5.4, 0.25, 0.12), (8.9, 0.1, 0.06)]:
        y += g * np.sin(2 * np.pi * 1568 * ratio * t) * env_exp(n, tau)
    return y * 0.6


def sfx_letter():
    y = np.zeros(int(0.6 * SR))
    for d in (0, 2, 4):
        k = krar(degree_hz(BATI_MAJOR, 67, d), 0.6, bright=0.8)
        y[: len(k)] += k * 0.4
    return y


def sfx_shield_break():
    n = int(0.6 * SR)
    t = np.arange(n) / SR
    y = highpass(RNG.standard_normal(n), 3000) * env_exp(n, 0.08) * 0.6
    f = 2600 * np.exp(-t / 0.2) + 400
    y += np.sin(2 * np.pi * np.cumsum(f) / SR) * env_exp(n, 0.2) * 0.5
    return y


def sfx_mission():
    y = np.zeros(int(1.2 * SR))
    for i, d in enumerate([0, 2, 4, 5, 7]):
        k = krar(degree_hz(TEZETA_MAJOR, 67, d), 0.7, bright=0.8)
        s = int(i * 0.09 * SR)
        y[s : s + len(k)] += k * 0.5
    dm = kebero_dum()
    s = int(0.45 * SR)
    y[s : s + len(dm)] += dm[: len(y) - s] * 0.6
    return y


def sfx_click():
    n = int(0.06 * SR)
    t = np.arange(n) / SR
    return np.sin(2 * np.pi * 1250 * t) * env_exp(n, 0.012) * 0.6


def sfx_tick():
    n = int(0.16 * SR)
    t = np.arange(n) / SR
    return np.sin(2 * np.pi * 880 * t) * env_exp(n, 0.06) * 0.6


def sfx_go():
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    return (np.sin(2 * np.pi * 1320 * t) + 0.3 * np.sin(2 * np.pi * 2640 * t)) * env_exp(n, 0.14) * 0.5


def sfx_jetpack():
    n = int(1.0 * SR)
    y = lowpass(RNG.standard_normal(n), 900) * 0.9 + bandpass(RNG.standard_normal(n), 2000, 6000) * 0.2
    envl = np.minimum(1, np.arange(n) / (0.05 * SR)) * env_exp(n, 0.5)
    return y * envl


def sfx_stumble():
    k = kebero_ka()
    n = int(0.25 * SR)
    y = np.zeros(n)
    y[: len(k)] += k * 0.8
    return y


def sfx_purchase():
    y = sfx_coin()
    z = np.zeros(int(0.5 * SR))
    z[: len(y)] += y
    k = krar(midi_to_hz(100), 0.3, bright=1.0)
    s = int(0.12 * SR)
    z[s : s + len(k)] += k * 0.5
    return z


def sfx_bleat():
    """Street goat: a buzzy, wobbly "meeeh"."""
    n = int(0.55 * SR)
    t = np.arange(n) / SR
    f = 520 * (1 - 0.18 * t / t[-1]) * (1 + 0.06 * np.sin(2 * np.pi * 11 * t))
    phase = 2 * np.pi * np.cumsum(f) / SR
    y = np.zeros(n)
    for k in range(1, 12):
        y += np.sin(k * phase) / k
    y = bandpass(y, 500, 2600) + 0.4 * bandpass(y, 2600, 3800)
    env = np.minimum(1, t / 0.04) * np.minimum(1, (t[-1] - t) / 0.12)
    return y * env


def sfx_spin_tick():
    n = int(0.04 * SR)
    t = np.arange(n) / SR
    return (np.sin(2 * np.pi * 2200 * t) * env_exp(n, 0.006)
            + bandpass(RNG.standard_normal(n), 2000, 6000) * env_exp(n, 0.004) * 0.5)


def sfx_box_open():
    y = np.zeros(int(1.0 * SR))
    n = int(0.25 * SR)
    whoosh = bandpass(RNG.standard_normal(n), 400, 3000) * np.hanning(n)
    y[:n] += whoosh * 0.6
    for i, d in enumerate([0, 2, 4, 5, 7, 9]):
        k = krar(degree_hz(BATI_MAJOR, 72, d), 0.5, bright=0.9)
        s = int((0.2 + i * 0.05) * SR)
        e = min(len(y), s + len(k))
        y[s:e] += k[: e - s] * 0.45
    return y


def sfx_flower():
    a = krar(midi_to_hz(84), 0.25, bright=0.7)
    b = krar(midi_to_hz(91), 0.35, bright=0.7)
    y = np.zeros(int(0.4 * SR))
    y[: len(a)] += a * 0.5
    s = int(0.04 * SR)
    y[s : s + len(b)] += b[: len(y) - s] * 0.6
    return y


def normalise(y, peak=0.85):
    y = np.asarray(y, dtype=float)
    return y / (np.max(np.abs(y)) + 1e-9) * peak


def main():
    import sys

    # The in-game soundtrack now comes from tools/process_music.py. The two
    # original qenet themes can still be rendered with --themes.
    if "--themes" in sys.argv:
        write_mp3(os.path.join(ROOT, "music", "merkato_run.mp3"), merkato_run(), "112k")
        write_mp3(os.path.join(ROOT, "music", "tezeta.mp3"), tezeta(), "112k")
    effects = {
        "coin": sfx_coin, "jump": sfx_jump, "roll": sfx_roll, "swipe": sfx_swipe,
        "crash": sfx_crash, "powerup": sfx_powerup, "gem": sfx_gem, "letter": sfx_letter,
        "shield_break": sfx_shield_break, "mission": sfx_mission, "click": sfx_click,
        "tick": sfx_tick, "go": sfx_go, "jetpack": sfx_jetpack, "stumble": sfx_stumble,
        "purchase": sfx_purchase, "bleat": sfx_bleat, "spin_tick": sfx_spin_tick,
        "box_open": sfx_box_open, "flower": sfx_flower, "super_jump": sfx_super_jump,
        "land": sfx_land, "magnet": sfx_magnet, "fly": sfx_fly,
    }
    for name, fn in effects.items():
        write_mp3(os.path.join(ROOT, "sfx", f"{name}.mp3"), normalise(fn()), "96k")


if __name__ == "__main__":
    main()
