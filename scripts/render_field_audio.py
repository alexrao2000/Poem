#!/usr/bin/env python3
"""Synthesize seamless stereo ambience beds for the campaign battlefields.

Whole-cycle swells cross the loop boundary. Brief, windowed stereo accents
fade well before it.
"""

import argparse
from pathlib import Path
import wave

import numpy as np


RATE = 22050
FRAMES = RATE * 8
FREQUENCIES = np.fft.rfftfreq(FRAMES, 1 / RATE)
PHASES = np.arange(FRAMES) * (2 * np.pi / FRAMES)
PROFILES = {
    "river": {
        "seed": 31393,
        "bands": [(100, 730, .73), (480, 2350, .27)],
        "swells": 3,
        "depth": .15,
        "spread": .29,
        "rms": .078,
    },
    "forest": {
        "seed": 76261,
        "bands": [(220, 1050, .31), (880, 3950, .69)],
        "swells": 2,
        "depth": .11,
        "spread": .36,
        "rms": .078,
    },
    "harbor": {
        "seed": 61871,
        "bands": [(55, 345, .78), (310, 1810, .22)],
        "swells": 2,
        "depth": .48,
        "spread": .26,
        "rms": .074,
    },
    "road": {
        "seed": 47732,
        "bands": [(118, 388, .44), (370, 870, .38), (790, 1770, .18)],
        "swells": 2,
        "depth": .26,
        "spread": .33,
        "rms": .048,
    },
    "mountain": {
        "seed": 54281,
        "bands": [(83, 365, .61), (330, 1460, .33), (1410, 3100, .06)],
        "swells": 2,
        "depth": .45,
        "spread": .42,
        "rms": .067,
    },
    "furnace": {
        "seed": 84913,
        "bands": [(40, 165, .64), (150, 550, .23), (750, 2350, .13)],
        "swells": 3,
        "depth": .28,
        "spread": .25,
        "rms": .057,
    },
    "engine": {
        "seed": 58109,
        "bands": [(46, 114, .55), (101, 268, .31), (305, 882, .14)],
        "swells": 8,
        "depth": .34,
        "spread": .30,
        "rms": .051,
    },
    "abbey": {
        "seed": 16365,
        "bands": [(90, 184, .54), (352, 632, .32), (752, 1270, .14)],
        "swells": 1,
        "depth": .18,
        "spread": .19,
        "rms": .044,
    },
    "village": {
        "seed": 90137,
        "bands": [(155, 420, .49), (460, 1210, .39), (1150, 2750, .12)],
        "swells": 1,
        "depth": .23,
        "spread": .36,
        "rms": .035,
        "calls": [
            (1.09, .13, 1900, 425, .10, -.57),
            (1.29, .16, 2210, -620, .078, -.52),
            (4.67, .11, 1640, 510, .063, .49),
            (4.83, .17, 2120, -530, .079, .52),
        ],
    },
    "aqueduct": {
        "seed": 74093,
        "bands": [(178, 580, .33), (625, 2080, .51), (1890, 4180, .16)],
        "swells": 4,
        "depth": .22,
        "spread": .46,
        "rms": .054,
        "calls": [
            (.44, .071, 1040, -720, .054, .43),
            (1.91, .069, 870, -410, .060, -.34),
            (2.27, .057, 1300, -590, .044, .40),
            (3.60, .085, 990, -435, .052, -.48),
            (5.28, .066, 1380, -720, .046, .36),
            (6.64, .081, 940, -580, .060, -.23),
            (7.04, .075, 1090, -590, .049, .44),
        ],
    },
    "observatory": {
        "seed": 64811,
        "bands": [(52, 154, .64), (292, 442, .25), (1270, 1760, .11)],
        "swells": 1,
        "depth": .25,
        "spread": .22,
        "rms": .035,
    },
    "castle": {
        "seed": 82531,
        "bands": [(116, 320, .54), (420, 980, .27), (1590, 3690, .19)],
        "swells": 3,
        "depth": .34,
        "spread": .42,
        "rms": .043,
        "rustles": [
            (.61, .28, 670, 1460, .062, .51),
            (2.50, .19, 840, 2800, .070, -.53),
            (4.84, .44, 590, 1880, .064, .39),
            (6.34, .26, 750, 2240, .074, -.56),
        ],
    },
}


def band_noise(random, low, high):
    spectrum = np.fft.rfft(random.standard_normal(FRAMES))
    safe_frequency = np.maximum(FREQUENCIES, 1)
    band = 1 / np.sqrt((1 + (low / safe_frequency) ** 6)
                       * (1 + (FREQUENCIES / high) ** 8))
    spectrum *= band
    spectrum[0] = 0
    samples = np.fft.irfft(spectrum, n=FRAMES)
    return samples / np.sqrt(np.mean(samples ** 2))


def render(profile):
    random = np.random.default_rng(profile["seed"])
    painted = np.zeros((FRAMES, 2))
    for low, high, strength in profile["bands"]:
        center = band_noise(random, low, high)
        for channel in range(2):
            side = band_noise(random, low, high)
            painted[:, channel] += strength * (center + profile["spread"] * side)

    swells = np.sin(PHASES * profile["swells"] - .75)
    secondary = np.sin(PHASES + .2)
    envelope = 1 + profile["depth"] * (.74 * swells + .26 * secondary)
    painted *= envelope[:, None]
    for start, duration, frequency, bend, strength, pan in profile.get("calls", ()):
        first = round(start * RATE)
        elapsed = np.arange(round(duration * RATE)) / RATE
        progress = elapsed / duration
        phase = 2 * np.pi * elapsed * (frequency + .5 * bend * progress)
        call = (np.sin(phase) + .18 * np.sin(phase * 2.01))
        phrase = strength * call * np.sin(np.pi * progress) ** 2
        stereo = np.sqrt(np.array([1 - pan, 1 + pan]) * .5)
        painted[first:first + len(phrase)] += phrase[:, None] * stereo
    for start, duration, low, high, strength, pan in profile.get("rustles", ()):
        first = round(start * RATE)
        count = round(duration * RATE)
        noise = band_noise(random, low, high)[first:first + count]
        window = np.sin(np.pi * np.arange(count) / count) ** 2
        stereo = np.sqrt(np.array([1 - pan, 1 + pan]) * .5)
        painted[first:first + count] += (strength * noise * window)[:, None] * stereo

    painted -= painted.mean(axis=0)
    painted *= profile["rms"] / np.sqrt(np.mean(painted ** 2))
    return np.rint(painted * 32767).astype("<i2")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path,
                        default=Path(__file__).resolve().parents[1] / "assets/audio")
    destination = parser.parse_args().output
    destination.mkdir(parents=True, exist_ok=True)
    for field, profile in PROFILES.items():
        samples = render(profile)
        path = destination / f"field-{field}.wav"
        with wave.open(str(path), "wb") as stream:
            stream.setnchannels(2)
            stream.setsampwidth(2)
            stream.setframerate(RATE)
            stream.writeframes(samples.tobytes())
        print(path)


if __name__ == "__main__":
    main()
