"""Original quiet foot/hoof contacts for soft ground, stone and timber."""
from pathlib import Path
import wave
import numpy as np

SR = 22050


def render():
    sounds = {}
    for mounted in [False, True]:
        for material, seed, smooth, ring in [
            ("soft", 8401, 7, 108), ("hard", 8402, 2, 430),
            ("wood", 8403, 4, 218),
        ]:
            duration = .15 if mounted else .10
            t = np.arange(round(duration * SR)) / SR
            rng = np.random.default_rng(seed + (10 if mounted else 0))
            noise = np.convolve(rng.uniform(-1, 1, len(t)),
                                np.ones(smooth) / smooth, mode="same")
            result = np.zeros_like(t)
            for delay, gain in ([(0, 1), (.047, .72)] if mounted else [(0, 1)]):
                age = np.maximum(t - delay, 0)
                gate = t >= delay
                click = noise * np.exp(-age * (95 if mounted else 68))
                body = np.sin(2 * np.pi * ring * age) * np.exp(-age * 85)
                upper = np.sin(2 * np.pi * ring * 2.13 * age) * np.exp(-age * 125)
                attack = np.clip(age / .0015, 0, 1)
                result += gate * attack * gain * (click * .16 + body * .055 + upper * .025)
            envelope = np.clip(t / .0015, 0, 1) * np.clip((t[-1] - t) / .015, 0, 1)
            result = (result - result.mean()) * envelope
            result -= envelope * (result.sum() / envelope.sum())
            sounds[("hoof" if mounted else "foot") + "_" + material] = result
    return sounds


if __name__ == "__main__":
    for name, sound in render().items():
        assert np.max(np.abs(sound)) < .2 and abs(sound.mean()) < .0001
        assert sound[0] == sound[-1] == 0
        target = Path(__file__).resolve().parent.parent / "assets/audio" / f"step_{name}.wav"
        with wave.open(str(target), "wb") as stream:
            stream.setparams((1, 2, SR, 0, "NONE", "not compressed"))
            stream.writeframes(np.round(sound * 32767).astype("<i2").tobytes())
        print(f"{name}: {len(sound)/SR:.3f}s, peak {np.max(np.abs(sound)):.3f}")
