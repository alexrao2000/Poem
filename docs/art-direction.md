# Art direction and asset provenance

Target: the readable sprite-on-3D tactical presentation and close-up 3D combat of Fire Emblem Awakening and Fates. Reference screenshots are linked in DEVELOPMENT.md; no reference pixels are included in the game.

## Exploratory 2D visual requirements

The [reusable 2D requirements package](visuals-2d/README.md) explores animated pixel characters with either 2D tilemaps or 3D terrain, informed by Dyadem's presentation. The implemented [visual foundation](../visuals/README.md) contains original generated sprite and environment atlases, a validated catalog, shared animation playback, effects, two map adapters, and a portable preview. The title screen's Visual workshop runs both renderers against the same separate tactical skirmish. The main campaign's renderer and separate 3D combat remain in place. Exact art prompts and provenance are in `visuals/source/generation-prompts.json`; production gaps and integration context are in [integration notes](visuals-2d/integration-notes.md).

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

The campaign map uses the [animated class catalog](../visuals/README.md) for all eight classes, extended by [individual recruit animations](../campaign_visuals.json). All 24 recruits have twelve original source poses each, with four directional facings, walking, attack and recoil states. Enemies and missing optional recruit art use class sheets. [Generation prompts](recruit-animation-prompts.json) record the built-in image tool inputs and original character references. The [atlas indexer](../scripts/index_recruit_animations.py) reads transparent separators and records crop regions and foot pivots without editing source pixels; constant pixel density prevents differently sized crops from stretching. Each pose anchors its lowest visible foot pixel, and west attacks mirror their right-facing contact pose around that pivot. The campaign adapter adds team tint, selection/spent markers, sprite-sized mouse picking and healing effects while keeping the portable renderer independent of campaign rules.

`assets/ui/weapons/` contains six original SVG weapon silhouettes authored directly as vector paths: sword, lance, axe, bow, tome and staff. The same lookup supplies combat nameplates, unit inspection and the arsenal. Their isolated asset render was checked on dark blue and parchment backgrounds; in-game bounds are covered by the combat/forecast layout checks.

## Facial texture and model inspection

`assets/art/face-features.png` is an original transparent eight-face feature atlas generated with the built-in image tool on 2026-10-29. Exact prompt: `docs/face-features-prompt.txt`. It supplies painted eyes, brows, nose and mouth details on curved 3D facial surfaces; characters remain fully 3D during combat. Each recruit selects a feature variant, skin/hair palette and short/long/bearded silhouette. Sculpted hair locks, collars, harnesses, armor trim and boot fittings add depth to the shared rigs. The company record's combat-model viewer exposes rotation and attack poses for visual review.

Water uses a shared world-space animated ripple shader. Ground receives broad color variation, tree crowns have varied heights/asymmetry, and village arenas include a cart, barrels and fences. These remain prototype art rather than a claim of matching finished 3DS character quality.

Mounted combat figures use chestnut, ivory and gray coats for Bram, Una and Elian, following their map identities. The [mount builder](../scripts/mount_visuals.gd) adds saddles, bordered saddlecloths, bridles, reins, stirrups, tapered manes, ears, eyes and articulated tails. Head and tail motion stay separate from tactical actor movement. Shared strand materials allow rigid details to batch inside their own joints: the full 24-character roster now combines 1,779 source meshes into 994 batches, verified against unbatched positions, normals and UVs in seven poses. This measures mesh submissions, not browser frame rate.

The [recruit profiles](../data/characters.json) also select individual cloth and cape colors. The [hair builder](../scripts/character_hair.gd) provides ponytails for Sera and Yuna, braids for Mara/Faye/Vela, Esme's side braid, Una's bun and curls for Petra/Ari, alongside the existing long, short, bearded and bald silhouettes. These are procedural improvements to identity continuity, not imported production character models.

Infantry pose endpoints lower the body and leg roots together using the lowest boot sole as support. Actual boot vertices are checked across seven classes and six poses to keep a supporting foot at ground level without sinking. Mounted actors keep their seated posture and horse gait. Approach locomotion remains a procedural stride rather than full foot-locking IK.

The [paired forecast cards](../scripts/battle_forecast.gd) move the two-unit comparison from the narrow command sidebar onto the battlefield, informed by the portrait-and-stat arrangement in this [Fates reference](https://www.superjumpmagazine.com/replay-review-fire-emblem-fates-for-nintendo-3ds/). Original portraits, blue/red headers, parchment panels, weapon icons, HP meters and aligned damage/hit/critical values retain the project's own artwork. The cards leave the command sidebar and help strip clear, hide during combat, and dismiss when the keyboard cursor chooses another tile. Display values are the existing rules' forecast, not a new damage calculation.

Original foliage card atlas: `assets/art/foliage-cards-v1.png`, made with built-in image generation, then edited through the same tool for wider transparent gutters. Prompt record: `docs/foliage-card-prompts.json`. Oak/willow sprays now form crossed alpha-cut cards in tree crowns, with gentle shader wind; 3D trunks and branches remain. No downloaded third-party models are included. In-game visual verification is pending browser permission; alpha gutters and all scene constructors are checked locally.
