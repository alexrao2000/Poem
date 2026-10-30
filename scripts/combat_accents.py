"""Original combat and progression accents; regenerate without touching the paired score."""
import argparse
from pathlib import Path
import wave
import numpy as np


def guard(sample_rate=22050):
    t = np.arange(round(.22 * sample_rate)) / sample_rate
    # Inharmonic modes and a short attack suggest steel contact without a bass hit.
    modes = [(970, .30, 30), (1567, .19, 39), (2671, .10, 52), (4640, .05, 95)]
    sound = sum(gain * np.sin(2 * np.pi * hz * t) * np.exp(-t * decay)
                for hz, gain, decay in modes)
    return sound * (1 - np.exp(-t * 1800))


def cutin(sample_rate=22050):
    t = np.arange(round(.32 * sample_rate)) / sample_rate
    # A brief rising air stroke resolves into a small bright, inharmonic chime.
    envelope = np.sin(np.pi * np.minimum(t / .10, 1)) ** 2
    noise = np.random.default_rng(61823).uniform(-1, 1, len(t))
    air = (noise * .09 + np.sin(2 * np.pi * (540*t + 7000*t*t)) * .14) * envelope
    dt = np.maximum(t - .065, 0)
    chime = sum(gain * np.sin(2*np.pi*hz*dt) * np.exp(-dt*decay)
                for hz, gain, decay in [(1430, .14, 23), (2277, .07, 29), (3521, .03, 38)])
    return (air + chime) * np.clip((.32-t)/.035, 0, 1)


def levelup(sample_rate=22050):
    t = np.arange(round(.72 * sample_rate)) / sample_rate
    sound = np.zeros_like(t)
    # An original four-note ascending bell figure, with short soft attacks.
    for offset, hz in [(0, 659.255), (.095, 783.991), (.19, 987.767), (.285, 1318.51)]:
        dt = np.maximum(t-offset, 0)
        envelope = (1-np.exp(-dt*500))*np.exp(-dt*10)*(t>=offset)
        sound += (.15*np.sin(2*np.pi*hz*dt)+.035*np.sin(2*np.pi*hz*2.71*dt))*envelope
    return sound*np.clip((.72-t)/.06, 0, 1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--effect", choices=["guard", "cutin", "levelup", "all"], default="all")
    args = parser.parse_args()
    for name, generate in {"guard": guard, "cutin": cutin, "levelup": levelup}.items():
        if args.effect not in [name, "all"]:
            continue
        output = Path(__file__).resolve().parent.parent / f"assets/audio/{name}.wav"
        sound = generate()
        with wave.open(str(output), "wb") as stream:
            stream.setparams((1, 2, 22050, 0, "NONE", "not compressed"))
            stream.writeframes((np.clip(sound, -.9, .9) * 32767).astype("<i2").tobytes())
        print(f"Wrote {output.name}: {len(sound)/22050:.2f}s, original synthesized accent")
