#!/usr/bin/env python3
"""Index the original enemy atlas without changing source pixels.

Reuse portable class animation timings. Transparent separators and alpha bounds
isolate every pose, while constant source density preserves weapon/body scale.
"""
import copy
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image
from index_recruit_animations import separators

ROOT = Path(__file__).resolve().parent.parent
PATH = ROOT / "assets/art/enemy-units-v2.png"


def main():
    image = Image.open(PATH)
    if image.mode != "RGBA":
        raise ValueError("Enemy atlas requires alpha transparency")
    mask = np.asarray(image)[:, :, 3] >= 100
    height, width = mask.shape
    templates = json.loads((ROOT / "visuals/units.json").read_text())["assets"]
    rows = separators(mask.sum(axis=1), len(templates), round(height / 8 * .38))
    assets = []
    for row, template in enumerate(templates):
        top, bottom = rows[row:row + 2]
        columns = separators(mask[top:bottom].sum(axis=0), 12, round(width / 12 * .22))
        frames = []
        for column in range(12):
            left, right = columns[column:column + 2]
            ys, xs = np.where(mask[top:bottom, left:right])
            if len(xs) < 100:
                raise ValueError(f"Missing enemy pose {row}/{column}")
            x = max(left, int(xs.min()) + left - 2)
            y = max(top, int(ys.min()) + top - 2)
            end_x = min(right + 1, width, int(xs.max()) + left + 3)
            end_y = min(bottom + 1, height, int(ys.max()) + top + 3)
            # Below the body, the bottom-most solid pixel is the planted foot.
            baseline = int(ys.max()) + top
            pivot = [round((column + .5) * width / 12) - x, baseline - y]
            rect = [x, y, end_x - x, end_y - y]
            if not (0 <= pivot[0] <= rect[2] and 0 <= pivot[1] <= rect[3]):
                raise ValueError("Foot pivot outside frame")
            frames.append({"rect": rect, "pivot_px": pivot})
        assets.append({
            "id": template["id"].replace("unit.", "enemy.", 1),
            "kind": "map_unit", "texture": PATH.relative_to(ROOT).as_posix(),
            "logical_frame_px": [64, 64], "source_pixel_scale": .44 if template["id"] == "unit.rider" else .46,
            "right_facing_frames": [10], "fallback_visual_id": None,
            "frames": frames, "clips": copy.deepcopy(template["clips"]),
        })
    output = {"schema_version": 1,
              "profile": {"id": "poem-enemies-v1", "tile_size_px": [32, 32]},
              "assets": assets,
              "sources": {PATH.relative_to(ROOT).as_posix(): hashlib.sha256(PATH.read_bytes()).hexdigest()}}
    (ROOT / "enemy_visuals.json").write_text(json.dumps(output, indent=2) + "\n")
    print(f"Indexed {len(assets)} enemy classes / 96 poses; source PNG unchanged")


if __name__ == "__main__":
    main()
