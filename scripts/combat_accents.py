"""Original metallic guard accent; may be regenerated without touching the score."""
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


if __name__ == "__main__":
    output = Path(__file__).resolve().parent.parent / "assets/audio/guard.wav"
    with wave.open(str(output), "wb") as stream:
        stream.setparams((1, 2, 22050, 0, "NONE", "not compressed"))
        stream.writeframes((guard() * 32767).astype("<i2").tobytes())
    print(f"Wrote {output.name}: 220 ms, original synthesized steel accent")
