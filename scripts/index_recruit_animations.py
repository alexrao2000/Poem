#!/usr/bin/env python3
"""Index transparent sprite frames without modifying a single source pixel.

Generated atlases may place figures a few pixels beyond nominal grid lines.
Find genuinely empty separators, retain a common source-pixel scale, and use
each pose's lowest visible foot pixel. Use a conservative alpha floor just below the
renderer cutoff, including borderline packed alpha values. Output is atlas metadata only. Requires Pillow
and NumPy for offline authoring; the game has no Python runtime dependency.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent


def separators(activity, count, radius):
    length = len(activity)
    cuts = [0]
    for index in range(1, count):
        expected = round(length * index / count)
        candidates = range(max(cuts[-1] + 1, expected - radius), min(length, expected + radius + 1))
        cut = min(candidates, key=lambda position: (activity[position], abs(position - expected)))
        if activity[cut] != 0:
            raise ValueError(f"No transparent separator near {expected}; fix the source artwork")
        cuts.append(cut)
    return cuts + [length]


def index_sheet(path, ids, scale):
    image = Image.open(path)
    if image.mode != "RGBA":
        raise ValueError("Recruit atlas must preserve an alpha channel")
    alpha = np.asarray(image)[:, :, 3]
    mask = alpha >= 100
    height, width = mask.shape
    rows = separators(mask.sum(axis=1), len(ids), round(height / len(ids) * .38))
    roster = {unit["id"]: unit for unit in json.loads((ROOT / "data/campaign.json").read_text())["roster"]}
    classes = {asset["id"]: asset for asset in json.loads((ROOT / "visuals/units.json").read_text())["assets"]}
    result = []
    for row, character in enumerate(ids):
        top, bottom = rows[row:row + 2]
        columns = separators(mask[top:bottom].sum(axis=0), 12, round(width / 12 * .22))
        boxes = []
        for column in range(12):
            left, right = columns[column:column + 2]
            ys, xs = np.where(mask[top:bottom, left:right])
            if len(xs) < 100:
                raise ValueError(f"Missing figure in {character}, pose {column}")
            boxes.append([int(xs.min()) + left, int(ys.min()) + top, int(xs.max()) + left + 1, int(ys.max()) + top + 1])
        frames = []
        for column, box in enumerate(boxes):
            baseline = box[3] - 1
            left = max(columns[column], box[0] - 2)
            right = min(width, columns[column + 1] + 1, box[2] + 2)
            y = max(top, box[1] - 2)
            end = min(height, bottom + 1, max(box[3] + 2, baseline + 2))
            pivot = [round((column + .5) * width / 12) - left, baseline - y]
            if not (0 <= pivot[0] <= right - left and 0 <= pivot[1] <= end - y):
                raise ValueError(f"Invalid foot pivot in {character}, pose {column}")
            frames.append({"rect": [left, y, right - left, end - y], "pivot_px": pivot})
        template = classes["unit." + roster[character]["job"].lower()]
        result.append({"id": "recruit." + character, "kind": "map_unit", "texture": path.relative_to(ROOT).as_posix(), "logical_frame_px": [64, 64], "source_pixel_scale": scale, "right_facing_frames": [10], "fallback_visual_id": None, "frames": frames, "clips": copy.deepcopy(template["clips"])})
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sheet", type=Path)
    parser.add_argument("--characters", required=True, help="Comma-separated character IDs in row order")
    parser.add_argument("--scale", type=float, default=.5)
    args = parser.parse_args()
    if not 0 < args.scale <= 2:
        raise ValueError("Source scale must be between zero and two")
    path = args.sheet.resolve()
    ids = args.characters.split(",")
    if len(ids) != len(set(ids)):
        raise ValueError("Duplicate character ID")
    assets = index_sheet(path, ids, args.scale)
    output = ROOT / "campaign_visuals.json"
    catalog = json.loads(output.read_text()) if output.exists() else {"schema_version": 1, "profile": {"id": "poem-recruits-v1", "tile_size_px": [32, 32]}, "assets": [], "sources": {}}
    updated = {asset["id"]: asset for asset in catalog["assets"]}
    updated.update({asset["id"]: asset for asset in assets})
    catalog["assets"] = list(updated.values())
    catalog["sources"][path.relative_to(ROOT).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    output.write_text(json.dumps(catalog, indent=2) + "\n")
    print(f"Indexed {len(assets)} recruits / {len(assets) * 12} poses without editing source pixels")


if __name__ == "__main__":
    main()
