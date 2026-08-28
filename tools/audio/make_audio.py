#!/usr/bin/env python3
"""Generate every sound in the game.

There are no sample libraries in this project and there will not be. Everything
here is built from `synth.py` and committed as a WAV, so the whole soundtrack is
regenerable from source and CI can assert that the committed files really are
this script's output.

Two rules run through all of it:

**Loops are periodic by construction, not by crossfade.** Every tonal loop is
LOOP_SECONDS long and every frequency in it is a whole multiple of
1/LOOP_SECONDS, so the last sample joins the first exactly. A loop point that
lands mid-cycle is a click, and in a room this quiet a click is the loudest
thing in the mix. Only noise, which cannot be made periodic, is crossfaded.

**Amplitudes are physical first and normalised last.** Each generator is written
in whatever units its physics wanted and scaled to a peak at the end, so a
change to one partial does not silently rebalance the rest.

Usage: python3 tools/audio/make_audio.py [--out assets/audio]
"""
from __future__ import annotations

import argparse
import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from synth import (  # noqa: E402
    Rng, cycles, envelope, fade_loop, impulse_train, mix, modal, noise,
    one_pole_high, one_pole_low, resonator, silence, sine,
)
from wav import normalise, write_mono16  # noqa: E402

RATE = 22050
LOOP_SECONDS = 16.0
LOOP_FRAMES = int(RATE * LOOP_SECONDS)
# Every frequency in a loop must be a whole multiple of this.
GRID_HZ = 1.0 / LOOP_SECONDS


def snap(freq: float) -> float:
    """Nearest frequency that completes whole cycles inside the loop."""
    return max(GRID_HZ, round(freq / GRID_HZ) * GRID_HZ)


def tremolo(frames: int, rate: int, hz: float, depth: float) -> list[float]:
    lfo = sine(frames, rate, snap(hz))
    return [1.0 - depth * 0.5 * (1.0 - v) for v in lfo]


def apply(samples: list[float], gain_curve: list[float]) -> list[float]:
    return [s * g for s, g in zip(samples, gain_curve)]


# --- score ------------------------------------------------------------------
# Four layers, crossfaded by the fear number (src/core/fear_state.gd). Each is
# complete on its own: the mix is not a build-up, it is four rooms the same
# space can be in.

def score_bed() -> list[float]:
    """Always present. Below where a phone speaker can reproduce it, on purpose:
    on a speaker it is felt as absence and on headphones it is the floor."""
    out = silence(LOOP_FRAMES)
    mix(out, sine(LOOP_FRAMES, RATE, snap(38.5)), 1.0)
    mix(out, sine(LOOP_FRAMES, RATE, snap(57.75)), 0.42)
    mix(out, sine(LOOP_FRAMES, RATE, snap(77.0)), 0.14)
    out = apply(out, tremolo(LOOP_FRAMES, RATE, 0.0625, 0.35))
    rumble = one_pole_low(noise(LOOP_FRAMES + 4410, Rng(11)), RATE, 55.0)
    mix(out, fade_loop(rumble, RATE, 0.2), 0.5)
    return normalise(out, 0.55)


def score_room() -> list[float]:
    """Enters early. Two partials half a hertz apart, so the layer beats once
    every two seconds and the room seems to breathe without anything moving."""
    out = silence(LOOP_FRAMES)
    mix(out, sine(LOOP_FRAMES, RATE, snap(110.0)), 1.0)
    mix(out, sine(LOOP_FRAMES, RATE, snap(110.5)), 0.95)
    mix(out, sine(LOOP_FRAMES, RATE, snap(220.0)), 0.18)
    body = resonator(noise(LOOP_FRAMES + 4410, Rng(23)), RATE, 165.0, 6.0)
    mix(out, fade_loop(body, RATE, 0.2), 0.8)
    return normalise(out, 0.5)


def score_strain() -> list[float]:
    """Struck metal, sustained rather than struck: the same inharmonic ratios a
    plate rings at, held. It is the building's own material, bowed."""
    out = silence(LOOP_FRAMES)
    root = 146.25
    for ratio, gain, wobble in (
        (1.0, 1.0, 0.125), (2.76, 0.5, 0.1875), (5.404, 0.28, 0.25),
        (8.933, 0.16, 0.3125), (13.34, 0.09, 0.375),
    ):
        partial = sine(LOOP_FRAMES, RATE, snap(root * ratio))
        mix(out, apply(partial, tremolo(LOOP_FRAMES, RATE, wobble, 0.6)), gain)
    return normalise(out, 0.42)


def score_edge() -> list[float]:
    """The top layer, and the quietest. High, thin, and only ever heard as the
    feeling that something in the room has changed pitch."""
    out = silence(LOOP_FRAMES)
    for freq, gain, wobble in ((2196.0, 1.0, 0.1875), (2933.0, 0.4, 0.25), (4392.0, 0.16, 0.3125)):
        partial = sine(LOOP_FRAMES, RATE, snap(freq))
        mix(out, apply(partial, tremolo(LOOP_FRAMES, RATE, wobble, 0.85)), gain)
    return normalise(out, 0.3)


# --- ambience and machinery -------------------------------------------------

def amb_powerhouse() -> list[float]:
    """Room tone. Broadband under 400 Hz plus mains hum -- 60 Hz and its second
    harmonic, because this is the United States in 1998 and the building is
    still energised."""
    tail = 6615
    bed = one_pole_low(noise(LOOP_FRAMES + tail, Rng(37)), RATE, 380.0)
    out = fade_loop(bed, RATE, 0.3)[:LOOP_FRAMES]
    while len(out) < LOOP_FRAMES:
        out.append(0.0)
    mix(out, sine(LOOP_FRAMES, RATE, snap(60.0)), 0.16)
    mix(out, sine(LOOP_FRAMES, RATE, snap(120.0)), 0.08)
    return normalise(out, 0.34)


def amb_water() -> list[float]:
    """Moving water in the drain gallery. Broadband with formants that wander:
    three resonators whose gains are on slow, unrelated LFOs, which is what a
    body of water sounds like without needing a body of water."""
    source = noise(LOOP_FRAMES + 6615, Rng(53))
    out = silence(LOOP_FRAMES)
    for freq, q, gain, wobble in (
        (420.0, 3.0, 1.0, 0.0625), (980.0, 4.5, 0.7, 0.125), (2100.0, 6.0, 0.45, 0.1875)
    ):
        band = fade_loop(resonator(source, RATE, freq, q), RATE, 0.3)[:LOOP_FRAMES]
        mix(out, apply(band, tremolo(LOOP_FRAMES, RATE, wobble, 0.7)), gain)
    mix(out, one_pole_low(fade_loop(source, RATE, 0.3)[:LOOP_FRAMES], RATE, 140.0), 0.6)
    return normalise(out, 0.45)


def mach_ballast() -> list[float]:
    """The bulkhead lamp's ballast. Twice line frequency with a tired second
    harmonic and a little buzz, which is what a forty-year-old magnetic ballast
    in a damp fitting does."""
    out = silence(LOOP_FRAMES)
    mix(out, sine(LOOP_FRAMES, RATE, snap(120.0)), 1.0)
    mix(out, sine(LOOP_FRAMES, RATE, snap(240.0)), 0.34)
    mix(out, sine(LOOP_FRAMES, RATE, snap(360.0)), 0.09)
    buzz = resonator(noise(LOOP_FRAMES + 4410, Rng(67)), RATE, 1240.0, 12.0)
    mix(out, fade_loop(buzz, RATE, 0.2), 0.5)
    return normalise(out, 0.6)


def mach_gallery() -> list[float]:
    """Distant plant, heard through concrete. An impulse train at shaft speed
    through a room-sized resonator, then everything above a few hundred hertz
    taken off, because that is what concrete does to a machine two rooms away."""
    train = impulse_train(LOOP_FRAMES + 4410, RATE, 14.6875, 0.06, Rng(83))
    body = resonator(train, RATE, 62.0, 9.0)
    body = one_pole_low(body, RATE, 260.0)
    out = fade_loop(body, RATE, 0.25)[:LOOP_FRAMES]
    while len(out) < LOOP_FRAMES:
        out.append(0.0)
    mix(out, one_pole_low(fade_loop(noise(LOOP_FRAMES + 4410, Rng(89)), RATE, 0.25)[:LOOP_FRAMES], RATE, 90.0), 0.5)
    return normalise(out, 0.4)


# --- one-shots --------------------------------------------------------------

def metal_door() -> list[float]:
    """A bulkhead dog coming free. Low, long, and inharmonic."""
    frames = int(RATE * 2.2)
    out = modal(frames, RATE, [
        (78.0, 1.9, 1.0), (188.0, 1.2, 0.62), (326.0, 0.8, 0.4),
        (538.0, 0.5, 0.24), (788.0, 0.3, 0.12),
    ])
    strike = apply(noise(frames, Rng(101)), envelope(frames, RATE, 0.0005, 0.012))
    mix(out, one_pole_high(strike, RATE, 600.0), 0.5)
    return normalise(out, 0.85)


def metal_wrench() -> list[float]:
    """The dog wrench engaging. Short, bright, and over before it is heard."""
    frames = int(RATE * 0.55)
    out = modal(frames, RATE, [
        (640.0, 0.22, 1.0), (1766.0, 0.14, 0.5), (3456.0, 0.08, 0.24), (5712.0, 0.04, 0.1),
    ])
    strike = apply(noise(frames, Rng(103)), envelope(frames, RATE, 0.0003, 0.006))
    mix(out, strike, 0.4)
    return normalise(out, 0.8)


def click_breaker() -> list[float]:
    """A breaker closing. The most important sound in Act 1: it is the first
    thing the player makes happen."""
    frames = int(RATE * 0.4)
    out = modal(frames, RATE, [(1180.0, 0.09, 1.0), (2740.0, 0.05, 0.45), (4100.0, 0.03, 0.2)])
    snap_noise = apply(noise(frames, Rng(107)), envelope(frames, RATE, 0.0002, 0.004))
    mix(out, one_pole_high(snap_noise, RATE, 900.0), 0.7)
    mix(out, modal(frames, RATE, [(96.0, 0.16, 1.0)]), 0.35)
    return normalise(out, 0.9)


def bell_admit() -> list[float]:
    """The shelter admit bell. A 1962 civil-defense fitting: a small steel gong
    struck by a solenoid, not a chime. Inharmonic and short, and the most
    important sound in Act 1 because somebody answers it."""
    frames = int(RATE * 2.6)
    out = modal(frames, RATE, [
        (523.0, 1.9, 1.0), (1310.0, 1.1, 0.55), (2270.0, 0.6, 0.3),
        (3480.0, 0.32, 0.16), (4980.0, 0.18, 0.08),
    ])
    strike = apply(noise(frames, Rng(109)), envelope(frames, RATE, 0.0004, 0.008))
    mix(out, one_pole_high(strike, RATE, 1400.0), 0.45)
    return normalise(out, 0.85)


def step(seed: int, kind: str) -> list[float]:
    """A footstep. Concrete is a damped thud with grit on it; grating is the
    same impact plus a ringing plate, because that is the difference."""
    frames = int(RATE * (0.45 if kind == "grating" else 0.28))
    rng = Rng(seed)
    body = resonator(
        apply(noise(frames, rng), envelope(frames, RATE, 0.0008, 0.035)),
        RATE, 170.0 + rng.next_float() * 40.0, 3.0,
    )
    out = list(body)
    grit = apply(noise(frames, Rng(seed + 1)), envelope(frames, RATE, 0.0004, 0.014))
    mix(out, one_pole_high(grit, RATE, 2200.0), 0.35)
    if kind == "grating":
        root = 1360.0 + rng.next_float() * 180.0
        mix(out, modal(frames, RATE, [
            (root, 0.18, 1.0), (root * 2.41, 0.11, 0.42), (root * 4.18, 0.06, 0.18),
        ]), 0.55)
    return normalise(out, 0.7)


# --- manifest ---------------------------------------------------------------
# name -> (builder, loops)

SOUNDS: dict = {
    "score_bed": (score_bed, True),
    "score_room": (score_room, True),
    "score_strain": (score_strain, True),
    "score_edge": (score_edge, True),
    "amb_powerhouse": (amb_powerhouse, True),
    "amb_water": (amb_water, True),
    "mach_ballast": (mach_ballast, True),
    "mach_gallery": (mach_gallery, True),
    "metal_door": (metal_door, False),
    "metal_wrench": (metal_wrench, False),
    "click_breaker": (click_breaker, False),
    "bell_admit": (bell_admit, False),
    "step_concrete_1": (lambda: step(211, "concrete"), False),
    "step_concrete_2": (lambda: step(223, "concrete"), False),
    "step_concrete_3": (lambda: step(227, "concrete"), False),
    "step_grating_1": (lambda: step(229, "grating"), False),
    "step_grating_2": (lambda: step(233, "grating"), False),
    "step_grating_3": (lambda: step(239, "grating"), False),
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="assets/audio")
    args = parser.parse_args()
    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    total = 0
    for name, (build, loops) in SOUNDS.items():
        samples = build()
        path = out / f"{name}.wav"
        write_mono16(path, RATE, samples)
        size = path.stat().st_size
        total += size
        seconds = len(samples) / RATE
        print(f"  {name:<20} {seconds:>6.2f}s  {size:>9,} B  {'loop' if loops else 'one-shot'}")
    print(f"\n{len(SOUNDS)} files, {total / 1048576:.2f} MB of source WAV")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
