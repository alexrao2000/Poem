"""Original elemental contact sounds; synthesis never changes the paired score."""
from pathlib import Path
import argparse
import wave
import numpy as np

SR = 22050


def noise(count, seed, smooth=1):
    signal = np.random.default_rng(seed).uniform(-1, 1, count)
    return np.convolve(signal, np.ones(smooth)/smooth, mode="same") if smooth > 1 else signal


def render():
    sounds = {}
    t = np.arange(round(.42*SR))/SR
    # A brief low pressure pulse opens into a dry, quieter fire crackle.
    pressure = np.sin(2*np.pi*(125*t-80*t*t))*.24*np.exp(-t*22)
    crackle = noise(len(t), 9111, 3)*.33*np.exp(-t*10)
    body = noise(len(t), 9112, 19)*.22*np.exp(-t*17)
    sounds["ember"] = pressure+crackle+body
    t = np.arange(round(.38*SR))/SR
    # Filtered air and a falling resonant edge distinguish wind from a metal hit.
    air = noise(len(t), 9113, 4)-noise(len(t), 9113, 37)
    gust = air*.48*np.exp(-t*12)*(1+.18*np.sin(2*np.pi*43*t))
    edge = np.sin(2*np.pi*(980*t-890*t*t))*.065*np.exp(-t*17)
    sounds["gale"] = gust+edge
    t = np.arange(round(.48*SR))/SR
    # One electrical crack, then short inharmonic body and a fading rumble.
    crack = noise(len(t), 9114)*.34*np.exp(-t*70)
    ring = sum(gain*np.sin(2*np.pi*hz*t)*np.exp(-decay*t)
               for hz, gain, decay in [(97,.13,16),(163,.08,21),(457,.055,27),(1823,.045,48)])
    rumble = noise(len(t), 9115, 25)*.24*np.exp(-t*11)
    sounds["thunder"] = crack+ring+rumble
    for name, sound in sounds.items():
        t = np.arange(len(sound))/SR
        envelope = np.clip(t/.0015,0,1)*np.clip((t[-1]-t)/.025,0,1)
        sound = (sound-sound.mean())*envelope
        sound -= envelope*(sound.sum()/envelope.sum())
        assert np.max(np.abs(sound)) < .6 and abs(sound.mean()) < .0001
        assert sound[0] == sound[-1] == 0
        sounds[name] = sound
    return sounds


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=Path(__file__).resolve().parent.parent/"assets/audio")
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for name, sound in render().items():
        with wave.open(str(args.output_dir/f"impact_{name}.wav"), "wb") as stream:
            stream.setparams((1,2,SR,0,"NONE","not compressed"))
            stream.writeframes(np.round(sound*32767).astype("<i2").tobytes())
        print(f"{name}: {len(sound)/SR:.3f}s, peak {np.max(np.abs(sound)):.3f}, RMS {np.sqrt(np.mean(sound**2)):.3f}")
