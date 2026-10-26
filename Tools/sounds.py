#!/usr/bin/env python3
"""Synthesize the game's sound effects into Vowelless/Vowelless/Resources/Sounds (16-bit mono WAV).

Run from the repository root: python3 Tools/sounds.py
Everything is generated from simple tones, so there are no third-party audio files or licenses.
"""
import math, random, struct, wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "Vowelless/Vowelless/Resources/Sounds"


def tone(freq, length, volume=0.5, attack=0.004, decay=None, harmonics=(1.0, 0.35, 0.15), slide=None, shape="sine"):
    """One note: a few harmonics with a quick attack and an exponential decay. `slide` glides to a frequency."""
    n = int(RATE * length)
    decay = decay or length / 4
    out, phase = [], 0.0
    for i in range(n):
        t = i / RATE
        f = freq if slide is None else freq + (slide - freq) * (i / n)
        phase += 2 * math.pi * f / RATE
        if shape == "square":
            v = sum(a * (1 if math.sin(phase * (k + 1)) >= 0 else -1) for k, a in enumerate(harmonics)) * 0.5
        elif shape == "triangle":
            v = sum(a * (2 / math.pi) * math.asin(math.sin(phase * (k + 1))) for k, a in enumerate(harmonics))
        else:
            v = sum(a * math.sin(phase * (k + 1)) for k, a in enumerate(harmonics))
        env = min(1.0, t / attack) * math.exp(-t / decay)
        out.append(v * env * volume)
    return out


def silence(length):
    return [0.0] * int(RATE * length)


def noise(length, volume=0.3, decay=0.01):
    rng = random.Random(7)
    return [rng.uniform(-1, 1) * volume * math.exp(-(i / RATE) / decay) for i in range(int(RATE * length))]


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]


def seq(*parts, gap=0.0):
    out = []
    for p in parts:
        out += p + silence(gap)
    return out


def write(name, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = min(1.0, 0.9 / peak)
    # Short fade-out so nothing clicks at the end.
    fade = int(RATE * 0.01)
    for i in range(1, min(fade, len(samples)) + 1):
        samples[-i] *= i / fade
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767)) for s in samples))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    C5, E5, G5, C6, E6, G6 = 523.25, 659.25, 783.99, 1046.5, 1318.5, 1568.0

    # Button press: a soft wooden "tok".
    write("tap", mix(noise(0.03, 0.25, 0.004), tone(900, 0.06, 0.4, decay=0.012, harmonics=(1, 0.2))))
    # Right answer: a bright rising arpeggio.
    write("correct", seq(tone(C6, 0.09, decay=0.06), tone(E6, 0.09, decay=0.06), tone(G6, 0.32, decay=0.12)))
    # Wrong answer: two soft low "bonk"s.
    write("wrong", seq(tone(240, 0.11, 0.45, decay=0.05, shape="triangle"), tone(180, 0.18, 0.45, decay=0.07, shape="triangle"), gap=0.02))
    # Hint card or vowel popping in.
    write("pop", tone(520, 0.11, 0.5, decay=0.05, slide=1250, harmonics=(1, 0.25)))
    # Coins: the classic two-note "bling".
    write("coin", seq(tone(988, 0.07, 0.45, decay=0.05, shape="square", harmonics=(1, 0.2)),
                      tone(1319, 0.32, 0.45, decay=0.12, shape="square", harmonics=(1, 0.2))))
    # Last seconds of a race clue.
    write("tick", tone(1700, 0.04, 0.35, decay=0.008, harmonics=(1,)))
    # Answer revealed after giving up: a gentle shimmer.
    write("reveal", mix(tone(660, 0.35, 0.25, slide=1320, decay=0.15), tone(990, 0.35, 0.15, slide=1980, decay=0.15)))
    # Round or race won.
    write("fanfare", seq(tone(C5, 0.11), tone(E5, 0.11), tone(G5, 0.11), mix(tone(C6, 0.6, decay=0.25), tone(E6, 0.6, 0.25, decay=0.25))))
    # Opponent took the point, or a race lost.
    write("lose", seq(tone(G5 / 2 * 1.0, 0.16, 0.4, decay=0.1, shape="triangle"),
                      tone(E5 / 2, 0.16, 0.4, decay=0.1, shape="triangle"),
                      tone(C5 / 2, 0.4, 0.4, decay=0.2, shape="triangle")))
    print("Wrote", len(list(OUT.glob("*.wav"))), "sounds to", OUT)


if __name__ == "__main__":
    main()
