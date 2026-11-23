#!/usr/bin/env python3
"""Synthesize seamless stereo ambience beds for the campaign battlefields."""

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

    # Whole cycles keep the swell continuous at the loop point.
    swells = np.sin(PHASES * profile["swells"] - .75)
    secondary = np.sin(PHASES + .2)
    envelope = 1 + profile["depth"] * (.74 * swells + .26 * secondary)
    painted *= envelope[:, None]
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
