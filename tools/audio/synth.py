"""The synthesis toolkit. Pure Python, deterministic, no dependencies.

Everything the game hears is built from what is in this file. There are no
sample libraries in this project and there will not be: `docs/DECISIONS.md` D3
and the repository rules forbid them, and more usefully, a facility that has to
sound like *one* building is easier to build than to license.

Three families, matching what the story asks for:

  metal      modal synthesis -- a struck plate is a sum of decaying sinusoids
             at inharmonic ratios, and that is not an approximation, it is what
             a plate does
  water      filtered noise with a slow-moving resonance, because moving water
             is broadband with a formant that wanders
  machinery  a periodic impulse train through a resonator, which is what a
             rotating machine in a concrete room actually is
"""
from __future__ import annotations

import math

TAU = math.tau


class Rng:
    """A named, seeded LCG. `random` would do, but a generator whose output has
    to be byte-identical across Python versions cannot use a stdlib PRNG whose
    internals are free to change."""

    def __init__(self, seed: int) -> None:
        self.state = (seed ^ 0x2545F491) & 0xFFFFFFFF

    def next_float(self) -> float:
        self.state = (self.state * 1664525 + 1013904223) & 0xFFFFFFFF
        return self.state / 4294967296.0

    def bipolar(self) -> float:
        return self.next_float() * 2.0 - 1.0


def silence(frames: int) -> list[float]:
    return [0.0] * frames


def mix(into: list[float], source: list[float], gain: float = 1.0, at: int = 0) -> None:
    limit = min(len(into) - at, len(source))
    for i in range(limit):
        into[at + i] += source[i] * gain


# --- filters ----------------------------------------------------------------

def one_pole_low(samples: list[float], rate: int, cutoff: float) -> list[float]:
    a = math.exp(-TAU * cutoff / rate)
    out = [0.0] * len(samples)
    state = 0.0
    for i, s in enumerate(samples):
        state = s * (1.0 - a) + state * a
        out[i] = state
    return out


def one_pole_high(samples: list[float], rate: int, cutoff: float) -> list[float]:
    low = one_pole_low(samples, rate, cutoff)
    return [s - l for s, l in zip(samples, low)]


def resonator(samples: list[float], rate: int, freq: float, q: float) -> list[float]:
    """A two-pole band-pass. The building block for both machinery and water:
    machinery is an impulse train through one of these, water is noise through
    several that move."""
    w = TAU * freq / rate
    r = math.exp(-w / (2.0 * max(q, 0.01)))
    a1 = 2.0 * r * math.cos(w)
    a2 = -r * r
    gain = (1.0 - r) * math.sqrt(max(1.0 - 2.0 * r * math.cos(2.0 * w) + r * r, 1e-9))
    out = [0.0] * len(samples)
    y1 = y2 = 0.0
    for i, s in enumerate(samples):
        y = gain * s + a1 * y1 + a2 * y2
        out[i] = y
        y2, y1 = y1, y
    return out


# --- sources ----------------------------------------------------------------

def noise(frames: int, rng: Rng) -> list[float]:
    return [rng.bipolar() for _ in range(frames)]


def sine(frames: int, rate: int, freq: float, phase: float = 0.0) -> list[float]:
    step = TAU * freq / rate
    return [math.sin(phase + step * i) for i in range(frames)]


def cycles(rate: int, freq: float, whole_cycles: int) -> int:
    """Frame count holding exactly `whole_cycles` of `freq`. Every loop in this
    game is built this way, because a loop point that lands mid-cycle is a click
    and no amount of crossfading hides it in a quiet room."""
    return max(2, int(round(rate * whole_cycles / freq)))


def modal(frames: int, rate: int, modes: list[tuple[float, float, float]]) -> list[float]:
    """Struck metal. `modes` are (frequency, decay seconds, amplitude).

    A plate or a pipe rings at frequencies that are not harmonics of anything;
    the ratios below in the generators come from that, which is why struck steel
    does not sound like a struck string however the envelope is shaped."""
    out = [0.0] * frames
    for freq, decay, amp in modes:
        step = TAU * freq / rate
        damp = math.exp(-1.0 / max(decay * rate, 1.0))
        level = amp
        for i in range(frames):
            out[i] += math.sin(step * i) * level
            level *= damp
            if level < 1e-5:
                break
    return out


def impulse_train(frames: int, rate: int, rate_hz: float, jitter: float, rng: Rng) -> list[float]:
    """Machinery. A rotating thing is a periodic impulse; the jitter is what
    stops it sounding like a synthesiser and what a worn bearing sounds like."""
    out = [0.0] * frames
    period = rate / max(rate_hz, 0.01)
    position = 0.0
    while position < frames:
        index = int(position)
        if 0 <= index < frames:
            out[index] += 1.0
        position += period * (1.0 + jitter * rng.bipolar())
    return out


def fade_loop(samples: list[float], rate: int, seconds: float) -> list[float]:
    """Crossfades a buffer's tail into its head so it loops without a seam.

    Used only where the material cannot be made periodic by construction --
    noise, mostly. Anything tonal uses `cycles()` instead, which is exact."""
    n = min(int(rate * seconds), len(samples) // 2)
    if n <= 1:
        return samples
    out = list(samples[:-n])
    for i in range(n):
        t = i / n
        out[i] = samples[i] * t + samples[len(samples) - n + i] * (1.0 - t)
    return out


def envelope(frames: int, rate: int, attack: float, decay: float) -> list[float]:
    a = max(1, int(attack * rate))
    out = [0.0] * frames
    for i in range(frames):
        if i < a:
            out[i] = i / a
        else:
            out[i] = math.exp(-(i - a) / max(decay * rate, 1.0))
    return out
