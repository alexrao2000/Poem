"""Original weapon and elemental release sounds, independent of the paired score."""
from pathlib import Path
import wave
import numpy as np

SR = 22050


def air(t, seed, smooth=1):
    noise = np.random.default_rng(seed).uniform(-1, 1, len(t))
    if smooth > 1:
        noise = np.convolve(noise, np.ones(smooth)/smooth, mode="same")
    return noise


def render():
    sounds = {}
    # The blade is light and bright; the heavier axe has a broader low sweep.
    for name, duration, hz, sweep, smooth, seed in [
        ("sword", .18, 830, -1900, 2, 8101),
        ("axe", .27, 190, -280, 9, 8102),
        ("lance", .14, 1150, -2600, 3, 8103),
    ]:
        t = np.arange(round(duration*SR))/SR
        envelope = np.sin(np.pi*t/duration)**2
        sounds[name] = (air(t, seed, smooth)*.36 +
                        np.sin(2*np.pi*(hz*t+sweep*t*t))*.055)*envelope
    t = np.arange(round(.24*SR))/SR
    # A plucked string with a brief wooden attack; no continuing arrow whistle.
    sounds["bow"] = sum(gain*np.sin(2*np.pi*hz*t)*np.exp(-decay*t)
                        for hz, gain, decay in [(275,.18,27),(561,.10,39),(1087,.05,61)])
    sounds["bow"] += air(t, 8104, 3)*.18*np.exp(-t*180)
    t = np.arange(round(.30*SR))/SR
    sounds["ember"] = (air(t, 8105, 5)*.34 + .065*np.sin(2*np.pi*(170*t-100*t*t)))*np.sin(np.pi*t/.30)**1.4
    t = np.arange(round(.34*SR))/SR
    sounds["gale"] = (air(t, 8106, 2)*.24 + .06*np.sin(2*np.pi*(610*t+930*t*t)))*np.sin(np.pi*t/.34)**2
    t = np.arange(round(.26*SR))/SR
    # Inharmonic strikes and three brief noise cracks make a dry electrical snap.
    sounds["thunder"] = sum(gain*np.sin(2*np.pi*hz*t)*np.exp(-decay*t)
                            for hz,gain,decay in [(523,.10,22),(1487,.07,35),(2831,.05,48)])
    crack = sum(np.exp(-np.maximum(t-offset,0)*240)*(t>=offset)
                for offset in [0,.024,.055])
    sounds["thunder"] += air(t, 8107)*.27*crack
    for name, sound in sounds.items():
        t = np.arange(len(sound))/SR
        # Smooth boundaries and remove DC without normalizing quiet and loud cues alike.
        envelope = np.clip(t/.002,0,1)*np.clip((t[-1]-t)/.018,0,1)
        sound = (sound-sound.mean())*envelope
        sound -= envelope*(sound.sum()/envelope.sum())
        sounds[name] = sound
    return sounds


if __name__ == "__main__":
    for name, sound in render().items():
        assert np.max(np.abs(sound)) < .5 and abs(sound.mean()) < .0001
        assert sound[0] == sound[-1] == 0
        target = Path(__file__).resolve().parent.parent / "assets/audio" / f"release_{name}.wav"
        with wave.open(str(target), "wb") as stream:
            stream.setparams((1,2,SR,0,"NONE","not compressed"))
            stream.writeframes(np.round(sound*32767).astype("<i2").tobytes())
        print(f"{name}: {len(sound)/SR:.3f}s, peak {np.max(np.abs(sound)):.3f}, RMS {np.sqrt(np.mean(sound**2)):.3f}")
