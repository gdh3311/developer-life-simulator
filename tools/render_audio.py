"""Render the original office score and Foley. Requires numpy, scipy and soundfile.

Run from any directory with python tools/render_audio.py.
The game ships the rendered assets and needs no Python audio dependencies.
"""

from pathlib import Path

import numpy as np
from scipy import signal
import soundfile as sf


OUT = Path(__file__).resolve().parents[1] / "audio"
RATE = 32_000
BAR = 8
LENGTH = BAR * 8
TAU = 2 * np.pi


def time(seconds):
    return np.arange(round(seconds * RATE)) / RATE


def hz(note):
    return 440 * 2 ** ((note - 69) / 12)


def noise(seconds, low, high, seed):
    white = np.random.default_rng(seed).standard_normal(round(seconds * RATE))
    band = signal.butter(2, (low, high), fs=RATE, btype="bandpass", output="sos")
    return signal.sosfilt(band, white)


def gates(t, ramp_in, ramp_out):
    return np.sin(np.pi / 2 * np.minimum(t / ramp_in, 1)) ** 2 * np.sin(
        np.pi / 2 * np.minimum((t[-1] - t) / ramp_out, 1)
    ) ** 2


def add(destination, wave, at, gain=1, pan=0, wrap=False):
    start = round(at * RATE) % len(destination)
    if destination.ndim == 2:
        wave = wave[:, None] * np.sqrt([(1 - pan) / 2, (1 + pan) / 2])
    first = min(len(wave), len(destination) - start)
    destination[start : start + first] += wave[:first] * gain
    if wrap and first < len(wave):
        destination[: len(wave) - first] += wave[first:] * gain


def felt(note, seconds, velocity, seed):
    """Muted hammer, detuned strings, and partials that decay at different rates."""
    t = time(seconds)
    f = hz(note)
    phase = np.random.default_rng(seed).uniform(-0.25, 0.25, size=7)
    wave = np.zeros_like(t)
    for k, level in enumerate((1, 0.36, 0.23, 0.11, 0.05, 0.03, 0.012), 1):
        partial = f * k * np.sqrt(1 + 0.00010 * k * k)
        carrier = TAU * partial * t + phase[k - 1]
        wave += level * (np.sin(carrier) + 0.48 * np.sin(carrier * 1.0019)) * np.exp(
            -t * (0.35 + 0.32 * k + f / 1500)
        )
    hammer = noise(seconds, 110, 1400, seed) * np.exp(-t * 125)
    return (wave + 0.42 * hammer) * velocity * gates(t, 0.012, 0.50)


def strings(note, seconds, seed, dark=False):
    """A slow, lightly bowed layer with independent drift and bow noise."""
    t = time(seconds)
    f = hz(note)
    drift = 0.32 * np.sin(TAU * 0.19 * t + seed) + 0.10 * np.sin(TAU * 0.43 * t)
    phase = TAU * f * t + drift
    wave = (0.64 * np.sin(phase) + 0.26 * np.sin(phase * 1.0024 + 0.6)
            + 0.19 * np.sin(2 * phase) + (0.06 if dark else 0.11) * np.sin(3.003 * phase))
    grain = noise(seconds, 280, 2100, seed) * 0.055
    movement = 0.84 + 0.16 * np.sin(TAU * 0.13 * t + seed)
    return (wave + grain) * movement * gates(t, 2.6, 3.3)


def room_reflections(wave, circular=False):
    wet = wave.copy()
    for milliseconds, amount in ((23, 0.085), (47, 0.07), (83, 0.054), (136, 0.036), (233, 0.028), (389, 0.016)):
        shift = round(milliseconds * RATE / 1000)
        if circular:
            wet += amount * np.roll(wave[:, ::-1], shift, axis=0)
        else:
            wet[shift:] += amount * wave[:-shift, ::-1]
    return wet


def write(name, wave, peak_db, loop=False):
    wave = wave * (10 ** (peak_db / 20) / np.max(np.abs(wave)))
    if loop:
        with sf.SoundFile(OUT / (name + ".ogg"), "w", RATE, 2, subtype="VORBIS") as output:
            for start in range(0, len(wave), 8192):
                output.write(wave[start : start + 8192].astype(np.float32))
    else:
        wave[-round(0.008 * RATE) :] *= np.linspace(1, 0, round(0.008 * RATE)).reshape(
            (-1,) + (1,) * (wave.ndim - 1)
        )
        sf.write(OUT / (name + ".wav"), wave, RATE, subtype="PCM_16")


def score():
    # Eight voiced D-minor bars. The three arrangements share position and harmony.
    harmony = [(38, 57, 64, 65), (36, 55, 62, 64), (34, 53, 60, 64), (43, 57, 62, 65),
               (38, 57, 64, 65), (41, 57, 60, 64), (34, 53, 60, 64), (45, 55, 58, 62)]
    theme = [(2.3, 62, .34), (5.9, 69, .19), (10.4, 67, .26), (15.1, 64, .22),
             (19.8, 60, .28), (23.4, 65, .21), (28.4, 62, .29), (34.0, 57, .26),
             (38.1, 64, .20), (43.0, 69, .25), (47.2, 65, .20), (51.1, 60, .25),
             (55.6, 64, .19), (60.4, 62, .25)]
    for mode, peak in (("focus", -12), ("incident", -12), ("calm", -13)):
        mix = np.zeros((LENGTH * RATE, 2))
        incident = mode == "incident"
        for index, voicing in enumerate(harmony):
            # Incident suspends resolutions with a low scrape. Calm leaves more space.
            notes = voicing if mode == "focus" else voicing[:3]
            for voice, note in enumerate(notes):
                amount = (0.14, 0.09, 0.055, 0.043)[voice]
                panning = (0.0, -0.60, 0.50, 0.27)[voice]
                add(mix, strings(note, 11.6, index * 9 + voice, incident),
                    index * BAR - 1.65, amount, panning, wrap=True)
            if incident:
                add(mix, strings(voicing[0] + 13, 10.2, 900 + index, True),
                    index * BAR + 0.8, 0.059, (-1) ** index * 0.50, wrap=True)
                t = time(2.9)
                swell = (np.sin(TAU * hz(voicing[0] + 12) * t) + 0.28 * np.sin(TAU * 72 * t))
                add(mix, swell * gates(t, 0.42, 2.4), index * BAR + 2.1, 0.054, wrap=True)
        for index, (at, note, velocity) in enumerate(theme):
            if mode == "calm" and index % 2:
                continue
            if incident and index % 3:
                continue
            shift = -12 if incident else 0
            amount = velocity * (0.76 if incident else 1.0)
            add(mix, felt(note + shift, 4.5, amount, index), at, pan=(-1) ** index * .21, wrap=True)
        write(mode, room_reflections(mix, circular=True), peak, loop=True)


def foley():
    t = time(18)
    common = noise(18, 75, 380, 87) * 0.21
    ventilation = np.sin(TAU * 118 * t) * 0.007 + np.sin(TAU * 164 * t) * 0.006
    room = np.column_stack([(common + ventilation + 0.06 * noise(18, 200, 1600, seed))
                            for seed in (123, 456)])
    room *= gates(t, 0.018, 0.018)[:, None]
    write("office", room, -28, loop=True)

    for index in range(8):
        heavy = index >= 6
        t = time(0.11)
        body = np.sin(TAU * (173 + index * 9 - (69 if heavy else 0)) * t) * np.exp(-t * 94)
        snap = noise(0.11, 1000, 3700, 100 + index) * np.exp(-t * 310)
        shell = noise(0.11, 220, 1550, 220 + index) * np.exp(-t * 97)
        release = np.roll(snap * 0.16, round((0.066 + index * 0.001) * RATE))
        write(f"key_{index + 1}", (body * .26 + snap * .44 + shell * .55 + release)
              * gates(t, .001, .01), -23 if heavy else -26)

    for index in range(3):
        t = time(0.30)
        sole = noise(0.30, 320, 2200, 61 + index) * np.exp(-t * 26)
        floor = noise(0.30, 45, 370, 41 + index) * np.exp(-t * 19)
        write(f"step_{index + 1}", (sole * 0.32 + floor) * gates(t, .011, .06), -16)

    # Short tactile sounds for ordinary actions rather than pitched confirmation jingles.
    for name, seconds, low, high, attack, decay, peak in (
        ("click", .052, 480, 2250, .0015, 105, -22),
        ("tick", .060, 400, 2500, .001, 90, -22),
        ("window", .165, 180, 1500, .013, 30, -21),
        ("commit", .12, 160, 1600, .004, 50, -20),
        ("push", .245, 230, 1350, .025, 22, -20),
        ("send", .18, 270, 1700, .016, 26, -21),
        ("power", .46, 75, 850, .025, 11, -18),
        ("relief", .62, 210, 920, .065, 9, -24),
    ):
        t = time(seconds)
        write(name, noise(seconds, low, high, round(high)) * np.exp(-t * decay)
              * gates(t, attack, .035), peak)


def cues():
    # Simultaneous felt voicings instead of ascending rewards and descending failure sweeps.
    for name, seconds, notes, peak in (
        ("message", .40, [(0, 66, .30)], -21),
        ("notify", .45, [(0, 61, .27), (.016, 68, .10)], -22),
        ("tests_ok", .55, [(0, 60, .27), (.019, 64, .14)], -18),
        ("tests_fail", .54, [(0, 49, .31), (.024, 58, .14)], -17),
        ("success", .82, [(0, 57, .37), (.025, 64, .21)], -16),
        ("fail", .81, [(0, 45, .36), (.018, 53, .21)], -16),
        ("merged", 1.65, [(0, 50, .29), (.032, 57, .24), (.060, 64, .17)], -14),
        ("promote", 3.00, [(0, 38, .20), (.044, 57, .22), (.115, 64, .15), (.66, 65, .13)], -13),
        ("purchase", .61, [(0, 60, .22), (.032, 67, .10)], -20),
        ("boot", 1.60, [(0, 45, .28), (.06, 52, .16), (.19, 59, .09)], -17),
        ("morning", 2.35, [(0, 50, .22), (.05, 57, .18), (.41, 64, .12)], -17),
        ("evening", 2.10, [(0, 50, .22), (.048, 57, .19), (.10, 65, .12)], -17),
        ("busted", 1.36, [(0, 40, .30), (.034, 53, .19)], -14),
    ):
        mix = np.zeros((round(seconds * RATE), 2))
        for index, (at, note, amount) in enumerate(notes):
            duration = seconds - at - .035
            add(mix, felt(note, duration, amount, index + 310), at, pan=(-1) ** index * .18)
        write(name, room_reflections(mix), peak)

    t = time(1.08)
    pulse = np.zeros_like(t)
    for start, weight in ((0, 1), (.21, .46), (.57, .78), (.75, .40)):
        tt = time(.27)
        impulse = (np.sin(TAU * 57 * tt) + 0.22 * np.sin(TAU * 103 * tt)) * np.exp(-tt * 22)
        add(pulse, impulse * gates(tt, .024, .045), start, weight)
    write("heart", pulse, -20)


if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    score()
    foley()
    cues()
    print(f"Rendered the office audio into {OUT}")
