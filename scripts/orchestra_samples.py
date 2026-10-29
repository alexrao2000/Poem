"""Small offline sampler for the original paired score; runtime needs no samples.

Source pitches come from the upstream SFZ mappings, which use different octave
labels for harp and other instruments. Mono reduction, a low-pass filter before
resampling, and note envelopes keep the rendered bank small and deterministic.
"""
from functools import lru_cache
import hashlib
import json
from pathlib import Path
import wave
import numpy as np

ROOT = Path(__file__).resolve().parent.parent


class OrchestraSamples:
    def __init__(self, sample_rate=22050):
        self.sample_rate = sample_rate
        self.manifest = json.loads((ROOT / 'assets/audio/orchestra-sources.json').read_text())
        self.cache = ROOT / '.tools/vsco'
        self.groups = {}
        for entry in self.manifest['samples']:
            self.groups.setdefault(entry['instrument'], []).append(entry)
            if not (self.cache / entry['path']).is_file():
                raise FileNotFoundError('Run python3 scripts/fetch_score_samples.py before rendering the orchestral score.')

    @lru_cache(maxsize=40)
    def load(self, path, expected_hash):
        source = self.cache / path
        blob = source.read_bytes()
        digest = hashlib.sha1(b'blob ' + str(len(blob)).encode() + b'\0' + blob).hexdigest()
        if digest != expected_hash:
            raise ValueError('Unverified recording: ' + path)
        with wave.open(str(source)) as audio:
            rate = audio.getframerate(); channels = audio.getnchannels(); width = audio.getsampwidth()
            raw = audio.readframes(audio.getnframes())
        if width == 3:
            packed = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3).astype(np.int32)
            values = packed[:, 0] | (packed[:, 1] << 8) | (packed[:, 2] << 16)
            values = ((values ^ 0x800000) - 0x800000) / 8388608.0
        elif width in (2, 4):
            values = np.frombuffer(raw, dtype='<i2' if width == 2 else '<i4').astype(np.float64) / (2**(width*8-1))
        else:
            raise ValueError('Unsupported recording format: ' + path)
        values = values.reshape(-1, channels).mean(axis=1)
        energy = np.convolve(np.abs(values), np.ones(256)/256, mode='same')
        onset = np.flatnonzero(energy > energy.max()*.06)
        if not len(onset):
            raise ValueError('Silent recording: ' + path)
        values = values[max(0, int(onset[0])-round(rate*.01)):]
        cutoff = min(.46, .42*self.sample_rate/(rate*1.5))
        axis = np.arange(-31, 32)
        kernel = 2*cutoff*np.sinc(2*cutoff*axis)*np.hamming(63)
        values = np.convolve(values, kernel/kernel.sum(), mode='same')
        peak = np.max(np.abs(values)); rms = np.sqrt(np.mean(values[:rate*3]**2))
        values *= min(.8/max(peak, 1e-9), .22/max(rms, 1e-9))
        return values, rate

    def render(self, midi, seconds, instrument, velocity=1):
        entries = self.groups.get(instrument)
        if not entries:
            return None
        entry = min(entries, key=lambda item: abs(midi-item['root']))
        values, rate = self.load(entry['path'], entry['git_blob'])
        count = max(1, round(seconds*self.sample_rate))
        positions = np.arange(count)*(rate/self.sample_rate)*2**((midi-entry['root'])/12)
        output = np.interp(positions, np.arange(len(values)), values, left=0, right=0)
        t = np.arange(count)/self.sample_rate
        attack = .004 if instrument == 'harp' else .025 if instrument == 'flute' else .045
        release = min(seconds*.35, .14 if instrument in ('strings', 'horn') else .08)
        envelope = np.minimum(1, t/attack)*np.minimum(1, np.maximum(0, (seconds-t)/max(release, .001)))
        return output*envelope*velocity
