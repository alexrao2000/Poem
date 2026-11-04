#!/usr/bin/env python3
"""Quilt the original ground painting into edge-matched Wang tiles.

Two quiet strips per direction supply all sixteen edge combinations. Minimum
error cuts join those strips to independent centers; triangular cut domains
keep other sides from overwriting a shared edge. One common corner pixel
allows any horizontal/vertical pair. Reflected gutters protect mip levels.
The preview samples both rules over the same world-space area.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SIZE = 128
BAND = 24
GUTTER = 8
STRIDE = SIZE + 2 * GUTTER
SEED = 472019
MATERIALS = ["grass", "earth"]


def quiet_strip(source, rng, vertical=False):
    height, width = (SIZE, BAND) if vertical else (BAND, SIZE)
    choices = []
    for _ in range(80):
        x = int(rng.integers(8, source.shape[1] - width - 8))
        y = int(rng.integers(8, source.shape[0] - height - 8))
        patch = source[y:y + height, x:x + width].copy()
        values = patch.astype(np.float32)
        score = np.var(values, axis=(0, 1)).mean() + np.mean(np.abs(np.diff(values, axis=0))) + np.mean(np.abs(np.diff(values, axis=1)))
        choices.append((float(score), patch))
    return min(choices, key=lambda item: item[0])[1]


def quilt_top(tile, strip):
    error = np.mean((tile[:BAND].astype(np.float32) - strip.astype(np.float32)) ** 2, axis=2)
    costs = np.full((BAND, SIZE), np.inf)
    previous = np.zeros((BAND, SIZE), dtype=np.int32)
    costs[0, 0] = error[0, 0]
    for x in range(1, SIZE):
        limit = min(BAND - 1, x, SIZE - 1 - x)
        for y in range(min(5, limit), limit + 1):
            start, end = max(0, y - 1), min(BAND, y + 2)
            parent = start + int(np.argmin(costs[start:end, x - 1]))
            costs[y, x] = error[y, x] + costs[parent, x - 1]
            previous[y, x] = parent
    seam = np.zeros(SIZE, dtype=np.int32)
    for x in range(SIZE - 1, 0, -1):
        seam[x - 1] = previous[seam[x], x]
    result = tile.copy()
    for x, y in enumerate(seam):
        result[:y + 1, x] = strip[:y + 1, x]
    return result


def material_tiles(source, material):
    rng = np.random.default_rng(SEED + material)
    horizontal = [quiet_strip(source, rng) for _ in range(2)]
    vertical = [quiet_strip(source, rng, True) for _ in range(2)]
    corner = np.median(source.reshape(-1, 3), axis=0).astype(np.uint8)
    for strip in horizontal:
        strip[0, 0] = strip[0, -1] = corner
    for strip in vertical:
        strip[0, 0] = strip[-1, 0] = corner
    tiles = []
    for index in range(16):
        x = int(rng.integers(8, source.shape[1] - SIZE - 8))
        y = int(rng.integers(8, source.shape[0] - SIZE - 8))
        tile = source[y:y + SIZE, x:x + SIZE].copy()
        top, right, bottom, left = [(index >> bit) & 1 for bit in range(4)]
        tile = quilt_top(tile, horizontal[top])
        tile = np.rot90(quilt_top(np.rot90(tile, 1), vertical[right].transpose(1, 0, 2)), -1)
        tile = np.rot90(quilt_top(np.rot90(tile, 2), horizontal[bottom][:, ::-1]), -2)
        tile = np.rot90(quilt_top(np.rot90(tile, 3), vertical[left].transpose(1, 0, 2)[:, ::-1]), -3)
        tile[0, 0] = tile[0, -1] = tile[-1, 0] = tile[-1, -1] = corner
        tiles.append(tile)
    return tiles


def edge_color(x, y, axis):
    key = ((x % 251) * 37 + (y % 251) * 101 + axis * 53 + 17) % 251
    return ((key * key * 13 + key * 19 + 23) % 101) % 2


def tile_index(x, y):
    return (edge_color(x, y, 0) + 2 * edge_color(x + 1, y, 1)
            + 4 * edge_color(x, y + 1, 0) + 8 * edge_color(x, y, 1))


def build(root=ROOT):
    original = np.array(Image.open(root / "assets/art/terrain-atlas.png").convert("RGB"))
    half = original.shape[0] // 2
    sources, tiles = [], []
    atlas = np.zeros((STRIDE * 8, STRIDE * 4, 3), dtype=np.uint8)
    for material in range(2):
        x, y = 0, material * half
        source = original[y:y + half, x:x + half]
        group = material_tiles(source, material)
        sources.append(source)
        tiles.append(group)
        for index, tile in enumerate(group):
            x, y = (index % 4) * STRIDE, (material * 4 + index // 4) * STRIDE
            atlas[y:y + STRIDE, x:x + STRIDE] = np.pad(tile, ((GUTTER, GUTTER), (GUTTER, GUTTER), (0, 0)), mode="reflect")
    return atlas, sources, tiles


def preview(sources, tiles):
    result = Image.new("RGB", (1056, 614), "#18212b")
    draw = ImageDraw.Draw(result)
    draw.text((16, 12), "POEM / ground texture study", fill="white")
    draw.text((16, 32), "Original mirrored repeat", fill="white")
    draw.text((544, 32), "16 Wang variants / matching edges", fill="white")
    for material, source in enumerate(sources):
        yy, xx = np.mgrid[:256, :512]
        u = np.abs(np.mod(xx / 128 * .25, 1) * 2 - 1)
        v = np.abs(np.mod(yy / 128 * .25, 1) * 2 - 1)
        before = source[(v * (source.shape[0] - 1)).astype(int), (u * (source.shape[1] - 1)).astype(int)]
        position_x = xx / 128 * (source.shape[1] / (2 * SIZE))
        position_y = yy / 128 * (source.shape[0] / (2 * SIZE))
        cell_x, cell_y = np.floor(position_x).astype(int), np.floor(position_y).astype(int)
        ids = np.vectorize(tile_index)(cell_x, cell_y)
        after = np.array(tiles[material])[ids, ((position_y % 1) * (SIZE - 1)).astype(int), ((position_x % 1) * (SIZE - 1)).astype(int)]
        y = 68 + material * 268
        draw.text((16, y - 13), MATERIALS[material], fill="white")
        result.paste(Image.fromarray(before), (16, y))
        result.paste(Image.fromarray(after), (544, y))
    draw.text((16, 604), "Texture-only comparison; scene lighting and terrain blending are not shown.", fill="white")
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args()
    atlas, sources, tiles = build(args.root)
    Image.fromarray(atlas).save(args.root / "assets/art/terrain-wang.png")
    destination = args.root / "docs/previews/wang-ground-comparison.png"
    destination.parent.mkdir(parents=True, exist_ok=True)
    preview(sources, tiles).save(destination)
    metadata = dict(source="assets/art/terrain-atlas.png", source_sha256=hashlib.sha256((args.root / "assets/art/terrain-atlas.png").read_bytes()).hexdigest(), tile_size=SIZE, gutter=GUTTER, stride=STRIDE, seed=SEED, materials=MATERIALS, tiles_per_material=16, world_tile_size=2 * SIZE / sources[0].shape[1], edge_bits=["top", "right", "bottom", "left"])
    (args.root / "assets/art/terrain-wang.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print("Generated 32 quilted tiles, padded atlas and texture comparison")


if __name__ == "__main__":
    main()
