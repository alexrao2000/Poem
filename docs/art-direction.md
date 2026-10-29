# Art direction and asset provenance

Target: the readable sprite-on-3D tactical presentation and close-up 3D combat of Fire Emblem Awakening and Fates. Reference screenshots are linked in DEVELOPMENT.md; no reference pixels are included in the game.

The first build's floating board, flat spheres, identical block sprites and wooden mannequin combatants were rejected by the user. Do not treat that aesthetic as the target. The current rebuild is an intermediate step, not an equivalent of the reference games.

## Original raster assets

Created with the built-in image-generation tool on 2026-10-29, then copied into the project. Alpha is preserved for sprites. Godot uses atlas regions; no Nintendo assets or extracted game models are used.

- `assets/art/terrain-atlas.png`: square 2-by-2 ground atlas. Prompt: original painterly medieval tactical RPG diffuse textures; equal quadrants without gutters; top-left sage grass with moss and tiny golden blades, top-right gray-beige irregular cobblestones with moss seams, bottom-left ochre dirt and fine gravel, bottom-right worn blue-gray slate flagstones; orthographic materials, no perspective, text, border or objects; subdued hand-painted albedo. Terrain shader selects quadrants in world space, reduces saturation, and uses mipmaps.
- `assets/art/class-sprites.png`: transparent 4-column, 2-row atlas. Prompt: eight original detailed hard-pixel Japanese fantasy tactical map sprites, full body, equal cells, three-quarter front view from above, three-head-tall proportions, blue/cream/gold/silver palette. Top row: female sword commander with chestnut hair and white mantle; silver armored lance knight; hooded archer; blue-coated mage with cyan orb. Bottom row: white-robed staff healer; chestnut mounted lancer; rugged red-haired axe warrior; short-haired blue-scarfed duelist. No text, labels, background, grid, existing characters or cell overlap. The generated sheet has some padding imperfections; regions are inset to suppress neighboring fragments. Class appearance is shared across recruits pending individual character art.

## Next quality targets

- Replace the generic face/hair construction with authored character meshes and textures, then develop weight shifts, planted feet, anticipation, follow-through, reactions and distinct ranged animations.
- Bring map and combat character identities into agreement; generate or author individual portraits and class variants for the full roster.
- Replace repetitive round foliage and simple houses with richer original environment assets. Match each combat arena to the actual battlefield terrain.
- Add restrained UI ornament and typographic hierarchy without increasing panel size.
- Improve camera continuity: track the selected map unit into the close-up, preserve relative orientation and terrain, then return to its exact map position.
