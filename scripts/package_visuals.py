#!/usr/bin/env python3
"""Package the reusable visuals as a clean Godot project and a source zip."""
from pathlib import Path
import shutil
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parent.parent
DESTINATION = ROOT / 'build/visuals-starter'
DESTINATION.mkdir(parents=True, exist_ok=True)
for source in (ROOT / 'visuals').rglob('*'):
    if not source.is_file() or source.suffix in {'.import', '.uid'} or '__pycache__' in source.parts or source.name == 'units-v1.png':
        continue
    target = DESTINATION / source.relative_to(ROOT)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
(DESTINATION / 'project.godot').write_text('''config_version=5
[application]
config/name="Tactical Sprite Starter"
run/main_scene="res://visuals/preview.tscn"
[display]
window/size/viewport_width=1440
window/size/viewport_height=900
window/stretch/mode="canvas_items"
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
''')
with ZipFile(ROOT / 'build/Reusable2DVisuals.zip', 'w', ZIP_DEFLATED) as archive:
    for source in DESTINATION.rglob('*'):
        if source.is_file() and '.godot' not in source.parts and source.suffix != '.import':
            archive.write(source, source.relative_to(DESTINATION))
print('Reusable starter:', DESTINATION)
print('Archive:', ROOT / 'build/Reusable2DVisuals.zip')
