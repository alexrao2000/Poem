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

## Character portraits and typography

`assets/portraits/company-a.png` through `company-d.png` contain all 24 individual original portraits in 3-by-2 atlases. Generated with the built-in image tool on 2026-10-29; complete prompts are preserved in `docs/portrait-prompts.json`. Transparent backgrounds are preserved and Godot clips each atlas region at runtime. These appear in recruitment, dossiers, dialogue and selected-unit panels.

Display headings use Cormorant Garamond from https://github.com/google/fonts/tree/main/ofl/cormorantgaramond under the included `assets/fonts/OFL.txt`.

The second presentation pass adds elbow/knee articulation, weapon-specific attack preparation and strikes, dodges, reactions and falling poses; projectiles for bows/magic; chapter-specific combat scenery and lighting; selection-centered camera zoom; and crossfades that remain stable during consecutive fights. Meshes remain procedural placeholders and need a substantial art pass.

## Environment and character materials

`assets/art/environment-atlas.png` contains original painted oak leaves, willow leaves, bark and masonry. `assets/art/character-materials.png` contains original linen, steel, chainmail and leather. Both were generated with the built-in image tool on 2026-10-29; exact prompts are in `docs/environment-prompt.txt` and `docs/character-material-prompt.txt`. Godot samples atlas quadrants directly; no external raster editing was used.

Character material shading uses Godot’s documented toon render modes: https://docs.godotengine.org/en/4.4/tutorials/shaders/shader_reference/spatial_shader.html. These are still procedural mesh approximations, not finished authored character models.

## Individual map sprites

`assets/sprites/company-a.png` through `company-c.png` contain all 24 recruits in original full-body sprite art derived from the project’s own portraits and earlier class sprite style. Exact creation and layout-refinement prompts are in `docs/map-sprite-prompts.json`. `scripts/index_sprites.gd` reads alpha bounds and writes `data/sprite_regions.json`; it does not alter pixels. Hand-chosen search regions accommodate the widest weapons without including neighboring characters. The older class atlas remains the fallback for enemies.

## Facial texture and model inspection

`assets/art/face-features.png` is an original transparent eight-face feature atlas generated with the built-in image tool on 2026-10-29. Exact prompt: `docs/face-features-prompt.txt`. It supplies painted eyes, brows, nose and mouth details on curved 3D facial surfaces; characters remain fully 3D during combat. Each recruit selects a feature variant, skin/hair palette and short/long/bearded silhouette. Sculpted hair locks, collars, harnesses, armor trim and boot fittings add depth to the shared rigs. The company record's combat-model viewer exposes rotation and attack poses for visual review.

Water uses a shared world-space animated ripple shader. Ground receives broad color variation, tree crowns have varied heights/asymmetry, and village arenas include a cart, barrels and fences. These remain prototype art rather than a claim of matching finished 3DS character quality.

Original foliage card atlas: `assets/art/foliage-cards-v1.png`, made with built-in image generation, then edited through the same tool for wider transparent gutters. Prompt record: `docs/foliage-card-prompts.json`. Oak/willow sprays now form crossed alpha-cut cards in tree crowns, with gentle shader wind; 3D trunks and branches remain. No downloaded third-party models are included. In-game visual verification is pending browser permission; alpha gutters and all scene constructors are checked locally.
