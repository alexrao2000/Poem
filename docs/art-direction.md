# Art direction and asset provenance

Target: the readable sprite-on-3D tactical presentation and close-up 3D combat of Fire Emblem Awakening and Fates. Reference screenshots are linked in DEVELOPMENT.md; no reference pixels are included in the game.

## Exploratory 2D visual requirements

The [reusable 2D requirements package](visuals-2d/README.md) explores animated pixel characters with either 2D tilemaps or 3D terrain, informed by Dyadem's presentation. The implemented [visual foundation](../visuals/README.md) contains original generated sprite and environment atlases, a validated catalog, shared animation playback, effects, two map adapters, and a portable preview. The title screen's Visual workshop runs both renderers against the same separate tactical skirmish. The main campaign's renderer and separate 3D combat remain in place. Exact art prompts and provenance are in `visuals/source/generation-prompts.json`; production gaps and integration context are in [integration notes](visuals-2d/integration-notes.md).

The first build's floating board, flat spheres, identical block sprites and wooden mannequin combatants were rejected by the user. Do not treat that aesthetic as the target. The current rebuild is an intermediate step, not an equivalent of the reference games.

## Original raster assets

Created with the built-in image-generation tool on 2026-10-29, then copied into the project. Alpha is preserved for sprites. Godot uses atlas regions; no Nintendo assets or extracted game models are used.

- `assets/art/terrain-atlas.png`: square 2-by-2 ground atlas. Prompt: original painterly medieval tactical RPG diffuse textures; equal quadrants without gutters; top-left sage grass with moss and tiny golden blades, top-right gray-beige irregular cobblestones with moss seams, bottom-left ochre dirt and fine gravel, bottom-right worn blue-gray slate flagstones; orthographic materials, no perspective, text, border or objects; subdued hand-painted albedo. Terrain shader selects quadrants in world space, reduces saturation, and uses mipmaps.
- `assets/art/class-sprites.png`: transparent 4-column, 2-row atlas. Prompt: eight original detailed hard-pixel Japanese fantasy tactical map sprites, full body, equal cells, three-quarter front view from above, three-head-tall proportions, blue/cream/gold/silver palette. Top row: female sword commander with chestnut hair and white mantle; silver armored lance knight; hooded archer; blue-coated mage with cyan orb. Bottom row: white-robed staff healer; chestnut mounted lancer; rugged red-haired axe warrior; short-haired blue-scarfed duelist. No text, labels, background, grid, existing characters or cell overlap. The generated sheet has some padding imperfections; regions are inset to suppress neighboring fragments. The class sheet now serves the portable workshop and fallback path; the campaign uses the separate individual recruit animation catalog.

## Next quality targets

- Review the assembled maps, dialogue, movement and combat in a rendered build when platform access permits; the current projection/resource checks do not replace art review.
- Replace procedural combat figures with higher-detail authored skeletal models while preserving the existing fallback, equipment identity and animation/socket contracts.
- Refine individual silhouettes, materials and expressions against the original roster portraits, guided by rendered review.
- Develop more personal attack/reaction clips while retaining planted contacts, controlled pacing and resolved gameplay outcomes.
- Measure browser rendering performance before setting device-specific quality budgets; current mesh counts are not frame-rate measurements.

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

Mounted combat figures use chestnut, ivory and gray coats for Bram, Una and Elian, following their map identities. The [mount builder](../scripts/mount_visuals.gd) adds saddles, bordered saddlecloths, bridles, reins, stirrups, tapered manes, ears, eyes and articulated tails. Head and tail motion stay separate from tactical actor movement. Shared strand materials allow rigid details to batch inside their own joints: the full 24-character roster now combines 1,794 source meshes into 1,066 batches, verified against unbatched positions, normals and UVs in eight poses. This measures mesh submissions, not browser frame rate.

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

The wooden bow grip now sits at the holding hand. Two string segments stay fixed at the bow tips and meet the arrow nock while it draws back 0.30 world units. The drawing arm uses a bounded two-segment constraint, with a small inward bow-arm angle so every archer can reach the string. The drawing hand releases during the shot; the nocked arrow hands off continuously to the flying tip. Tests sample the whole windup at infantry/mounted target heights in both directions, and compare geometry in all tested batched poses.

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

## Weapon follow-through

Attack contact now flows into a 160 ms weapon-specific recovery before a 120 ms return to ready. Swords and axes carry the arm/body turn past contact; spears retract the grip while remaining aimed; bows lower the released hand; spell users lower their casting arms. The defender settles or falls alongside that recovery. Released arrows and javelins remain hidden until the ready stance reloads them. The contact endpoint, hit stop and resolved result remain unchanged.

An optional authored `recover` mapping takes precedence; unmapped authored actors use their existing idle section. Checks cover planted feet, actual weapon-tip displacement/ground clearance, spear grip retraction, delayed reload, all 24 rigs before/after batching, complete counter/follow-up order and skipping during recovery. The added presentation does not move either combatant's engagement position or consume gameplay RNG.

## Three-act paired score

Chapters 1–4 retain “A Standard at Dawn” (108 BPM, 71.111 seconds). Chapters 5–8 use the new “The Road Beneath the Ash” (96 BPM, 80 seconds), and chapters 9–12 use “Dawn Without Kings” (120 BPM, 64 seconds). Each original 32-bar theme has separate calm and Ablaze arrangements with identical decoded frame counts. The latter two pieces are authored in `scripts/render_campaign_music.py`, using the existing 33 pinned CC0 VSCO recordings, original note/harmony timelines and synthesized percussion. No Nintendo music or recordings are included. Source provenance and license remain in `assets/audio/`.

Changing act crossfades over 450 ms, with at most one outgoing player. That outgoing player retains its actual running decoder/playhead while the new pair loads; it is never duplicated or sought backward for the fade. Moving between chapters within an act keeps the current stream and playhead. Combat still blends the two synchronized arrangements without restarting them. Muting during a transition cancels the outgoing source and any volume tween. Camp, dialogue and direct battle/load entry all select the chapter’s theme before presentation.

The previous loop calculation divided imported resource bytes by the PCM stride, but Godot imports these WAVs as QOA: its `data` is compressed, so that calculation shortened the first theme to roughly 14.36 seconds. Loop endpoints now use composition frame metadata, validated against decoded duration. An offline test mixes each of the six actual imported streams through its complete duration and checks the playhead at every chunk and after wrapping. This follows the documented [AudioStreamWAV format semantics](https://docs.godotengine.org/en/4.5/classes/class_audiostreamwav.html) and [AudioStreamPlayback.mix_audio API](https://docs.godotengine.org/en/4.5/classes/class_audiostreamplayback.html#class-audiostreamplayback-method-mix-audio).

Checks cover all twelve chapter mappings, exact paired durations, continuous combat mixing, interrupted fades, mute, unchanged roster/RNG and resources inside the release package. New raw renders have peaks below 0.88 and seam steps below 0.022; listening review remains outstanding. Rapid menu replacement also exposed a deferred layout callback holding a freed Control; deferred sizing now resolves a weak reference before calling it.

## Sparse painted ground cover

An original four-cell transparent atlas adds low grass, ferns, shoreline reeds and a few cream wildflowers. It was generated and gutter-refined with the built-in image tool; the selected PNG is unchanged at `assets/art/ground-cover-v1.png`. Exact prompts and source output paths are recorded in `docs/ground-cover-prompts.json`. `scripts/index_ground_cover.py` only measures alpha bounds/root pivots into JSON; runtime UVs use those bounds. All four plants retain more than ten percent transparent margin within their cells.

There are 192 deterministic clumps across the campaign’s natural outdoor maps. Planting stays near eligible plain/forest/hill tile edges, away from road, wall, shrine, objective, bridge and building-footprint cells. Reeds require a natural adjacent water tile; hill plants avoid the existing boulder. Stone and industrial chapters do not receive meadow plants. Each clump uses two crossed cards/four triangles with measured ground pivots, a shared material and cached geometry. Root-weighted subtle wind survives static batching through UV2; batching now preserves each source’s extra culling margin. Small clumps cast no additional shadows.

Outdoor combat cutaways use the same plants beyond the engagement corridor, grounded on the actual central/distant floor height. River arenas keep plants out of background water, and wooden bridge cutaways omit them. Tests inspect the complete card envelope, open standing area, deterministic chapter placement, root/wind weights, original alpha gutters, arena clearance and batching equivalence. Current static map geometry totals 13,554 source meshes / 626 spatial batches across all twelve maps, plus the existing fourteen cloth instances and atmosphere. These are geometry/resource checks; current rendered appearance and browser FPS remain unverified.

## Promotion silhouettes and outfit previews

All sixteen training branches now layer distinct costumes onto the original recruit rigs. Defensive paths add overlapping shoulder lames, bracers, longer tabards or a shield rim; mobile paths use shorter mantles and split sashes. Spell/staff branches distinguish layered stoles, protective plate and small sun/star devices. Pathfinder/Wayfarer add a travel satchel, and Stormbreaker uses one reinforced shoulder with crossed harness straps. `data/promotion_looks.json` separates these visual choices from the actual promotion bonuses.

The twenty-four recruits retain their individual face, hair, cloth/cape palette and mount. Promotion construction never replaces a joint, weapon or socket; added rigid parts join the existing material/joint batches and outline pass. The optional authored-model catalog still takes precedence, and these shipped actors remain procedural. Unpromoted, enemy and incompatible preview data retain their existing looks.

Training confirmation now offers “Preview outfit.” It builds an isolated copy with the proposed branch, using the existing rotatable model view and ready/windup/strike controls. Escape or Return restores the same training decision; neither preview nor return grants bonuses or saves a choice. Normal dossier viewing retains its return route.

Checks cover all 48 recruit/branch combinations, distinct geometry for both paths of each class, preserved personal appearance, matching animated joint transforms and projectile origins, one geometry/UV batching comparison per branch, unchanged roster/RNG and actual preview input/return. The menu audit now checks 528 layouts, including short-window training previews and confirmations. Export smoke checks construct all sixteen costumes from the packaged resources. Current rendered appearance remains unverified.

The hit-stop isolation test now observes actual process frames with only its expiry timer paused, then separately checks automatic restoration. This avoids assuming that a short startup timer guarantees a newly created tween has already updated. Production hit-stop timing is unchanged.

## Outward armor lighting and tailored caster robes

The shared ascending-ring shell constructor had reversed winding: a simple elliptical shell measured an average radial-normal agreement of −0.88545. Reversing its triangle order gives +0.88545, so torso/armor/collar/trim faces and their outline expansion point outward. All base and promoted recruit shells now have per-vertex lighting/outline and triangle-orientation checks; geometry positions, rigs and contact reach are unchanged.

Caster skirts now use a shared original mesh with eight restrained folds, a widening split front, an uneven ankle-length edge and a separate fitted gold hem. The fabric uses 192 triangles and the hem 64, replacing the two cone/cylinder pieces without adding nodes or joints. The existing cloth colors, UV painting and rigid body animation are retained. Checks cover caching, winding, non-degenerate triangles, the open front, bounded dimensions and ground clearance through ready, preparation, contact and recovery, plus the existing 24-rig batching equivalence. These are still procedural garments rather than skinned cloth simulation.

Source review also found duplicate back-face normal flips in foliage, wind cloth and ground-cover shaders. Godot 4.5 Compatibility maps `cull_disabled` to `DO_SIDE_CHECK` in its [material compiler](https://raw.githubusercontent.com/godotengine/godot/4.5-stable/drivers/gles3/storage/material_storage.cpp), and its [scene fragment pipeline](https://raw.githubusercontent.com/godotengine/godot/4.5-stable/drivers/gles3/shaders/scene.glsl) orients back-face normals before running user fragment code. The extra flips have been removed; custom vertex normals remain. This conclusion comes from engine source, not a rendered comparison.

## Dedicated enemy army sprites

Eight enemy class identities now use their own original crimson, charcoal and steel atlas, with natural skin, hair and brown horses. Hooded infantry, helmeted knights, veiled healers and scarfed skirmishers give the army a coherent silhouette language. The full-sheet red multiplier is removed for these assets, while the existing gray spent-state treatment and red health-bar borders remain. Unavailable optional artwork still falls back to tinted portable class sprites.

The unchanged generated PNG contains 96 poses. A spacing pass and targeted cavalry-lance correction removed visible overlaps; the metadata indexer reads actual transparent separators and foot pivots without altering pixels. A constant source density avoids pose-to-pose resizing, and westward attack frames mirror around their foot pivot. Portable class animation timings and gameplay rules remain unchanged. The atlas still has two-step movement and shared attack/recoil poses; it is not a frame-for-frame recreation of the reference games.

`docs/enemy-atlas-prompts.json` records all three built-in image generation prompts and the selected source. `enemy_visuals.json` keeps campaign army art separate from the portable visual workshop. Pixel checks cover all 96 frame edges; runtime checks cover all eight classes, five states, four directions, authored-color preservation, spent shading, and missing/malformed supplement fallback. The atlas itself was inspected, but the latest running game still needs rendered visual review.

## Cape bending through combat

The existing cape joint still follows the character, while a shared shader function adds small bends toward the hem. The shoulder edge remains fixed. Advance, strike, recovery and reactions smoothly increase motion, then settle toward a restrained ready-state ripple. Displacement is bounded below 8 cm; mesh culling margins cover 10 cm. Analytic inverse-transpose normals follow the bend for lighting and the thin outline, and both passes use the same function and actor-owned clock. Local hit stop freezes that clock with the fighter instead of leaving cloth animated by global shader time.

Each cape owns its fabric and outline materials. Shared armor, weapons and body fabric never opt into deformation. Rebinding after rigid batching preserves independent state; source geometry and this deformation adds no mesh batches (the current roster totals 1,794 sources / 1,066 joint batches). Tests exercise all 24 recruits, attachment geometry, per-actor material isolation, paired clocks, action-to-idle settling and real hit-stop pause/resume. Export checks include the new shader dependency. This is bounded procedural secondary motion, not physical cloth simulation; rendered tuning remains pending.

## The campaign route

The war council's Route button opens an original illustrated valley map: riverside towns, forest road, ruined abbey, causeway, harbor, eastern pass, aqueduct, hilltop monastery and northern capital. The unchanged generated parchment illustration is `assets/art/campaign-valley-v1.png`; its exact built-in generation prompt is recorded in `docs/campaign-map-prompt.json`. Normalized landmark positions keep the overlay aligned when the map is fitted to its available space without stretching or cropping.

Dotted roads, numbered seals and a small pulsing standard show the company's progress. Reached chapters reveal their existing title, place and tactical briefing in a scrollable side panel. Future seals reveal no briefing, and all browsing is read-only: no chapter jumps, battles, roster changes or save mutations. The return button and Escape lead back to the war council. Runtime checks cover all twelve chapters at three desktop sizes, marker bounds and hit-target separation, actual button navigation, locked selection, and campaign-state isolation. The full menu audit now covers 564 layouts. The illustration was inspected separately; the assembled running interface still needs rendered review.

## Cleaner facial features and a shaped head

`assets/art/face-features-v2.png` replaces the overly realistic facial decal with eight simpler original anime-style eye, brow, nose and mouth sets. Existing iris/feature assignments are retained. The source is copied unchanged, with the selected fresh-generation prompt and rejected reference-preserving edit recorded in `docs/face-features-v2-prompts.json`. Pixel checks confirm transparent gaps, isolated cells and no visible red/yellow mask-edge colors at the actual alpha threshold. The earlier atlas remains available as source history.

A shared original 512-triangle head mesh now narrows at the jaw, broadens at the cheeks and incorporates a small nose. Its width/height and head joint retain the existing hair, ears and helmets. The feature overlay reuses the exact 256 front triangles with a 3 mm forward offset, keeping painted eyes and mouths fitted to the skin rather than intersecting an independently curved patch. Geometry is cached by feature variant. The separate nose primitive is removed, reducing the base roster to 1,773 source meshes; indexed skin geometry remains compatible with the existing joint batches.

Checks cover closed manifold edges, non-degenerate outward faces, feature/skin vertex alignment, atlas UV bounds, every recruit's material binding and all 48 promotion combinations. These remain procedural characters, and the new face/head combination still requires rendered inspection in combat.

## Enemy identity across views

The second enemy map atlas aligns the eight class archetypes with their existing portraits and close-up headgear: short dark hair and half-masks for vanguards, closed plumed knight helms, olive ranger hoods, plum mage hoods, ivory healer veils, mounted steel helmets, bearded corsairs and masked duelists. `assets/art/enemy-units-v2.png` is copied unchanged from the built-in image tool; its exact two-reference edit prompt is in `docs/enemy-identity-prompt.json`. All 96 frames have freshly measured transparent separators and foot pivots. Cavalry uses a slightly smaller constant source scale to stay within the map silhouette envelope.

`data/enemy_looks.json` gives the procedural actors corresponding hair, face variants, cloth and cape colors. Anonymous enemies select these profiles independently of recruit IDs, including the natural brown horse; personal goggles, signature mantles and named mounts stay with the company. Tests compare eight archetypes against 24 deliberate recruit-ID collisions, alongside atlas edges, all animation states/directions and rigid batching. Earlier image revisions remain in the repository as provenance but are excluded from release exports.

## Interface sound and score shutdown

Three original synthesized plucks in `scripts/ui_accents.py` supply a 45 ms cursor tick, 145 ms rising confirmation and 115 ms falling back cue. They use short smooth envelopes, deterministic oscillators and no extracted or sampled game audio. Exported PCM peaks are below .18, with zero endpoints and near-zero DC; listening review is still pending. Regenerating these files does not touch the paired campaign scores.

Common buttons, portrait buttons, route markers and changed keyboard map tiles use a dedicated interface voice at the saved effects volume. Hover and focus share a 70 ms cooldown, accepted presses suppress hover for 120 ms, and duplicate activation within 30 ms stays quiet. Disabled controls and cursor movement clamped at an edge are silent. This voice cannot interrupt an active combat effect. Return controls and supported Escape routes use the descending cue.

Runtime checks exercise actual button signals and cursor movement, mute/volume, priorities and unchanged game/music state. Score shutdown now explicitly stops the current and outgoing crossfade players. Twenty-eight integration suites share a shutdown helper that stops voices and gives the mixer 200 ms of monotonic time to release imported one-shot playback resources before engine exit. An isolated immediate-quit probe reproduced the warning, while the drained probe exited cleanly. This delay is test-only. The foliage batching check now reads the imported texture resource, avoiding a source-image export warning.

## Weapon releases and elemental anticipation

`scripts/release_accents.py` generates seven original deterministic mono PCM effects without touching the paired soundtrack: a light sword stroke, broader axe sweep, short lance thrust, plucked bowstring, ember rush, airy gale and electrical thunder snap. All are 140–340 ms, with smooth zero endpoints, near-zero DC and measured peaks below .39. No extracted game audio is used. Melee cues begin with the stroke; ranged cues wait until the held arrow/spear is released and the projectile starts. The existing hit/guard/critical sounds remain tied to contact.

The three folios also gather their element around the live casting socket during anticipation: warm embers, mint crescents or violet bolts inside a restrained ring. Four additive meshes remain within 36 cm of the socket, follow the actor through critical windup, and fade over 120 ms at the actual release position. No lights or gameplay randomness are added. Skipping anticipation removes the effect without launching a projectile or playing contact audio.

Tests exercise transformed stage parents, all three caster identities in both directions, socket/facing attachment, geometry bounds, release anchoring and actor removal, along with actual counters, misses, all three spells and skip restoration. The effects preserve campaign state and RNG. These are runtime/resource checks; rendered appearance and listening review remain outstanding.

## Open folios and a free casting hand

Casters hold an open original folio in the left palm while the right hand gathers and releases magic. Two angled covers and page blocks, gold corner fittings, a binding and a narrow ribbon replace the closed block book. `scripts/spellbook.gd` creates a shared 128×192 manuscript texture from geometric strokes and a lozenge; it contains no borrowed alphabet or game artwork. The isolated page texture was inspected. Printed page surfaces retain their own material without an expanded silhouette shell.

A bounded reading orientation keeps the book facing upward through locomotion, anticipation, release, recovery and reactions; the down pose releases that orientation while retaining hand attachment. The release pose separates the hands, and magic projectile sockets now come from the free hand. Staff and physical weapon sockets are unchanged.

Nine hundred sampled poses cover all three casters, six promoted variants and the enemy mage in both directions. Checks cover palm attachment, actual printed-face normals, casting-hand clearance, material/texture sharing and batching. Full-roster animated geometry remains equivalent: 1,791 source meshes become 1,012 joint batches, six more batches than before. Elemental anticipation, real exchanges and all 48 promotion looks also pass. The assembled characters still need rendered inspection.

## Open casting hands

The three caster identities, their promoted forms and the enemy mage now have small original bare hands matching their skin colors. A tapered palm, four gently bent fingers and a mirrored thumb replace each oval glove. The two shared meshes each contain 276 triangles after excluding collapsed primitive pole faces; UVs, inverse-transpose normals and closed finger caps remain intact. Their bounds fit within the previous glove envelope. A 1.5 mm silhouette width preserves gaps between the fingers without changing other character outlines.

Both palms face upward during casting and reading, then return to their local rest orientation in the down pose. The folio rises 3 cm within its holder to clear the palm, while the magic socket sits 10 cm above the right palm. Tests check actual book vertices against the palm plane throughout 900 pose samples, mirrored bounds, closed edges, nonzero area, outward winding, finger materials and the live release socket. All other weapon grips retain their existing geometry. Full-roster batching preserves animated geometry at 1,791 source meshes / 1,018 joint batches. These are geometry and runtime checks; the assembled hands still need rendered inspection.

## Dawn title illustration

`assets/art/title-dawn-v1.png` is an original 1536×1024 painted valley at dawn: a torn blue-and-ivory sun standard, a road and river, a distant citadel and small traveling silhouettes. The built-in image tool produced the illustration; it was inspected and copied unchanged. `docs/title-dawn-prompt.json` records the exact prompt and generated source path. No reference-game pixels or symbols are included.

The title, credits and title-origin options/save-transfer screens display the painting with aspect-preserving fill and 3% overscan. A very small slow drift never reveals an empty edge. The title menu narrows to 500 px, keeping the banner visible beside it. The backdrop ignores pointer input and suspends the covered map's visibility and process modes, restoring each original value when its screen exits. Campaign-origin menus retain their existing context.

Tests sample 630 crop positions across the three supported desktop sizes, check banner visibility, hidden-clock suspension and exact scene-state restoration, then use real title buttons to navigate credits, options, save transfer and campaign entry. All 564 menu layouts pass, and the export smoke check requires the title resource. The source illustration is reviewed; assembled-screen visual review remains pending.

## Painted chapter conversation backgrounds

Three original four-panel atlases now provide all twelve locations: Cinderford, Reed Crossing, Greywood, Hallow Abbey, Kingsroad, Glass Harbor, Windscar Pass, Old Aqueduct, Starfall, Reddeep, Crown Approach and the Sun Engine. Each 1536×1024 sheet is copied unchanged, and the four measured 764×508 regions inset each quadrant by two pixels. Atlas textures are cached and clip filtering to their selected region. The earlier original dawn painting served only as a style reference.

The abbey sheet was corrected through the image tool to remove the bell that the story says was taken. A separate original river view removes the barrier chain for chapter two's closing scene; the final closing conversation uses natural dawn instead of the still-active Sun Engine. `data/dialogue_scenery.json` maps chapter/phase to source art. `docs/dialogue-scenery-prompts.json` records all five exact generation/edit prompts and generated paths. The selected assets are `assets/art/dialogue-places-1-v1.png`, `dialogue-places-2-v1.png`, `dialogue-places-3-v1.png` and `dialogue-river-open-v1.png`.

Opening, closing and support conversations select their current location beneath the existing transparent speaker portraits. A lighter 20% shade keeps the scene readable while separating it from the portraits. Aspect-fill preserves proportions. Title and dialogue now share the same visibility/process-state lifecycle, so covered maps pause and restore exactly when each painted screen exits. Backdrops ignore input and never advance gameplay RNG.

Checks cover all twelve locations, 108 background fits, the two closing variants, actual victory-to-closing-to-next-chapter navigation, finale completion, support progression and all 885 dialogue layouts. Export checks require every location and closing asset. Source illustrations were inspected; the assembled running dialogue remains unverified visually.

## Chapter deployment card

Each deployment now opens with an original blue/ivory/gold chapter card over the live battlefield. Chapter number, title and location sit between thin rules and small geometric ornaments in the existing Cormorant typeface. A 200 ms fade in, 800 ms hold and 200 ms fade out lead into the normal player-phase ribbon. The camera and synchronized score continue unchanged.

A full-screen input surface prevents a skip click from becoming a tactical order. Click or Tab dismisses the card, with its own skip state so it cannot skip the following phase ribbon or combat. Deployment keeps commands locked until both announcements finish. Checks cover all twelve chapter names at three desktop sizes, text bounds, automatic completion, pointer/keyboard skip and real deployment/turn ordering without changing campaign state. Assembled appearance remains unverified.

### Idle eyelids

`assets/art/face-features-blink-v1.png` is an unchanged transparent image-generation edit of the current face atlas. Exact prompt/reference/source provenance is in `docs/face-blink-prompt.json`. Both images are 1774×887. The face shader samples the closed variant only within cell V 0.34–0.55, preserving the original brows, nose and mouth, and retains the 0.22 alpha cutoff and toon diffuse response. Individual actors blink for 105 ms at staggered 3.1–4.8-second idle intervals without using gameplay RNG. Hidden actors and local hit-stop suspend those clocks. Geometry, texture isolation and runtime states are tested; final rendered appearance is unverified.

### Finishing a combat exchange

A resolved defeat holds the surviving fighter in a restrained weapon-rest stance for 0.6 seconds (0.28 seconds settling). Sword, axe, lance, bow, folio and staff poses use distinct arm positions; infantry keeps its supporting foot planted and mounted actors retain their seat. The finishing camera moves toward the fighter’s facing side while staying on the established side of the combat axis, with extra distance for mounts. Tab cancels the hold and restores the map. Tested geometry and layout bounds do not replace a rendered animation review.

### Loose hair motion

Existing long back lengths, ponytails, braids and the side braid now retain a dedicated `HairFall` joint beneath the head. Root placement preserves every source transform, and rigid batching remains within that joint. A deterministic critically damped rotation uses restrained style-specific limits (0.06–0.14 radians); cap/bang/face geometry stays on the head. Actual vertices stay within a tested 12 cm displacement envelope. Ten recruits and the two long-haired enemy profiles share this behavior; hit-stop and hidden presentation suspend it. The roster uses 1,791 sources / 1,028 batches, with no measured FPS claim.

### Tactical travel audio

`scripts/travel_accents.py` renders six original deterministic mono 22.05 kHz PCM clips, each 100 ms (foot) or 150 ms (paired hoof), using filtered noise and short inharmonic resonances. No external samples are used. Peak amplitudes are 0.103–0.161, with zero endpoints and negligible DC. `travel_audio.gd` selects soft/hard/wood contacts through the map surface mapping and keeps two voices separate from UI, combat and paired music. Effects volume/mute applies, with travel seven dB quieter; alternating contacts vary pitch by three percent. Cues occur at tile arrival every other movement step and at the final planted stop. Listening review remains pending.

### Equipped item silhouettes

`data/equipment_looks.json` defines all 22 weapon appearances separately from combat statistics. `equipment_visuals.gd` builds cached closed blade/head meshes and keeps each class’s prior contact reach. The war hammer is blunt and beveled; the hatchet has one blade; narrow swords, broad tempered steel, braced pike lugs, three bow limb profiles, elemental folio covers/ribbons and different staff crowns distinguish the arsenal. Bowstrings use the actual limb height. Thrown spears inherit equipped head width and colors. Source geometry/material fingerprints distinguish all items; 880 pose samples and real javelin playback pass. Default roster: 1,794 sources / 1,066 joint batches. Final rendered inspection remains outstanding.

### Tactical selection polish

The keyboard cursor is now one flat corner mesh with ivory marks and a dark blue outline, replacing eight shaded blocks. A 2.5% scale pulse stays within the selected tile. Selected-unit rings flatten to 45% of their former tube height and pulse by 4.5%; hidden campaign sprites suspend idle motion. The selected-unit card reuses the combat health gauge at a compact size with ratio-dependent green, amber and red fill, alongside exact HP/ATK values. Existing interaction and layout checks cover the integration; rendered appearance remains unreviewed.

### Named commanders

`assets/portraits/commanders-v1.png` is the unchanged framed revision of twelve original commander portraits. Exact generation/edit prompts and source paths are in `docs/commander-portraits-prompts.json`; `data/commanders.json` records measured atlas regions, eye-focus points, model palettes and original critical calls. The source is 1254×1254, with measured column dividers at 312/626/940 and row dividers at 410/820; four-pixel insets exclude the borders. Named models share their class silhouettes while matching personal cloak/armor/hood colors, plume colors and mage circlets. `assets/ui/commander.svg` is an original vector crown used above the existing class map sprite. Crown hit bounds participate in unit picking. Named identities require the actual enemy commander flag and matching name/class, with class fallbacks for ordinary soldiers and unknown saves. All twelve chapter lookups, model isolation, portrait crops, 36 critical layouts and real critical-call integration pass. Full gameplay rendering remains unreviewed.

### Opponent gaze

A separate `Gaze` joint above the existing `Head` lets procedural combatants look toward their opponent’s live eye position without replacing animated head poses. Pitch is limited to ±0.32 radians and yaw to ±0.45, with smooth settling. Recoil, evasion, defeat and finishing poses relax that offset. Both fighters are bound by weak references at cinematic setup; hidden presentation and hit-stop freeze the controller. Tests cover 384 roster/facing/height/pose samples, moving and deleted targets and real mutual binding. The extra transform adds no mesh batches. Authored models may provide an optional gaze socket; otherwise the adapter returns a point above its impact socket. Rendered animation review remains pending.

### Preparation portrait cards

The council replaces long biography/stat rows with two columns of compact parchment cards. Each leads with its original portrait, name, class, level, HP and equipped weapon icon/name. A blue border and “IN COMPANY” label distinguish deployment; locked recruits retain their join chapter and disabled controls. Support-ready labels remain visible. Full statistics, biography, equipment and supports stay in the dossier. The deployment button restores the same scroll position and keyboard focus after the new grid has laid out. The opaque council shares the painted-screen scene suspension, loaded at runtime to avoid a measured Godot 4.5.1 preload shutdown-retention issue. Interaction, capacity, lifecycle and existing desktop layout checks pass; assembled rendering remains unreviewed.

### Fortified towers

Six authored tower landmarks now use `fortification.gd` instead of plain cylinders and eight box merlons. Seven staggered courses contain small physical joints and restrained stone-color variation; three projecting bands, closed wedge battlements and an inset deck retain a readable fortified silhouette. Each shared mesh has 2,080 triangles and one vertex-color stone material. Map positions and the 1.4 m base footprint are unchanged, and nearby combat backdrops reuse the same geometry at their existing larger scale. Geometry tests inspect actual top intersections to distinguish merlons, open gaps and deck height, as well as all triangle normals/winding and both map/arena bindings. Current map totals: 13,554 source meshes / 616 batches. Rendered review remains outstanding.

### Combat travel footwork

Procedural approach gait now advances by signed distance along the fighter’s facing direction: 1.6 m per infantry cycle and 2.8 m for mounts. Stationary fighters hold the stride; backward reach adjustments reverse it. Infantry hips and legs share the computed supporting-foot height, and pose tweens relinquish those translations during travel. Horse head movement follows its gait phase while the rider retains a seated pose. Approach duration scales with distance at 5 m/s within 0.18–0.65 seconds, and Tab cancels the travel tween before preparation begins. Tests sample actual boot vertices over 2,304 roster/facing/direction steps, stationary behavior, consistent frame subdivision, mounted seating, pose ownership and a real skipped approach with full tactical restoration. This is improved procedural travel; it is not a claim of authored animation or complete horizontal foot locking, and rendered review remains pending.

### Forecast weapon matchups

Small original vector triangles now sit beside forecast weapon names: green/up for advantage and red/down for disadvantage, with text tooltips and separate horizontal space. Neutral pairings and unavailable counters hide the marker. `Rules.forecast()` exposes its existing triangle modifier so presentation does not duplicate matchup logic or change damage/hit calculations. Tests cover all 36 family pairings, both sides, no-counter cases and roster layouts at 1024×640, 1280×720 and 1440×900.

### Tiered town fountain

`fountain.gd` replaces the opening-town stack of cylinders with a lathed lower basin, tapered pedestal and upper bowl. Two inset water disks reuse the existing ripple material with proper planar UV/tangent frames. Four thin crossed-ribbon jets leave the upper bowl and land above the lower water, with moving glints and softened edges in `fountain-flow.gdshader`; depth testing remains active. The shader uses Godot’s documented [fog-disabled mode](https://docs.godotengine.org/en/4.5/tutorials/shaders/shader_reference/spatial_shader.html#render-modes) to keep faded edges clear. All three meshes are cached, total 1,056 triangles and remain inside the existing tile. Map and nearby arena bindings, actual basin/water height intersections, jet bounds and twelve-map batching pass. Current scenery totals: 13,554 sources / 616 batches, plus cloth and atmosphere. Rendered water appearance remains unreviewed.

### Dialogue readiness

The active speaker’s name now sits on a compact blue plate with ivory display lettering and a restrained gold border. A small original diamond appears at the opposite side of the header only when the line has finished typing; its opacity pulses between 0.4 and 0.9. The existing action button shows “Reveal text” during typing and “Continue” afterward, with matching keyboard hints and tooltips. Main refresh/reveal actions update that state immediately; hidden stages suspend the pulse. Actual two-step button behavior, instant-text preference, speaker continuity and all 885 story/support layouts pass. No dialogue text or progression changes.

## Castle gatehouse

The castle arena's old flat wall and freestanding column row are replaced by a closed-mesh arched gatehouse, recessed open iron grille, cornices, battlements and six engaged square buttresses. The 35-meter backdrop remains nine meters behind the combat center; supports leave the central approach clear. Shared masonry has 216 triangles and an actual curved void, with separate wedge-stone arch trim. Ray tests verify the opening, header and piers; grille bounds follow the arch and the entire castle assembly retains its original width. All twelve map and arena batching comparisons pass. This is original procedural architecture; rendered review remains pending.

## Combat travel contacts

Procedural actors emit alternating contact signals at stride extrema, driven by signed ground travel rather than a timer. The existing six original foot/hoof samples play through the separate travel voices at the effects setting minus seven dB. Arena surface selection follows the actual backdrop floor, including wooden harbor decking. Final tween travel is applied before the attack pose takes ownership; stationary counters, hidden actors and non-travel poses emit no extra steps. Imported models retain their animation ownership and may opt into the same contact signal. Forward/reverse and single/multiple-frame strides, real sword exchanges and mounted harbor combat are tested without changing simulation or music. Listening review remains pending.

## Curled combat gloves

`grip_hand.gd` replaces the non-caster oval gloves with original closed palm, finger and thumb surfaces. Four curved digits leave a central longitudinal grip channel, and thumb/palm geometry mirrors by hand. The meshes remain within the former 15 × 17 × 13 cm bounds and attach directly to the existing elbow joints; weapon sockets and reach are unchanged. A separately cached leather surface limits finger outlines to 1.5 mm. Geometry tests cover closed surfaces, outward faces, grip clearance, both handed shapes and roster/enemy wrist attachments through six poses. All 22 weapon appearances and rigid-batch geometry remain valid. The default roster uses 1,794 source meshes / 1,066 joint batches. Rendered review remains pending.

## Portrait-led forecasts and finishing lines

The saved Fates forecast reference was re-inspected for its larger opposed portraits above compact statistics. Poem now stages the existing original transparent recruit dialogue cutouts and enemy portraits above 214-pixel stat cards. Portraits remain outside the name and value rows, below the top HUD, inside their own side's horizontal bounds and clear of the command sidebar. Even at 1024 × 640 they leave over 200 pixels of central battlefield open. Artwork ignores pointer input; all values, matchup arrows and confirmation rules remain unchanged. Tests cover all 24 recruits at three desktop sizes, real retargeting, cinematic concealment/restoration and keyboard controls.

Each recruit also has an original `finish_quote` in `data/characters.json`, grounded in their existing biography. Only a confirmed player survivor receives it, during a 0.95-second skippable finishing stance. Enemy and unknown identities retain the prior name-only 0.60-second finish. All 24 full captions fit the narrowest supported viewport; actual kills, counter kills, surviving exchanges and Tab skips keep their existing outcome and map restoration. No voice recordings are implied. Assembled visual review remains pending.

The forecast's original crossed-blade target cue follows the actual sprite's projected top edge as the map camera moves. It ignores input and hides beneath portraits, cards, the top HUD or outside the playable area; it can reappear after panning and pauses with the cinematic forecast. Portraits start at least 112 pixels below the viewport top, leaving clearance beneath the battle header. All 58 suites passed for the portrait/finishing pass; after this cue and clearance adjustment, forecast, controls and complete presentation flows were rerun before refreshing both exports.

## River-scroll panel ornament

`assets/ui/river-scroll.svg` is an original hand-authored 96-pixel vector tile of curled stems, leaves and a small central diamond. It repeats at 10–12 percent opacity inside the existing blue/red combat-nameplate polygons and forecast header rectangles, behind all text and borders. The standalone two-color sample was inspected; Godot's imported asset contains 1,598 stroke pixels with transparent spacing. Existing HUD and forecast layout suites pass, and no sizes or input regions changed. Texture drawing follows the [Godot 4.5 CanvasItem API](https://docs.godotengine.org/en/4.5/classes/class_canvasitem.html#class-canvasitem-method-draw-colored-polygon). No reference-game pixels are included; assembled game review remains pending.

## Held combat fast-forward

A temporary `combat_playback.gd` overlay owns the presentation clock for one full cinematic, including map-to-arena transitions. Holding Shift doubles the prior clock scale; releasing it restores that scale. A key held on entry is honored, focus loss clears acceleration, and explicit completion or scene cleanup restores the previous value. Tab remains skip, while the map's Space shortcut remains separate. The bottom hint fits all three desktop sizes. Map-only combat never creates the controller.

The already-resolved event sequence, roster state, RNG and restored tactical camera remain identical in normal and accelerated test exchanges. The synchronized calm/Ablaze stream and audio pitch are unchanged. Godot documents that [Engine.time_scale changes animation/timer deltas but does not speed audio playback](https://docs.godotengine.org/en/4.5/classes/class_engine.html#class-engine-property-time-scale). The existing combat presentation uses transforms and tweens, not physics bodies. Tests exercise real input dispatch, focus loss, teardown, a measured faster exchange, a mid-approach Tab skip and the map-only preference. Rendered and listening review remain pending.

## Mounted seat and ground contact

Headless inspection of actual source vertices found the mounted pelvis 18.5 cm above the saddle and the standing hooves 4.5 cm below the arena floor. The horse body and legs now meet the existing rider height: saddle/pelvis contact is exact at rest, and standing hoof minima are at ground level. Rider weapon sockets, reach, camera height and tactical position stay unchanged. The seated legs spread around the mount, and repositioned stirrup steps meet each boot's actual lowest point.

A separate registered Horse root preserves the body, head, tail and leg hierarchy through batching. Ground correction uses the four animated hoof ellipsoids and moves the horse and rider roots together. It runs after pose writes as well as during signed-distance locomotion, so walking-to-attack transitions retain contact. Defeat retains a torso slump while the pelvis is constrained to the saddle and the legs stay seated. The 2,304 roster travel samples include 288 mounted samples; ten mounted poses, including defeat, are sampled through their transitions, with actual hoof, saddle and boot/stirrup checks. Weapon-motion, finishing-camera and complete rig-batching comparisons pass. Counts remain 1,794 sources / 1,066 batches. Rendered animation review remains pending.

## Swept melee trails

`combat_trail.gd` now records the actual weapon edge during the 3D strike. Equipment supplies its furthest blade/head vertex, including each axe/hammer width, and procedural actors transform it through the animated grip. Sword/axe ribbons fade toward their inner edge; lance tips carry a narrow perpendicular stroke so a straight thrust still has visible width. History is capped at twelve samples and 22 triangles; stationary samples and degenerate faces are dropped. The final pose is sampled before a brief fade releases the effect.

Tests exercise all thirteen equipped melee items in both directions, match the sampled tip to actual source vertices, preserve world positions under transformed parents, verify geometry limits and cleanup, and observe the real cinematic beginning the ribbon during its strike. Normal/accelerated exchanges retain their outcomes. Authored rigs can provide optional `trail_inner`/`trail_tip` sockets; missing or coincident endpoints retain the earlier painted contact-accent fallback. Rendered effect review remains pending.

Forecast damage keeps its large numeral and adds a separate small green ×2 badge when the rules grant a follow-up. The badge is absent for an unavailable counter; both elements are centered together inside their damage column.

## Grounded approach dust

Combat foot/hoof contacts create a bounded pair or trio of soft, non-additive billboards. Their origin comes from the animated sole ellipsoid instead of the actor center and survives joint mesh batching. Signed travel determines drift even during retreat. Soft ground uses muted tan, hard ground a fainter gray, and wooden decks no dust. The puffs remain below the knees, retain depth testing, fade over 300 ms and release when the arena hides; no gameplay random stream is used. Effects muting changes audio only. Geometry and a real muted cinematic are tested; rendered appearance remains pending.

## Knight shield silhouette

The heavy-infantry shield now has a clipped upper edge, tapered point and shallow bowed face. A raised metal border surrounds an original diamond and paired river chevrons. Body and trim share 64 cached source triangles and the existing left forearm attachment; both friendly and enemy knights inherit their own clothing/metal palettes. Closed topology, outward normals, actual surface separation, living-pose ground clearance and rig batching are checked. The source silhouette was reviewed as a standalone SVG study, not a gameplay render.

## Archer quivers

The original back quiver now has an open annular lip, tapered leather walls and a recessed floor. Four staggered shafts enter this cavity; each has three small ivory feathers above the opening. A single tilted attachment keeps the container and arrow tails aligned through the body animation. Fine feather outlines use a 1 mm shell. Four cached material meshes replace the prior cylinder and four independent sticks; the roster now totals 1,794 sources / 1,066 joint batches. Actual opening/clearance rays, body topology, archer poses and batching equivalence pass; assembled rendering remains pending.

## Foreground combat framing

The Awakening reference uses strong perspective depth and a prominent foreground fighter. Combat now looks across the engagement axis at about 33 degrees, with a 5.4 m base infantry radius and 7.35 m mounted radius. The vertical composition leaves room for captions and the lower HUD; preparation/contact camera shifts are deliberately small. In the fixed 4 m ranged fixture, a 1.8 m foreground figure occupies 46.4% of view height, while the farther figure occupies 31.3%; the prior foreground result was 30.1%. The lens stays at 46–48 degrees.

The camera audit uses actual SubViewport dimensions and transformed head/boot/hoof bounds: 2,304 layouts across all recruits, both sides, 1.3/4 m gaps, mixed mounts, idle/preparation/critical/impact poses and three desktop sizes. Heads and soles clear the caption, viewport edges and HUD. Finishing-camera behavior is retained. Projection, transition, recovery and restoration checks pass; rendered camera/art review is still unavailable.

## Tactical readiness and selection

Spent campaign sprites now use cached grayscale frames plus even dimming, rather than retaining colored clothing beneath a tint. Frames are created only when requested, preserve source transparency and crop dimensions, and are discarded when the catalog reloads. Ready units restore the original cached frame immediately. This uses Godot’s [Image.adjust_bcs](https://docs.godotengine.org/en/4.5/classes/class_image.html#class-image-method-adjust-bcs) at zero saturation; source assets remain unchanged.

The selected unit carries a shared flat blue corner mesh inside its tile, below the ivory keyboard cursor and above route overlays. The old raised gold ring and spent check mark are removed from campaign presentation. HP fills and blue/red faction borders stay colored. Pixel, pivot, source-integrity, cache and actual controls/terrain checks pass; the portable sprite workshop retains its independent presentation.

## Layered outdoor ridgelines

Village, road, forest, river and mountain arenas replace the separate ellipsoid hills with three continuous heightfields. Each layer has an original crest profile, a different depth and a slightly cooler palette. Countryside uses smooth hill transitions; mountain profiles use sharper rises. All boundaries taper to the distant ground plane. The nearest relief starts 26 m behind the fighters, beyond the landmarks and approach space.

Six cached source meshes supply the two families; three layers total 2,304 triangles per arena. The distant geometry does not cast shadows into the fighter shadow atlas. Geometry checks cover exact shared seams, opaque restrained colors, normalized upward normals, nondegenerate clockwise faces, distinct skylines and arena placement. All map/arena batching and actual scene transitions pass. A separate SVG profile study was reviewed; this is not a rendered-game review or FPS measurement.

## Quieter combat text

The large top caption is reserved for the confirmed survivor’s finishing line. Routine weapon, damage, miss and healing headlines are removed because those events already have active nameplates, local numbers, health meters and critical cut-ins. The bottom Shift/Tab hint remains available throughout. Live exchange/healing checks keep the action area free of duplicate captions, while finishing checks require the character line to remain visible.

## Fractured stone silhouettes

Three original cached rock forms replace the shared spherical boulder shape. Uneven rings form broad shoulders, smaller upper planes and a buried base; face normals stay faceted. Each closed mesh uses 72 triangles, projects the existing stone material onto its faces, and stays within the former horizontal unit radius and upper envelope. Coordinate-derived variant selection preserves gameplay random state and every existing map/arena transform. Closed-edge, nondegenerate winding, outward normal, UV and batching checks pass. Source/batch counts remain unchanged; rendered review is pending.

## Spoked roadside cart wheels

Village and road carts now have open six-spoke wooden wheels with curved rims and narrow iron tires. Four wheels share one cached 232-triangle mesh and material; their original scale and lateral footprint are retained. Tires meet the cart’s ground plane, while two axles and four small bearings connect the hubs to the bed. Rays verify actual rim/spoke solids and open gaps; transformed-geometry checks verify ground contact and axle support. All map/arena batching checks pass. The cart remains a scenery prop and changes no terrain rules.

## Bowed wooden barrels

The warehouse, cart and roadside barrels now use a twelve-stave bowed profile with a slightly recessed lid and fitted iron hoops. Three cached meshes provide 222 triangles in two shared materials; vertex colors distinguish the wood staves and lid marks. The closed wooden body, physical inset, hoop clearance and original footprint are verified from geometry. Existing placements and scales remain fixed. Replacing seven primitive pieces with three lowers the twelve-map total to 13,554 sources / 616 batches, with all map/arena geometry preserved through batching. This is not a measured frame-rate improvement.

## Continuous pose contact and defeat expressions

Infantry now derives its support height from the currently interpolated thigh/knee rotations after each pose update. It no longer interpolates between endpoint heights independently of the legs. This removes the measured 18 mm floor penetration during hit-to-defeat and 28 mm during the preview's return from defeat. Actual boot geometry is checked through 2,016 transition samples across all 21 infantry recruits; the pelvis and upper legs share the same support offset. Distance-driven travel retains the same constraint.

Defeat holds the existing closed-eyelid atlas instead of reopening the eyes for every non-idle pose. Living reactions and finishing poses remain attentive. Per-actor materials, opaque helmets, hidden suspension and hit-stop behavior are retained; no source image is changed. Rendered animation review remains pending.
