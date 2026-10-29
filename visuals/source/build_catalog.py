#!/usr/bin/env python3
"""Index generated artwork without changing any image pixels."""
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parent.parent

def png_size(path):
    data = path.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    return struct.unpack('>II', data[16:24])

def build():
    width, height = png_size(ROOT / 'assets/units-v2.png')
    assert (width, height) == (1536, 1024), 'Review grid bounds if source dimensions change'
    assets = []
    names = ['vanguard', 'knight', 'ranger', 'arcanist', 'warden', 'rider', 'corsair', 'duelist']
    for row, name in enumerate(names):
        frames = [{'rect': [col*128+3, row*128+2, 122, 124], 'pivot_px': [61, 108]} for col in range(12)]
        clips = {state: {} for state in ['idle', 'move', 'act', 'hurt', 'defeated']}
        for facing, columns in {'south': [0, 1], 'west': [2, 3], 'east': [4, 5], 'north': [6, 7]}.items():
            idle = [0, 1] if facing == 'south' else [columns[0], columns[0]]
            move = [8, 9] if facing == 'south' else columns
            definitions = {
                'idle': (idle, [350, 350], True, []),
                'move': (move, [110, 110], True, []),
                'act': ([columns[0], 10, 10, columns[0]], [120, 100, 90, 110], False, [{'frame_index': 1, 'name': 'contact'}]),
                'hurt': ([11, 11], [120, 160], False, []),
                'defeated': ([11, 11], [200, 300], False, []),
            }
            for state, (indices, durations, loop, cues) in definitions.items():
                clips[state][facing] = {'frames': indices, 'duration_ms': durations, 'loop': loop, 'cues': cues}
        assets.append({
            'id': 'unit.'+name, 'kind': 'map_unit', 'texture': 'assets/units-v2.png',
            'logical_frame_px': [49, 50], 'fallback_visual_id': None,
            'frames': frames, 'clips': clips,
            'provenance': {'generator': 'built-in image_gen', 'record': 'source/generation-prompts.json'},
            'art_status': 'prototype: directional move pairs; shared attack and hurt pose; defeat reuses recoil',
        })
    catalog = {'schema_version': 1, 'profile': {'id': 'tactical-pixel-v1-prototype', 'tile_size_px': [32, 32], 'direction_axes': {'east': '+x', 'south': '+y'}}, 'assets': assets}
    (ROOT / 'units.json').write_text(json.dumps(catalog, indent=2)+'\n')
    assert png_size(ROOT / 'assets/terrain-v1.png') == (1254, 1254)
    xs, ys = [0, 314, 628, 942, 1254], [0, 305, 611, 914, 1254]
    regions = [[xs[col]+2, ys[row]+2, xs[col+1]-xs[col]-4, ys[row+1]-ys[row]-4] for row in range(4) for col in range(4)]
    (ROOT / 'data/terrain.json').write_text(json.dumps({'texture': 'assets/terrain-v1.png', 'regions': regions}, indent=2)+'\n')
    print('Indexed eight classes, 96 source poses, four facings, five states, and sixteen environment regions.')

if __name__ == '__main__':
    build()
