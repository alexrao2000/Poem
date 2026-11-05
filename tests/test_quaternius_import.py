"""Offline source-asset checks; no archive downloads or rendered-game claims."""
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import struct
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('assembler', ROOT / 'scripts/import_quaternius.py')
assembler = importlib.util.module_from_spec(spec)
spec.loader.exec_module(assembler)
ASSETS = ROOT / 'assets/models/quaternius'


class QuaterniusImport(unittest.TestCase):
    def test_rest_rotation_delta(self):
        h = math.sqrt(.5)
        source, target, delta = (h, 0, 0, h), (0, h, 0, h), (0, 0, h, h)
        actual = assembler.remap_rotation(assembler.quat_product(source, delta), source, target)
        expected = assembler.quat_product(target, delta)
        for a, b in zip(actual, expected):
            self.assertAlmostEqual(a, b)
        for a, b in zip(assembler.remap_rotation(source, source, target), target):
            self.assertAlmostEqual(a, b)

    def test_import_settings_preserve_existing_metadata(self):
        with tempfile.TemporaryDirectory() as folder:
            image = Path(folder) / 'source.png'
            settings = Path(str(image) + '.import')
            assembler.texture_import(image)
            text = settings.read_text().replace('[params]', '[params]\ncompress/mode=0')
            settings.write_text(text)
            assembler.texture_import(image)
            first = settings.read_bytes()
            assembler.texture_import(image)
            self.assertEqual(first, settings.read_bytes())
            self.assertIn(b'compress/mode=0', first)
            self.assertIn(b'process/size_limit=1024', first)
            self.assertIn(b'mipmaps/generate=true', first)

    def test_local_source_images_and_licenses(self):
        provenance = json.loads((ASSETS / 'provenance.json').read_text())
        self.assertEqual(provenance['license'], 'CC0 1.0 Universal')
        self.assertEqual(set(provenance['sources']), {'base', 'outfits', 'animations'})
        for name in provenance['sources']:
            self.assertIn('CC0 1.0 Universal', (ASSETS / 'licenses' / (name + '.txt')).read_text())
        for path in (ASSETS / 'textures').glob('*.png'):
            self.assertEqual(path.name.split('-')[0], hashlib.sha256(path.read_bytes()).hexdigest()[:16])
            settings = Path(str(path) + '.import').read_text()
            self.assertIn('process/size_limit=1024', settings)
            self.assertIn('mipmaps/generate=true', settings)

    def test_compact_rigs_and_animation_data(self):
        for gender in ['female', 'male']:
            with self.subTest(gender=gender):
                data = json.loads((ASSETS / ('duelist_' + gender + '.gltf')).read_text())
                raw = (ASSETS / data['buffers'][0]['uri']).read_bytes()
                self.assertEqual(len(raw), data['buffers'][0]['byteLength'])
                self.assertLess(len(raw), 2_800_000)
                used = set()

                def values(index):
                    used.add(index)
                    a = data['accessors'][index]
                    v = data['bufferViews'][a['bufferView']]
                    code, width = assembler.COMPONENTS[a['componentType']]
                    count = assembler.WIDTHS[a['type']]
                    size = a['count'] * width * count
                    self.assertEqual(size, v['byteLength'])
                    self.assertLessEqual(v['byteOffset'] + size, len(raw))
                    result = list(struct.iter_unpack('<' + code * count, raw[v['byteOffset']:v['byteOffset'] + size]))
                    self.assertTrue(all(math.isfinite(x) for row in result for x in row))
                    return result

                self.assertEqual(len(data['meshes']), 8)
                self.assertEqual(len(data['skins']), 3)
                for skin in data['skins']:
                    self.assertEqual(len(skin['joints']), 65)
                    self.assertEqual(len(values(skin['inverseBindMatrices'])), 65)
                    self.assertEqual(len(set(skin['joints'])), 65)
                for mesh in data['meshes']:
                    for primitive in mesh['primitives']:
                        attrs = {key: values(index) for key, index in primitive['attributes'].items()}
                        count = len(attrs['POSITION'])
                        self.assertTrue(all(len(rows) == count for rows in attrs.values()))
                        indices = values(primitive['indices'])
                        self.assertEqual(len(indices) % 3, 0)
                        self.assertTrue(all(0 <= row[0] < count for row in indices))
                        self.assertTrue(all(abs(sum(row) - 1) < .0001 for row in attrs['WEIGHTS_0']))
                        self.assertTrue(all(0 <= x < 65 for row in attrs['JOINTS_0'] for x in row))
                        for key in attrs:
                            if key.startswith('COLOR_'):
                                self.assertTrue(data['accessors'][primitive['attributes'][key]]['normalized'])
                self.assertEqual({a['name'] for a in data['animations']}, assembler.CLIPS)
                for animation in data['animations']:
                    self.assertEqual(len(animation['channels']), 195)
                    for channel in animation['channels']:
                        sampler = animation['samplers'][channel['sampler']]
                        times = [row[0] for row in values(sampler['input'])]
                        output = values(sampler['output'])
                        self.assertEqual(len(times), len(output))
                        self.assertTrue(all(a < b for a, b in zip(times, times[1:])))
                        self.assertGreaterEqual(times[0], 0)
                        if channel['target']['path'] == 'rotation':
                            self.assertTrue(all(abs(sum(x*x for x in row) - 1) < .0001 for row in output))
                self.assertEqual(used, set(range(len(data['accessors']))), 'No unused source buffers survive compaction')
                for image in data['images']:
                    self.assertTrue((ASSETS / image['uri']).is_file())
                    self.assertNotIn('..', image['uri'])


if __name__ == '__main__':
    unittest.main()
