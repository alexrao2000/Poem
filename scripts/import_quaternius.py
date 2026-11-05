#!/usr/bin/env python3
"""Assemble compatible CC0 outfit/head/hair rigs from local Standard archives.

No downloads or external executables. Meshes retain their individual skin binds
on a shared named hierarchy. Mannequin animation deltas use the outfit rest pose.
"""
import argparse
import copy
import hashlib
import json
import math
import re
from pathlib import Path, PurePosixPath
import struct
import zipfile

COMPONENTS = {5121: ('B', 1), 5123: ('H', 2), 5125: ('I', 4), 5126: ('f', 4)}
WIDTHS = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}
CLIPS = {'Idle_Loop', 'Sword_Idle', 'Sword_Attack', 'Jog_Fwd_Loop',
         'Hit_Chest', 'Death01', 'Roll'}


def texture_import(path):
    """Limit engine textures while retaining the unmodified licensed source."""
    settings = Path(str(path) + '.import')
    text = settings.read_text() if settings.exists() else '[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n'
    for key, value in [('process/size_limit', '1024'), ('mipmaps/generate', 'true')]:
        pattern = '^' + re.escape(key) + '=.*$'
        if re.search(pattern, text, flags=re.MULTILINE):
            text = re.sub(pattern, key + '=' + value, text, flags=re.MULTILINE)
        else:
            text += key + '=' + value + '\n'
    settings.write_text(text)


def quat_product(a, b):
    x, y, z, w = a
    X, Y, Z, W = b
    return (w*X+x*W+y*Z-z*Y, w*Y-x*Z+y*W+z*X,
            w*Z+x*Y-y*X+z*W, w*W-x*X-y*Y-z*Z)


def remap_rotation(value, source, target):
    inverse = (-source[0], -source[1], -source[2], source[3])
    result = quat_product(quat_product(target, inverse), value)
    length = math.sqrt(sum(v*v for v in result))
    assert length > 0.00001
    return tuple(v/length for v in result)


class Source:
    def __init__(self, archive, suffix):
        self.archive = archive
        matches = [name for name in archive.namelist() if name.endswith(suffix)]
        if len(matches) != 1:
            raise ValueError(f'Expected exactly one source: {suffix}')
        self.name = matches[0]
        self.folder = str(PurePosixPath(self.name).parent)
        raw = archive.read(self.name)
        if self.name.endswith('.glb'):
            magic, version, size = struct.unpack_from('<III', raw)
            assert magic == 0x46546C67 and version == 2 and size == len(raw)
            chunks = {}
            cursor = 12
            while cursor < len(raw):
                length, kind = struct.unpack_from('<II', raw, cursor)
                chunks[kind] = raw[cursor + 8:cursor + 8 + length]
                cursor += 8 + length
            self.data = json.loads(chunks[0x4E4F534A])
            self.buffers = [chunks[0x004E4942]]
        else:
            self.data = json.loads(raw)
            self.buffers = [archive.read(self.relative(item['uri']))
                            for item in self.data.get('buffers', [])]

    def relative(self, uri):
        path = PurePosixPath(uri)
        if path.is_absolute() or '..' in path.parts or ':' in uri:
            raise ValueError(f'Nonlocal asset URI: {uri}')
        return self.folder + '/' + uri

    def values(self, index, raw_normalized=False):
        accessor = self.data['accessors'][index]
        assert 'sparse' not in accessor
        assert raw_normalized or not accessor.get('normalized', False)
        view = self.data['bufferViews'][accessor['bufferView']]
        code, width = COMPONENTS[accessor['componentType']]
        count = WIDTHS[accessor['type']]
        stride = view.get('byteStride', width * count)
        offset = view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
        raw = self.buffers[view['buffer']]
        return [struct.unpack_from('<' + code * count, raw, offset + i * stride)
                for i in range(accessor['count'])]


class Assembly:
    def __init__(self, outfit, destination):
        self.destination = destination
        self.binary = bytearray()
        self.data = {'asset': {'version': '2.0', 'generator': 'Poem CC0 rig assembler'},
                     'scene': outfit.data.get('scene', 0),
                     'scenes': copy.deepcopy(outfit.data['scenes']),
                     'nodes': copy.deepcopy(outfit.data['nodes']),
                     'meshes': [], 'skins': [], 'animations': [],
                     'accessors': [], 'bufferViews': [], 'images': [],
                     'textures': [], 'samplers': [], 'materials': []}
        self.nodes = {node['name']: i for i, node in enumerate(self.data['nodes'])
                      if 'name' in node}
        self.joints = outfit.data['skins'][0]['joints']
        self.joint_names = [self.data['nodes'][i]['name'] for i in self.joints]
        self.root = self.nodes['Armature']
        access, material = self.resources(outfit)
        skin = copy.deepcopy(outfit.data['skins'][0])
        skin['inverseBindMatrices'] += access
        self.data['skins'].append(skin)
        for mesh in outfit.data['meshes']:
            self.data['meshes'].append(self.mesh(mesh, access, material))

    def append_bytes(self, raw):
        self.binary.extend(b'\0' * (-len(self.binary) % 4))
        offset = len(self.binary)
        self.binary.extend(raw)
        return offset

    def accessor(self, values, kind, component):
        code, _ = COMPONENTS[component]
        raw = b''.join(struct.pack('<' + code * len(value), *value) for value in values)
        offset = self.append_bytes(raw)
        view = len(self.data['bufferViews'])
        self.data['bufferViews'].append({'buffer': 0, 'byteOffset': offset, 'byteLength': len(raw)})
        index = len(self.data['accessors'])
        self.data['accessors'].append({'bufferView': view, 'componentType': component,
                                       'count': len(values), 'type': kind})
        return index

    def resources(self, source, materials=True):
        offsets = [self.append_bytes(raw) for raw in source.buffers]
        view_start = len(self.data['bufferViews'])
        access_start = len(self.data['accessors'])
        for original in source.data.get('bufferViews', []):
            view = copy.deepcopy(original)
            view['byteOffset'] = view.get('byteOffset', 0) + offsets[view['buffer']]
            view['buffer'] = 0
            self.data['bufferViews'].append(view)
        for original in source.data.get('accessors', []):
            item = copy.deepcopy(original)
            assert 'sparse' not in item
            item['bufferView'] += view_start
            self.data['accessors'].append(item)
        material_start = len(self.data['materials'])
        if not materials:
            return access_start, material_start
        image_start = len(self.data['images'])
        for original in source.data.get('images', []):
            uri = original['uri']
            path = source.relative(uri)
            if path not in source.archive.namelist() and uri in ['T_Eye_Normal_png.png', 'T_Hair_1_Normal_png.png']:
                replacement = uri.replace('_png.png', '.png')
                path = source.relative(replacement)
                godot_copy = next(name for name in source.archive.namelist()
                                  if name.endswith('/Textures/Normals Unity - Godot/' + replacement))
                assert source.archive.read(path) == source.archive.read(godot_copy)
            raw = source.archive.read(path)
            name = hashlib.sha256(raw).hexdigest()[:16] + '-' + PurePosixPath(path).name
            folder = self.destination / 'textures'
            folder.mkdir(parents=True, exist_ok=True)
            (folder / name).write_bytes(raw)
            texture_import(folder / name)
            self.data['images'].append({'uri': 'textures/' + name})
        sampler_start = len(self.data['samplers'])
        self.data['samplers'].extend(copy.deepcopy(source.data.get('samplers', [])))
        texture_start = len(self.data['textures'])
        for original in source.data.get('textures', []):
            item = copy.deepcopy(original)
            item['source'] += image_start
            if 'sampler' in item:
                item['sampler'] += sampler_start
            self.data['textures'].append(item)
        for original in source.data.get('materials', []):
            item = copy.deepcopy(original)
            for parent in [item, item.get('pbrMetallicRoughness', {})]:
                for key, info in parent.items():
                    if key.endswith('Texture') and isinstance(info, dict):
                        info['index'] += texture_start
            self.data['materials'].append(item)
        return access_start, material_start

    @staticmethod
    def mesh(original, access, material):
        mesh = copy.deepcopy(original)
        for primitive in mesh['primitives']:
            assert primitive.get('mode', 4) == 4
            primitive['attributes'] = {key: value + access for key, value in primitive['attributes'].items()}
            primitive['indices'] += access
            if 'material' in primitive:
                primitive['material'] += material
            for target in primitive.get('targets', []):
                for key in target:
                    target[key] += access
        return mesh

    def compatible(self, source):
        source_parents = {child: i for i, node in enumerate(source.data['nodes'])
                          for child in node.get('children', [])}
        target_parents = {child: i for i, node in enumerate(self.data['nodes'])
                          for child in node.get('children', [])}
        names = []
        for index in source.data['skins'][0]['joints']:
            node = source.data['nodes'][index]
            name = node['name']
            assert name in self.joint_names, f'Unknown bone: {name}'
            names.append(name)
            assert source.data['nodes'][source_parents[index]]['name'] == self.data['nodes'][target_parents[self.nodes[name]]]['name']
            # The kits share names/parents but not every local rest transform.
            # Each mesh retains its own inverse binds on the outfit hierarchy.
        return names

    def add_meshes(self, source, head_only=False):
        names = self.compatible(source)
        access, material = self.resources(source)
        skin = copy.deepcopy(source.data['skins'][0])
        skin['inverseBindMatrices'] += access
        skin['joints'] = [self.nodes[name] for name in names]
        if 'skeleton' in skin:
            skin['skeleton'] = self.nodes[source.data['nodes'][skin['skeleton']]['name']]
        skin_index = len(self.data['skins'])
        self.data['skins'].append(skin)
        for source_node in source.data['nodes']:
            if 'mesh' not in source_node:
                continue
            assert not any(key in source_node for key in ['matrix', 'translation', 'rotation', 'scale'])
            mesh = self.mesh(source.data['meshes'][source_node['mesh']], access, material)
            kept = []
            for primitive, original in zip(mesh['primitives'], source.data['meshes'][source_node['mesh']]['primitives']):
                joints = source.values(original['attributes']['JOINTS_0'])
                weights = source.values(original['attributes']['WEIGHTS_0'])
                indices = source.values(original['indices'])
                if head_only:
                    head = [sum(weight for bone, weight in zip(row, influence)
                                if names[bone] in ['Head', 'neck_01']) >= 0.5
                            for row, influence in zip(joints, weights)]
                    indices = [value for i in range(0, len(indices), 3)
                               if all(head[indices[i + j][0]] for j in range(3))
                               for value in indices[i:i + 3]]
                    if not indices:
                        continue
                    used = sorted({value[0] for value in indices})
                    remap = {old: new for new, old in enumerate(used)}
                    primitive['indices'] = self.accessor([(remap[value[0]],) for value in indices], 'SCALAR', 5125)
                    # Do not ship the removed body's unused vertices and UVs.
                    for key, index in original['attributes'].items():
                        definition = source.data['accessors'][index]
                        values = source.values(index, raw_normalized=True)
                        result = self.accessor([values[i] for i in used], definition['type'], definition['componentType'])
                        if definition.get('normalized', False):
                            self.data['accessors'][result]['normalized'] = True
                        primitive['attributes'][key] = result
                kept.append(primitive)
            if not kept:
                continue
            mesh['primitives'] = kept
            mesh_index = len(self.data['meshes'])
            self.data['meshes'].append(mesh)
            index = len(self.data['nodes'])
            self.data['nodes'].append({'name': 'Head_' + source_node['name'] if head_only else source_node['name'], 'mesh': mesh_index, 'skin': skin_index})
            self.data['nodes'][self.root].setdefault('children', []).append(index)

    def add_animations(self, source):
        source_parents = {child: i for i, node in enumerate(source.data['nodes'])
                          for child in node.get('children', [])}
        target_parents = {child: i for i, node in enumerate(self.data['nodes'])
                          for child in node.get('children', [])}
        for index in source.data['skins'][0]['joints']:
            name = source.data['nodes'][index]['name']
            assert name in self.joint_names
            source_parent = source.data['nodes'][source_parents[index]]['name']
            target_parent = self.data['nodes'][target_parents[self.nodes[name]]]['name']
            assert source_parent == target_parent, f'Incompatible animation hierarchy: {name}'
        access, _ = self.resources(source, materials=False)
        for original in source.data['animations']:
            if original['name'] not in CLIPS:
                continue
            animation = {'name': original['name'], 'samplers': [], 'channels': []}
            for original_channel in original['channels']:
                channel = copy.deepcopy(original_channel)
                source_node = source.data['nodes'][channel['target']['node']]
                name = source_node['name']
                target_node = self.data['nodes'][self.nodes[name]]
                sampler = copy.deepcopy(original['samplers'][channel['sampler']])
                assert sampler.get('interpolation', 'LINEAR') == 'LINEAR'
                values = source.values(sampler['output'])
                path = channel['target']['path']
                if path == 'rotation':
                    values = [remap_rotation(value, source_node.get('rotation', [0, 0, 0, 1]),
                                             target_node.get('rotation', [0, 0, 0, 1])) for value in values]
                elif path == 'translation':
                    source_rest = source_node.get('translation', [0, 0, 0])
                    target_rest = target_node.get('translation', [0, 0, 0])
                    values = [tuple(t + v - s for v, s, t in zip(value, source_rest, target_rest)) for value in values]
                elif path == 'scale':
                    source_rest = source_node.get('scale', [1, 1, 1])
                    target_rest = target_node.get('scale', [1, 1, 1])
                    values = [tuple(t*v/s for v, s, t in zip(value, source_rest, target_rest)) for value in values]
                else:
                    raise ValueError(f'Unexpected animation path: {path}')
                sampler['input'] += access
                sampler['output'] = self.accessor(values, 'VEC4' if path == 'rotation' else 'VEC3', 5126)
                channel['sampler'] = len(animation['samplers'])
                channel['target']['node'] = self.nodes[name]
                animation['samplers'].append(sampler)
                animation['channels'].append(channel)
            self.data['animations'].append(animation)
        assert {item['name'] for item in self.data['animations']} == CLIPS

    def compact(self):
        """Copy only referenced accessors, excluding unused mannequin/clip data."""
        original_accessors = self.data['accessors']
        original_views = self.data['bufferViews']
        original_binary = self.binary
        self.binary = bytearray()
        self.data['accessors'] = []
        self.data['bufferViews'] = []
        remapped = {}

        def keep(index):
            if index in remapped:
                return remapped[index]
            item = original_accessors[index]
            view = original_views[item['bufferView']]
            code, width = COMPONENTS[item['componentType']]
            count = WIDTHS[item['type']]
            stride = view.get('byteStride', width * count)
            offset = view.get('byteOffset', 0) + item.get('byteOffset', 0)
            values = [struct.unpack_from('<' + code * count, original_binary, offset + i * stride)
                      for i in range(item['count'])]
            result = self.accessor(values, item['type'], item['componentType'])
            if item.get('normalized', False):
                self.data['accessors'][result]['normalized'] = True
            if 'min' in item or item['type'] == 'VEC3':
                self.data['accessors'][result]['min'] = [min(row[i] for row in values) for i in range(count)]
                self.data['accessors'][result]['max'] = [max(row[i] for row in values) for i in range(count)]
            remapped[index] = result
            return result

        for mesh in self.data['meshes']:
            for primitive in mesh['primitives']:
                primitive['indices'] = keep(primitive['indices'])
                primitive['attributes'] = {key: keep(value) for key, value in primitive['attributes'].items()}
                for target in primitive.get('targets', []):
                    for key in target:
                        target[key] = keep(target[key])
        for skin in self.data['skins']:
            skin['inverseBindMatrices'] = keep(skin['inverseBindMatrices'])
        for animation in self.data['animations']:
            for sampler in animation['samplers']:
                for key in ['input', 'output']:
                    sampler[key] = keep(sampler[key])

    def write(self, name):
        self.compact()
        self.data['buffers'] = [{'uri': name + '.bin', 'byteLength': len(self.binary)}]
        (self.destination / (name + '.bin')).write_bytes(self.binary)
        (self.destination / (name + '.gltf')).write_text(json.dumps(self.data, separators=(',', ':')) + '\n')
        print(f'{name}: {len(self.data["meshes"])} meshes, {len(self.joints)} bones, {len(self.data["animations"])} clips')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['outfits', 'base', 'animations']:
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--output', type=Path, default=Path('assets/models/quaternius'))
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.outfits) as outfits, zipfile.ZipFile(args.base) as base, zipfile.ZipFile(args.animations) as animations:
        motion = Source(animations, '/Unreal-Godot/UAL1_Standard.glb')
        for gender, hair in [('Female', 'Hair_Long'), ('Male', 'Hair_SimpleParted')]:
            outfit = Source(outfits, f'/Outfits/{gender}_Peasant.gltf')
            head = Source(base, f'/Base Characters/Godot - UE/Superhero_{gender}_FullBody.gltf')
            hairstyle = Source(base, f'/Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)/{hair}.gltf')
            assembly = Assembly(outfit, args.output)
            assembly.add_meshes(head, head_only=True)
            assembly.add_meshes(hairstyle)
            assembly.add_animations(motion)
            assembly.write('duelist_' + gender.lower())
        licenses = args.output / 'licenses'
        licenses.mkdir(exist_ok=True)
        for name, archive in [('outfits', outfits), ('base', base), ('animations', animations)]:
            license_path = next(path for path in archive.namelist() if PurePosixPath(path).name in ['License.txt', 'License_Standard.txt'])
            (licenses / (name + '.txt')).write_bytes(archive.read(license_path))
    manifest = {'author': 'Quaternius', 'source_url': 'https://quaternius.com', 'license': 'CC0 1.0 Universal',
                'sources': {name: {'archive': getattr(args, name).name,
                                   'sha256': hashlib.sha256(getattr(args, name).read_bytes()).hexdigest()}
                            for name in ['outfits', 'base', 'animations']},
                'modifications': ['Combined outfits, head-only base meshes and hair on the shared named hierarchy, preserving each mesh skin bind.',
                                  'Removed triangles below the head/neck skin influences.',
                                  'Compacted referenced mesh and animation buffers; removed unused body vertices and unselected animation data.',
                                  'Set engine texture imports to a 1024-pixel limit with mipmaps; source image bytes are unchanged.',
                                  'Selected seven supplied in-place animation clips.',
                                  'Remapped mannequin animation deltas onto each outfit rest pose after verifying the named hierarchy.',
                                  'Corrected missing eye/hair normal URIs to the verified adjacent Godot normal maps.']}
    (args.output / 'provenance.json').write_text(json.dumps(manifest, indent=2) + '\n')


if __name__ == '__main__':
    main()
