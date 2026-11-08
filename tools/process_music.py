#!/usr/bin/env python3
"""Turns the main soundtrack (tools/source/addis_groove_source.mp3) into the
game's adaptive music:

  music/groove.m4a          gameplay loop (seamless, cut on a bar line)
  music/groove_menu.m4a     muffled "from the next room" version for menus
  music/groove_magnet.m4a   shimmering phaser version while the magnet is on
  music/groove_shoes.m4a    heavy, punchy bass version for super-jump shoes
  music/groove_fly.m4a      airy, echoing "in the clouds" version for flying
  sfx/tape_stop.mp3         the song grinding to a halt, played on a crash

All variants share the exact same timeline, so the game can crossfade between
them in time with the beat.

    pip install numpy librosa && python3 tools/process_music.py   (needs ffmpeg)
"""

from __future__ import annotations

import os
import subprocess
import tempfile

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "source", "addis_groove_source.mp3")
OUT = os.path.join(HERE, "..", "assets", "audio")
SR = 44100


def ffmpeg(*args):
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *args], check=True)


def load(path: str) -> np.ndarray:
    raw = subprocess.run(
        ["ffmpeg", "-loglevel", "error", "-i", path, "-vn", "-ac", "2", "-ar", str(SR),
         "-f", "f32le", "-"],
        capture_output=True, check=True,
    ).stdout
    return np.frombuffer(raw, np.float32).reshape(-1, 2).copy()


def save_wav(path: str, y: np.ndarray):
    import wave

    pcm = (np.clip(y, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(y.shape[1])
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def find_loop(y: np.ndarray) -> tuple[int, int]:
    """Returns (loop_end_sample, crossfade_samples).

    The loop point is chosen from detected beat times so that the end of the
    loop sits at the same position in the beat (and bar) as the very start
    of the song: end = beat[j] - beat[0], with j a whole number of bars.
    """
    import librosa

    mono = y.mean(axis=1)
    _, beats = librosa.beat.beat_track(y=mono, sr=SR)
    bt = librosa.frames_to_time(beats, sr=SR)
    period = float(np.median(np.diff(bt)))
    xfade = 4 * period  # one bar
    duration = len(y) / SR
    best = None
    for j in range(len(bt) - 1, 0, -1):
        end = bt[j] - bt[0]
        if j % 4 == 0 and end + xfade + 0.1 < duration:
            best = end
            break
    assert best is not None
    print(f"tempo {60 / period:.1f} bpm, first beat {bt[0]:.2f}s, loop {best:.2f}s, "
          f"crossfade {xfade:.2f}s")
    return int(best * SR), int(xfade * SR)


def make_loop(y: np.ndarray) -> np.ndarray:
    end, xf = find_loop(y)
    out = y[:end].copy()
    fade = np.linspace(0, 1, xf)[:, None]
    # Blend the music that follows the loop point into the start, so that
    # end -> start sounds like the song simply continues.
    out[:xf] = out[:xf] * np.sqrt(fade) + y[end:end + xf] * np.sqrt(1 - fade)
    return out


def encode(src_wav: str, dst: str, filters: str | None, mono: bool, bitrate: str):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    af = (filters + "," if filters else "") + "loudnorm=I=-15:TP=-1.5:LRA=11"
    args = ["-i", src_wav, "-af", af, "-ar", str(SR)]
    if mono:
        args += ["-ac", "1"]
    args += ["-c:a", "aac", "-b:a", bitrate, "-movflags", "+faststart", dst]
    ffmpeg(*args)
    print(f"wrote {os.path.relpath(dst, OUT)} ({os.path.getsize(dst) // 1024} KB)")


def tape_stop(y: np.ndarray, start_s: float, length_s: float = 1.1) -> np.ndarray:
    """Varispeed slow-down to zero, like pulling the plug on a turntable."""
    n_out = int(length_s * SR)
    t = np.arange(n_out) / n_out
    rate = (1 - t) ** 1.6
    pos = start_s * SR + np.cumsum(rate)
    idx = np.clip(pos.astype(int), 0, len(y) - 2)
    frac = (pos - idx)[:, None]
    seg = y[idx] * (1 - frac) + y[idx + 1] * frac
    env = np.minimum(1, (1 - t) * 6)[:, None]
    return seg * env


def main():
    y = load(SRC)
    loop = make_loop(y)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "loop.wav")
        save_wav(wav, loop)
        music = os.path.join(OUT, "music")
        encode(wav, os.path.join(music, "groove.m4a"), None, mono=False, bitrate="128k")
        encode(wav, os.path.join(music, "groove_menu.m4a"),
               "lowpass=f=700,lowpass=f=900,aecho=0.8:0.6:40:0.25,volume=-2dB",
               mono=True, bitrate="64k")
        encode(wav, os.path.join(music, "groove_magnet.m4a"),
               "aphaser=in_gain=0.5:out_gain=0.9:delay=2.5:decay=0.55:speed=0.9:type=t,"
               "chorus=0.6:0.9:40|60:0.4|0.32:0.25|0.4:2|1.3,treble=g=5:f=5000",
               mono=True, bitrate="96k")
        encode(wav, os.path.join(music, "groove_shoes.m4a"),
               "bass=g=9:f=85:w=0.6,acompressor=threshold=-18dB:ratio=4:attack=5:release=120,"
               "treble=g=-2:f=7000",
               mono=True, bitrate="96k")
        encode(wav, os.path.join(music, "groove_fly.m4a"),
               "highpass=f=320,aecho=0.8:0.75:90|180|270:0.4|0.28|0.18,treble=g=4:f=6000",
               mono=True, bitrate="96k")
        stop = tape_stop(y, start_s=48.0)
        stop_wav = os.path.join(tmp, "stop.wav")
        save_wav(stop_wav, stop)
        dst = os.path.join(OUT, "sfx", "tape_stop.mp3")
        ffmpeg("-i", stop_wav, "-ac", "1", "-c:a", "libmp3lame", "-b:a", "96k", dst)
        print(f"wrote sfx/tape_stop.mp3 ({os.path.getsize(dst) // 1024} KB)")


if __name__ == "__main__":
    main()
