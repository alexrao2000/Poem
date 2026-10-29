"""Offline source-bank and final score checks; requires NumPy and cached samples."""
import json
from pathlib import Path
import sys
import wave
import numpy as np

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'scripts'))
from orchestra_samples import OrchestraSamples

bank = OrchestraSamples()
for instrument, entries in bank.groups.items():
    for entry in entries:
        source, rate = bank.load(entry['path'], entry['git_blob'])
        assert rate >= 22050 and len(source) > rate
        assert np.isfinite(source).all() and np.max(np.abs(source)) <= .801
    for pitch in [48, 60, 72, 81]:
        note = bank.render(pitch, .8, instrument)
        assert len(note) == 17640 and np.isfinite(note).all()
        assert np.max(np.abs(note)) > .005 and abs(note[0]) < 1e-9 and abs(note[-1]) < .002
assert bank.render(60, 1, 'unknown') is None
manifest = bank.manifest
assert next(e['root'] for e in manifest['samples'] if e['path'].endswith('KSHarp_C5_mf.wav')) == 72, 'Harp octave labels differ from other instruments'
tracks = {}
for name in ['calm', 'ablaze']:
    with wave.open(str(ROOT / 'assets' / f'{name}.wav')) as audio:
        assert (audio.getnchannels(), audio.getsampwidth(), audio.getframerate(), audio.getnframes()) == (2, 2, 22050, 1568000)
        data = np.frombuffer(audio.readframes(audio.getnframes()), dtype='<i2').reshape(-1, 2)/32768
    assert np.max(np.abs(data)) <= .9, 'Headroom prevents clipping'
    assert .08 < np.sqrt(np.mean(data**2)) < .17, 'Both arrangements have usable level'
    assert np.max(np.abs(data[0]-data[-1])) < .03, 'No abrupt step at the wrap seam'
    assert np.max(np.abs(data.mean(axis=0))) < .005, 'No material DC offset'
    tracks[name] = data
assert np.mean(np.abs(tracks['calm']-tracks['ablaze'])) > .025, 'Ablaze is a distinct arrangement'
score = json.loads((ROOT / 'assets/audio/score.json').read_text())
assert score['frames'] == 1568000 and 'CC0' in score['samples']
print('PASS: 33 verified orchestral recordings, source pitch mappings, note envelopes, stereo timelines, headroom and loop seams')
