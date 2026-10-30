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

Mounted combat figures use chestnut, ivory and gray coats for Bram, Una and Elian, following their map identities. The [mount builder](../scripts/mount_visuals.gd) adds saddles, bordered saddlecloths, bridles, reins, stirrups, tapered manes, ears, eyes and articulated tails. Head and tail motion stay separate from tactical actor movement. Shared strand materials allow rigid details to batch inside their own joints: the full 24-character roster now combines 1,797 source meshes into 1,006 batches, verified against unbatched positions, normals and UVs in eight poses. This measures mesh submissions, not browser frame rate.

The [recruit profiles](../data/characters.json) also select individual cloth and cape colors. The [hair builder](../scripts/character_hair.gd) provides ponytails for Sera and Yuna, braids for Mara/Faye/Vela, Esme's side braid, Una's bun and curls for Petra/Ari, alongside the existing long, short, bearded and bald silhouettes. These are procedural improvements to identity continuity, not imported production character models.

The [outline pass](../scripts/character_outline.gd) follows the compact character silhouettes and stronger figure edges visible in this [Awakening combat reference](https://www.superphillipcentral.com/2013/02/fire-emblem-awakening-3ds-review.html). It uses a thin reverse-culled shell, following [Godot's outline technique](https://docs.godotengine.org/en/4.5/tutorials/3d/standard_material_3d.html#grow), with separately smoothed edge directions encoded in otherwise unused vertex colors. This closes faceted corners without softening the base model's lighting. Painted face cards, transparent details and emissive pieces are excluded; original shared materials are not changed. Outlined batches add a rendering pass beyond the base-mesh counts above. Current game rendering and browser frame rate still need direct visual measurement.

The [blade builder](../scripts/weapon_blades.gd) creates closed sword, axe and spear meshes with central ridges or beveled cutting edges. Held and thrown spears share a leaf-shaped head. Geometry checks cover closed edges, nondegenerate faces, winding and unchanged reach; combat checks retain actual contact with infantry and mounted opponents. Arrow and spear flight tracks the leading vertex, with the shaft behind it, so the visible tip reaches the impact point without overshooting. Launch starts with the shaft near the animated hand.

Campaign sprites now use a compact rendering scale, guided by the tile-relative figures in this [Fates tactical reference](https://www.ebgames.com.au/product/3ds/157962-fire-emblem-fates-conquest-preowned). Idle recruit artwork occupies 0.8–1.2 world units in height on one-unit tiles; enemy class art uses the same campaign pixel size. Source pixels, atlas density, foot pivots and the portable renderer stay intact. Sprite-sized picking uses the resulting projected bounds. Dock and bridge arena plank tops align with the fighters' zero-height ground plane, with water below and no coincident central ground sheet.

The same map reference informs persistent HP bars and soft contact shadows beneath campaign sprites. Blue/red borders identify team while green/amber/red fills show remaining health; solid team plates are replaced by a shared radial shadow. Natural outdoor shores use the [river-bank height field](../scripts/river_bank.gd): adjacent and diagonal land determines a continuous slope into the water, with deterministic width variation and matching tile seams. Town canals and harbor masonry keep their constructed edges. Neither change alters terrain rules or the portable sprite package.

The battle command panel now groups Save, local transfer, options and the war council inside a centered menu, leaving unit actions and End Phase on the map. M opens it; Escape resumes the same selection and uncommitted movement. Compact spacing is checked at 1024×640 and 1280×720 alongside the standard 1440×900 layout. Keyboard focus stays within the menu, and its buttons still use the existing save, transfer and options flows.

Infantry pose endpoints lower the body and leg roots together using the lowest boot sole as support. Actual boot vertices are checked across seven classes and six poses to keep a supporting foot at ground level without sinking. Mounted actors keep their seated posture and horse gait. Approach locomotion remains a procedural stride rather than full foot-locking IK.

Miss reactions begin before the strike reaches contact. Arrows, spears and spells retain the original aim point while the defender steps aside; melee trails likewise pass the original contact location. Actual cinematic checks observe the defender already evading at release/contact and back on the combat axis before returning to the map, with unchanged simulation state and RNG.

The [paired forecast cards](../scripts/battle_forecast.gd) move the two-unit comparison from the narrow command sidebar onto the battlefield, informed by the portrait-and-stat arrangement in this [Fates reference](https://www.superjumpmagazine.com/replay-review-fire-emblem-fates-for-nintendo-3ds/). Original portraits, blue/red headers, parchment panels, weapon icons, HP meters and aligned damage/hit/critical values retain the project's own artwork. The cards leave the command sidebar and help strip clear, hide during combat, and dismiss when the keyboard cursor chooses another tile. Display values are the existing rules' forecast, not a new damage calculation.

The [enemy portrait atlas](../assets/portraits/enemy-classes-v1.png) supplies eight original class archetypes for inspection, forecast, combat nameplates and critical cut-ins. [Prompts and provenance](enemy-portrait-prompts.json) record the built-in image tool and project-owned style reference. These are shared class portraits, not unique portraits for every named foe. Opposing card portraits face inward even when the enemy initiates combat. [Enemy headgear](../scripts/enemy_headgear.gd) adds matching open hoods, half masks, helmet crests and cavalry cheek guards to procedural 3D opponents; all detail remains attached to and batched within the head.

Original foliage card atlas: `assets/art/foliage-cards-v1.png`, made with built-in image generation, then edited through the same tool for wider transparent gutters. Prompt record: `docs/foliage-card-prompts.json`. Oak/willow sprays now form crossed alpha-cut cards in tree crowns, with gentle shader wind; 3D trunks and branches remain. No downloaded third-party models are included. In-game visual verification is pending browser permission; alpha gutters and all scene constructors are checked locally.

## Two-speaker dialogue

All 24 original roster portraits now have transparent dialogue variants in `assets/portraits/dialogue-*-v1.png`. The generated files are copied unchanged; atlas rectangles use measured transparent gutters rather than an assumed equal grid. The dialogue shader discards alpha below 0.13 to remove residual background haze. The fourth sheet has narrow shoulder joins near its first column boundary; the measured region keeps that crop at the existing bust edge. Characters face inward; listeners dim without leaving the scene. The panel and busts adapt to 1024×640, 1280×720 and 1440×900. Runtime checks cover all 103 story and 192 support lines; current rendered appearance still needs visual review.

Generation prompt: [dialogue-portrait-prompt.txt](dialogue-portrait-prompt.txt). Source and generated file paths: [dialogue-portrait-provenance.json](dialogue-portrait-provenance.json). These are edits of this project’s original roster art, with no game-reference artwork included as source.

## Contact timing and guarded hits

Damaging contact holds actor processing locally for 55 ms (100 ms for criticals), after a 35 ms recoil lead. The camera, effects, UI and shared music timeline continue. This uses node-bound tween processing, described in the [Godot 4.5 Tween documentation](https://docs.godotengine.org/en/4.5/classes/class_tween.html); tests cover procedural joints, imported AnimationPlayers, cancellation and combat skipping. No global time scale changes. Zero-damage hits have a guard stance and restrained gray glint instead of damaging sparks. `scripts/combat_accents.py` generates the original short metallic sound without rewriting the soundtrack; the main score generator also includes it.

## Ground transitions and bridge openings

A small per-chapter RGBA control texture preserves the four original ground paintings at tile centers and blends only near boundaries. The world-space shader adds slight edge variation and uses mirrored texture repeats to avoid abrupt wrapping seams. All ground cells share one material, and the natural river banks use that material too. Water in masonry channels has zero painting weight, normalized out at the edge. Bridge cells now contain water at -0.07 rather than opaque ground under the raised planks. All 38 bridge cells and all twelve chapter control maps are checked; static geometry and UV equivalence remain verified after batching (13,637 source meshes → 635 batches). Rendered appearance and browser performance still need direct review.

## Bow draw and map framing

The wooden bow grip now sits at the holding hand. Two string segments stay fixed at the bow tips and meet the arrow nock while it draws back 0.30 world units. The drawing arm uses a bounded two-segment constraint, with a small inward bow-arm angle so every archer can reach the string. The drawing hand releases during the shot; the nocked arrow hands off continuously to the flying tip. Tests sample the whole windup at infantry/mounted target heights in both directions, and compare geometry in all eight batched poses.

The map action card fits its contents, freeing its previously empty lower area. A smaller terrain readout and one-line contextual hints leave more of the landscape visible; the complete control guide remains in the M-key menu. Layout and focus checks cover all tactical states at 1024×640, 1280×720 and 1440×900.

## Campaign menu layouts

The war council, dossiers, equipment, title, options, credits, training confirmations, results and model viewer now fit 1024×640 through 1440×900. Primary actions remain visible outside scrolling narrative/reading areas. The council preserves its roster and briefing in two responsive columns. All menu scroll areas follow keyboard focus; save transfer keeps at least 160 px of editable code area. The `menus` suite checks 492 layouts across the full roster, every chapter and both training choices, including last-entry reachability and unchanged progression. This verifies bounds and interaction state, not rendered styling.

## Staff recovery presentation

Staff healing follows the battle-animation preference: full/player modes use the shared map zoom and arena return; map-only mode retains its short field cue. Tonic use remains a field action. The existing rules resolve health, 30 XP and support gain once before the sequence. Both participants keep allied nameplates, with the recipient's meter starting at pre-heal HP and rising when the light arrives.

Procedural staff users have separate preparation/release poses with an upright staff constraint. Light leaves the actual crown, follows three fixed curved strands, then blooms around the recipient's chest with two foot-level rings, rising motes and a green recovery number. Mounted recipients use rider-height contact while the rings stay at the ground. The effect uses additive geometry and no extra lights or gameplay RNG. Healing never triggers recoil, dodge, hit stop or damaging sparks. Early skip and skip during the light return to the map with the resolved result intact. The synchronized score blends through the same existing calm/Ablaze timeline.

The recovery suite checks all three staff rigs in both directions, transformed effect parents, mounted height, actual field actions, repeated-input locking, rising HP, animation preferences, skip cleanup, score restoration and unchanged resolved progression. Imported actors accept optional cast mappings and otherwise use their windup/strike sections. These are runtime and geometry checks, not a rendered review.

## Focused critical portrait strip

Criticals use a 156 px full-width strip above the combat nameplates, with a closer eye-level portrait crop, a soft slanted edge, 22 directional background streaks and the existing original battle call. Enemy portraits and text swap sides as well as facing inward. The strip enters in 90 ms, holds with moving streaks for 340 ms and exits in 100 ms; the same skip callback cancels any phase.

`data/critical_portraits.json` records measured eye centers from the project's four original roster sheets and eight-class enemy sheet. Runtime nested atlas crops leave the source PNGs unchanged. No game art was extracted or copied. All 32 portraits are checked at three desktop sizes for atlas boundaries, full quote visibility, separation from text and clearance above combat HP. Tests also observe both entrance directions, moving streaks during the hold, the actual critical exchange and early cancellation without altering outcomes.

A new original 320 ms synthesized air/chime cue begins with the strip. `scripts/combat_accents.py --effect cutin` regenerates it independently; the full score generator includes the same function. It uses its own fixed synthesis seed and does not touch either score arrangement or game RNG. Runtime checks do not substitute for a rendered or listening review.

## Tactical action tracking

Moving units receive a short camera pan only when their full sprite bounds lie outside the readable map area. The camera follows them at that area's edges without changing the chosen zoom, map angle or lens offset. Map-only attacks and recovery frame both participants before the cue appears; the next player phase returns attention to the first standing ally. Normal full-arena transitions retain their existing view restoration.

Framing projects feet and upper-body points, reserves room for the command/terrain cards and respects the board's camera limits. Because clamping a world axis shifts both screen axes in the angled view, the destination is reprojected before movement, avoiding an extra corrective pan. Visible actions add no camera wait. Headless projection tests cover 18 frames and 363 tracking samples across three actual SubViewport sizes, raised ground, real enemy movement, visible map damage numbers, unchanged rules/RNG and existing cinematic ownership.

## Chapter atmosphere

All twelve tactical maps and battle arenas now carry restrained local atmosphere: tumbling leaves in forest/road scenes, rising embers in the furnace/engine, cool motes at the observatory and faint warm dust elsewhere. Each scene uses one MultiMesh with 14–32 particles, no collision, no extra lights and no cast shadows. The particles have fixed local seeds, fade before recycling, remain within explicit culling bounds and stop updating while their world or arena is hidden. At this checkpoint static scenery counted 13,637 source meshes / 635 batches; atmosphere adds one instanced object to each visible scene. No frame-rate claim is made.

Transforms and colors are uploaded together in a 16-float public MultiMesh buffer. Godot 4.5.1 headless individual instance getters return defaults, so tests inspect the submitted buffer instead. The [dummy renderer source](https://raw.githubusercontent.com/godotengine/godot/4.5-stable/servers/rendering/dummy/storage/mesh_storage.h) and [Compatibility buffer implementation](https://raw.githubusercontent.com/godotengine/godot/4.5-stable/drivers/gles3/storage/mesh_storage.cpp) explain that distinction and the public row/color layout. Tests cover every environment, actual uploaded geometry bounds, deterministic motion, low opacity, hidden suspension, loop fades and scene cleanup.

Camera-facing dust/embers and recovery glow explicitly preserve their scale. Transparent accents disable fog so fully faded quad edges cannot become visible; see the [Godot BaseMaterial3D properties](https://docs.godotengine.org/en/4.5/classes/class_basematerial3d.html#class-basematerial3d-property-billboard-keep-scale). These changes are resource/runtime checked; the current game remains unreviewed in a rendered browser/native view.

## Critical anticipation

Critical attacks deepen the preparation pose before the eye-level portrait strip. Sword/axe users raise and coil the weapon further; spears draw back with a stronger torso turn; magic opens both arms; thrown spears use a distinct overhead coil. Archers keep their proven shoulder/nock geometry and add a focused head pose. The original strike endpoint and reach remain unchanged.

Optional authored `critical_windup` and `critical_throw_windup` clips take precedence when supplied. A critical throw falls back to a dedicated throw preparation before generic windup. Geometry checks cover grounded infantry, bow contact in both directions, melee reach after the stronger anticipation and all 24 rigs before/after batching. The live cinematic check confirms the pose is established before the portrait appears. Rendered appearance is still unverified.

## Descending map-to-combat zoom

The 420 ms map approach now moves its look point toward the engaged pair while lowering the camera from the tactical angle to 38 degrees and adding a small yaw turn. Orthographic size still closes to five units; the existing radial veil conceals the arena swap. Pitch/yaw interpolate separately so the horizon stays level throughout. The return restores the exact captured tactical transform and lens values. Checks measure continuous zoom/descent, initial transform continuity, final pair centering, interrupted navigation ownership and complete return through combat/healing.

## Progression feedback

Ordinary XP uses a compact bottom panel. A level-up uses the recruit's transparent dialogue portrait alongside a five-row stat display, old/new level numbers and a segmented sequence: fill the XP meter, play the original 720 ms four-note bell figure, settle at the actual retained XP, then reveal actual HP/Power/Defense/Resistance/Speed values and their gains. Zero gains use a muted dash. The level limit uses a full meter and explicit label; multi-level gains retain their aggregate resolved values. Continue is available by mouse as well as the existing keyboard dismissal and automatic timeout.

The view does not award XP, roll growth or modify the roster. Checks cover all 24 recruits in both display modes at three desktop sizes (144 layouts), sequential reveals, actual numbers, caps, multi-level rewards, cue timing and early dismissal. `scripts/combat_accents.py --effect levelup` regenerates the original sound independently; the full score generator also includes it. Existing paired music files are unchanged. Rendered and listening review remain outstanding.

## Fitted tiled roofs

The previous roof slabs left the existing gable peak protruding by about 0.035 world units. The new closed roof underside follows the exact gable equation, with overhanging eaves, six shallow overlapping tile courses per slope, staggered joints and small ridge caps. Three subdued slate/clay/weathered palettes vary buildings without changing their walls, footprints or movement rules. Roof identity is derived from the original map location and passed through nearby combat context so the same building retains its palette in the arena.

Each palette uses one cached mesh under 600 triangles, with a shared vertex-color material. Geometry checks measure 204 roof/gable intersections, face winding/normals, overhangs and all eight campaign house/warehouse identities in their actual backdrops. Full static batching checks preserve triangles, positions and UVs across all maps/arenas; map counts at that checkpoint were 13,501 source meshes / 625 batches. These are geometry checks, not rendered appearance or frame-rate measurements.

## Equipped action reach

The blue movement region now has an orange action envelope showing where the selected unit could attack after a legal move. Staff users receive green healing reach instead. The envelope excludes blue cells to keep movement readable, while immediately attackable enemies or healable allies retain a stronger target highlight. After moving, reach originates only at the new tile; undo restores the larger preview. A short contextual legend explains the colors.

The preview reads the actual equipped item's minimum/maximum range and only projects from legal stopping cells, excluding occupied endpoints, impassable terrain and off-board targets. It never moves a unit or resolves a simulated action. Checks compare 528 equipment/chapter/movement cases against actual attack/healing legality and exercise exact overlay geometry, raised terrain, real movement/undo, stationary bow blind spots, staff styling and spent-unit cleanup. Replacing tactical overlays now detaches old nodes immediately, keeping names and contents consistent even with multiple updates in one frame.

## Wind-driven standards and sails

The twelve objective markers replace solid flag boxes with pole-pinned cloth grids, forked free edges, a restrained gold border and an original diamond device. Both campaign boats now attach canvas directly to their masts; nearby arena boats use the same cloth. Existing original linen paint provides texture. Each cloth uses 144 triangles and two low-amplitude waves whose displacement fades to zero at the attached edge, with a small downward drape. Analytic normals track the wave, and both sides receive lighting. No extra lights or physics bodies are introduced.

Per-instance phase pauses with a hidden map/arena and wraps at the waves' shared period. The cloth node stays out of static batching, preserving local dimensions and explicit deformation bounds. The implementation follows Godot's [spatial shader coordinate conventions](https://docs.godotengine.org/en/4.5/tutorials/shaders/shader_reference/spatial_shader.html) and [custom geometry bounds](https://docs.godotengine.org/en/4.5/classes/class_geometryinstance3d.html#class-geometryinstance3d-property-custom-aabb).

Checks cover attachment geometry under transformed parents, grid winding, forked/rectangular silhouettes, conservative wind/sag envelopes, material parameters, phase wrap/pause, static-batch exclusion, all map instances, actual boat backdrops and cleanup. Headless checks do not execute a rendered review of the wind shader. Current static map counts are 13,487 source meshes / 611 batches, plus fourteen separate cloth meshes across all twelve maps; this is not a frame-rate measurement.
