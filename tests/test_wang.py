"""Verify actual atlas seams, mip gutters and reproducible quilt generation."""
import hashlib
import importlib.util
import json
from pathlib import Path
import unittest

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("wang", ROOT / "scripts/generate_wang.py")
wang = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wang)


class WangAtlas(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.atlas = np.array(Image.open(ROOT / "assets/art/terrain-wang.png").convert("RGB"))
        cls.groups = []
        for material in range(2):
            group = []
            for index in range(16):
                x, y = (index % 4) * wang.STRIDE + wang.GUTTER, (material * 4 + index // 4) * wang.STRIDE + wang.GUTTER
                group.append(cls.atlas[y:y + wang.SIZE, x:x + wang.SIZE])
            cls.groups.append(group)

    def test_all_compatible_edges_match(self):
        for group in self.groups:
            self.assertEqual(len({tile.tobytes() for tile in group}), 16)
            for a in range(16):
                for b in range(16):
                    if ((a >> 1) & 1) == ((b >> 3) & 1):
                        np.testing.assert_array_equal(group[a][:, -1], group[b][:, 0])
                    if ((a >> 2) & 1) == (b & 1):
                        np.testing.assert_array_equal(group[a][-1], group[b][0])

    def test_shared_edges_across_negative_coordinates_and_chunk_boundaries(self):
        used = set()
        for y in range(-64, 65):
            for x in range(-64, 65):
                a, right, below = wang.tile_index(x, y), wang.tile_index(x + 1, y), wang.tile_index(x, y + 1)
                self.assertEqual((a >> 1) & 1, (right >> 3) & 1)
                self.assertEqual((a >> 2) & 1, below & 1)
                used.add(a)
        self.assertEqual(used, set(range(16)))

    def test_reflected_gutters_cover_mip_footprints(self):
        for material, group in enumerate(self.groups):
            for index, tile in enumerate(group):
                x, y = (index % 4) * wang.STRIDE, (material * 4 + index // 4) * wang.STRIDE
                actual = self.atlas[y:y + wang.STRIDE, x:x + wang.STRIDE]
                np.testing.assert_array_equal(actual, np.pad(tile, ((wang.GUTTER, wang.GUTTER), (wang.GUTTER, wang.GUTTER), (0, 0)), mode="reflect"))

    def test_reproducible_from_recorded_source(self):
        metadata = json.loads((ROOT / "assets/art/terrain-wang.json").read_text())
        self.assertEqual(metadata["source_sha256"], hashlib.sha256((ROOT / metadata["source"]).read_bytes()).hexdigest())
        generated, _, _ = wang.build(ROOT)
        np.testing.assert_array_equal(self.atlas, generated)


if __name__ == "__main__":
    unittest.main()
