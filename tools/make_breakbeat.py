#!/usr/bin/env python3
"""Original 200 BPM synthetic breakbeat. No copyrighted samples. Requires numpy.
Regenerate with: python3 -m pip install numpy && python3 tools/make_breakbeat.py
The generated WAV is already included; Python is NOT needed to play.
"""
from pathlib import Path
import wave
import numpy as np

SR = 22050
BPM = 200
BEAT = 60 / BPM
BARS = 32
rng = np.random.default_rng(7721)
audio = np.zeros((int(BARS * 4 * BEAT * SR), 2))


def mix(sample, beat, gain=1.0, pan=0.0):
    start = int(beat * BEAT * SR)
    if start >= len(audio):
        return
    n = min(len(sample), len(audio) - start)
    audio[start:start+n, 0] += sample[:n] * gain * (1 - pan * 0.45)
    audio[start:start+n, 1] += sample[:n] * gain * (1 + pan * 0.45)


def kick():
    t = np.arange(int(SR * .23)) / SR
    phase = np.cumsum(48 + 130 * np.exp(-t * 40)) * 2 * np.pi / SR
    return np.tanh(np.sin(phase) * 2.5) * np.exp(-t * 22) * .75


def snare():
    t = np.arange(int(SR * .2)) / SR
    n = rng.uniform(-1, 1, len(t))
    n = n - np.roll(n, 1) * .6
    return (n * .6 * np.exp(-t * 25) + np.sin(2 * np.pi * 185 * t) * np.exp(-t * 38) * .4)


def hat(open_hat=False):
    t = np.arange(int(SR * (.14 if open_hat else .055))) / SR
    n = rng.uniform(-1, 1, len(t))
    return (n - np.roll(n, 1)) * np.exp(-t * (35 if open_hat else 90)) * .14


k, s = kick(), snare()
for bar in range(BARS):
    base = bar * 4
    pattern = bar % 8
    for b in [0, 1.75, 2.5] + ([3.25] if pattern in [2, 5, 7] else []):
        mix(k, base + b, .95)
    for b in [1, 3]:
        mix(s, base + b, 1.0)
    for b in [.75, 2.25, 2.75, 3.5]:
        if rng.random() > .25:
            mix(s[::2] if pattern > 3 else s, base + b, rng.uniform(.2, .45), rng.uniform(-.6, .6))
    for step in range(16):
        mix(hat(step % 8 == 6), base + step / 4, .65 if step % 2 else 1, (-1 if step % 2 else 1) * .6)
    if pattern in [3, 7]:
        for step in range(8 if pattern == 7 else 4):
            mix(s[::2], base + 3 + step / 8, .6 + step * .035, (-1) ** step * .8)
    # Reese-style bass and a sparse minor-key arpeggio, all synthesized here.
    root = [41.203, 41.203, 48.999, 43.654][(bar // 2) % 4]
    for b in [0, 1.5, 2.5, 3.5]:
        t = np.arange(int(SR * .13)) / SR
        bass = np.sin(2*np.pi*root*t) + .28*np.sin(2*np.pi*root*2.01*t)
        bass = np.tanh(bass * 2) * np.minimum(t*180, 1) * np.exp(-t*13)
        mix(bass, base+b, .31)
    for step in range(8):
        t = np.arange(int(SR * .12)) / SR
        note = root * 8 * 2 ** ([0, 7, 12, 3, 10, 7, 3, 0][step] / 12)
        lead = np.sin(2*np.pi*note*t) + .2*np.sin(2*np.pi*note*2*t)
        lead *= np.minimum(t*250, 1) * np.exp(-t*35)
        mix(lead, base + step / 2, .11 if bar % 8 < 4 else .17, np.sin(step))
        mix(lead, base + step / 2 + .75, .04, -np.sin(step))

# Soft limiting and tiny boundary fades make the loop safe and click-free.
audio = np.tanh(audio * 1.15) * .82
fade = min(180, len(audio))
audio[:fade] *= np.linspace(0, 1, fade)[:, None]
audio[-fade:] *= np.linspace(1, 0, fade)[:, None]
out = Path(__file__).resolve().parents[1] / "assets/music/fallback.wav"
with wave.open(str(out), "wb") as f:
    f.setnchannels(2)
    f.setsampwidth(2)
    f.setframerate(SR)
    f.writeframes((audio * 32767).astype('<i2').tobytes())
print(f"Created {out.name}: {len(audio)/SR:.1f}s / {BPM} BPM / {out.stat().st_size:,} bytes")
