"""Render three original, short interface tones without touching campaign music."""
from pathlib import Path
import wave
import numpy as np

SR = 22050


def pluck(midi, seconds, gain):
    t = np.arange(round(seconds * SR)) / SR
    hz = 440 * 2 ** ((midi - 69) / 12)
    envelope = np.minimum(1, t / .003) * np.clip((seconds - t) / .015, 0, 1)
    sound = (np.sin(2*np.pi*hz*t) + .18*np.sin(2*np.pi*hz*2*t)*np.exp(-t*70)
             + .07*np.sin(2*np.pi*hz*3*t)*np.exp(-t*110))
    result = sound * envelope * np.exp(-t*22) * gain
    result[0] = result[-1] = 0
    return result


def render():
    result = {"ui_move": pluck(81, .045, .14)}
    for name, notes, duration in [
        ("ui_confirm", [(0, 81), (.035, 86)], .145),
        ("ui_back", [(0, 77), (.035, 74)], .115),
    ]:
        sound = np.zeros(round(duration * SR))
        for offset, midi in notes:
            start = round(offset * SR)
            note = pluck(midi, duration - offset, .13)
            length = min(len(note), len(sound) - start)
            sound[start:start+length] += note[:length]
        result[name] = sound
    return result


if __name__ == "__main__":
    for name, sound in render().items():
        assert np.max(np.abs(sound)) < .22 and abs(sound.mean()) < .001
        assert sound[0] == sound[-1] == 0
        target = Path(__file__).resolve().parent.parent / "assets/audio" / f"{name}.wav"
        with wave.open(str(target), "wb") as stream:
            stream.setparams((1, 2, SR, 0, "NONE", "not compressed"))
            stream.writeframes(np.round(sound * 32767).astype("<i2").tobytes())
        print(f"{name}: {len(sound)/SR:.3f}s, peak {np.max(np.abs(sound)):.3f}, RMS {np.sqrt(np.mean(sound**2)):.3f}")
