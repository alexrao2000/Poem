# Reusable 2D visual requirements

Status: visual requirements and production targets, 2026-10-29. A working prototype now lives in [the reusable visual package](../../visuals/README.md), with both map renderers available from the game title screen. Character sprites are the shared foundation; the production map renderer remains a separate decision. This package can be copied into another tactical RPG project without Poem code or character data.

The target is a readable, expressive handheld tactical RPG look: compact pixel characters, strong class silhouettes, restrained terrain detail, and clear tactical information. [Dyadem](https://store.steampowered.com/app/4206930/Dyadem/) is a reference for presentation and readability. Create original characters, tiles, interfaces, and animations.

## Decisions and scope

| Area | Requirement | Decision still open |
| --- | --- | --- |
| Map characters | Animated 2D sprites with consistent pixel density and grounded feet | Final pixel scale and proportions after the art test |
| Maps | Support either authored 2D tilemaps or 3D terrain through the same logical grid | Choose one renderer after comparing the same scene |
| Portraits and UI | Share character identity, palette, icons, and interface assets across map renderers | Final illustration treatment and typography |
| Close combat | Keep combat presentation independent of map presentation | In-map effects, dedicated 2D battles, or existing 3D battles |
| Gameplay | Simulation owns movement, occupancy, terrain rules, damage, and outcomes | No visual decision may change these rules |

Choosing 3D maps does not require 3D characters. Choosing 2D maps does not require replacing separate 3D combat scenes. A future fully 3D character direction can reuse identity sheets, palettes, portraits, UI, and logical contracts; sprite animation frames do not automatically become 3D rigs or animations.

MUST means required for a completed implementation. Proposed numerical budgets below establish a starting art test, rather than describing existing assets or measured performance. Freeze the selected profile before producing the full roster.

## Shared art direction

- Characters MUST remain identifiable by silhouette, weapon, and one or two costume features at normal map zoom. Distinguish infantry, armor, cavalry, archers, casters, healers, and flyers without requiring a portrait.
- Use deliberate pixel clusters, controlled outlines, and a consistent light direction. Avoid mixing soft resized illustrations with authored low resolution pixel sprites in the final set.
- Terrain MUST stay quieter than units and tactical overlays. Use recognizable landmarks and material changes to establish routes, cover, hazards, and objectives.
- Allies, enemies, neutrals, selected units, and spent units MUST have distinct symbols or marker shapes as well as color. Dimming alone must not erase a unit's silhouette or HP information.
- Each named character MUST share recognizable hair, costume colors, weapon identity, and accessories across portrait, map sprite, and any combat representation. Promotions need an explicit appearance mapping or an explicitly shared base appearance.
- Environment lighting may tint sprites gently; it MUST preserve unit identity and team readability. Terrain and sprite shading must appear to belong to the same scene.

## Proposed pixel profile

| Item | Starting specification |
| --- | --- |
| Ground tile | 32 by 32 source pixels in the 2D map |
| Infantry frame | 64 by 64 transparent canvas; visible figure roughly 26–32 pixels wide and 36–44 pixels tall |
| Large unit frame | 96 by 96 canvas for mounts, large armor, or flyers; gameplay footprint remains defined by simulation |
| Anchor | Bottom center of the planted feet; default infantry pivot at pixel coordinates 32, 56 |
| Atlas padding | Two transparent pixels outside every frame edge; no neighboring art in the padding |
| World view | Proposed 640 by 360 logical pixel viewport; HUD may render separately at display resolution |
| Scaling | Integer world scaling with nearest filtering; center unused space instead of stretching pixels |
| Minimum review size | 1280 by 720 display, including the full HUD; also review 1440 by 900 |
| Palette | Start with 16–24 colors per unit including outline and shared material ramps; transparency is separate |

The world viewport is the area available after HUD layout. If the HUD reduces it below the proposed canvas, reflow the HUD or use a smaller validated logical viewport. Do not silently crop the battlefield. Portraits and text can have a higher resolution treatment; keep map sprites and map effects on one pixel grid.

Source pixels, atlas coordinates, and screen pixels are different units. In a 3D map, calibrate the orthographic camera so a horizontal ground tile spans approximately 32 logical pixels at the reference zoom. A tilted map foreshortens ground depth; retain the same character source pixel scale rather than stretching character height to match a projected tile.

MUST preserve a fixed canvas and pivot throughout each animation. Trimmed frames require restored source offsets; independently centering cropped frames is unacceptable. Weapons, capes, and spell effects must stay within their declared frame or separate effect layer.

## Sprite animation requirements

Supply south, west, east, and north views for every map unit. Directions refer to the logical grid: east is increasing x and south is increasing y. The renderer resolves these into the current view. Mirroring is allowed only when weapon hands and asymmetric costumes remain correct; otherwise author both sides.

| State | Initial frame budget per direction | Playback and acceptance |
| --- | --- | --- |
| Idle | 4 | Loop around 4–6 frames per second; breathing or cloth motion with planted feet |
| Move | 6 | Loop around 8–10 frames per second; steps match route travel without sliding |
| Act | 4 | One shot with anticipation, contact or release, and recovery; specialize by weapon or spell family |
| Hurt | 2 | One shot with readable recoil; no accidental cell movement |
| Defeated | 4 | One shot, then hold final frame or remove according to the presentation policy |
| Selected | Reuse idle initially | External ring, cursor, or pulse; separate artwork optional |
| Spent | Reuse idle | Apply the shared spent marker and restrained dimming |

This baseline totals 80 authored frames per unit before action variants: 20 frames times four directions. Shared class sheets reduce production cost, but named units still require their defining identity cues. Healers need a support action; bows and magic need release cues and separate projectiles. Flyers need wing motion and a distinct ground shadow; mounted units need mount and rider motion that agree.

Every clip MUST declare frame order, duration per frame, looping, and optional visual cues such as `contact` or `projectile_release`. Visual cues synchronize effects with results already supplied by simulation. They MUST NOT roll hits, apply damage, or advance turns. Skipping a clip must complete presentation once and preserve the same simulation result.

## Portable asset delivery

Deliver editable source, exported RGBA PNG atlases, metadata, preview images, and provenance together. Runtime imports MUST use nearest filtering for sprites and avoid compression artifacts on alpha edges. Handle terrain texture filtering separately for each renderer.

Use stable asset IDs rather than character array order or sheet position. File paths MUST be relative to the package root. Game character IDs map to visual IDs in a project adapter; sprites must not contain campaign statistics or save data.

The [example manifest](asset-manifest.example.json) contains one representative asset from the implemented export contract. Runtime metadata, images, and the Godot loader live together in `visuals/`; the example is provided for inspection.

| Field | Required meaning |
| --- | --- |
| `schema_version`, `profile` | Version the contract and declare source pixel density and logical direction convention |
| `id`, `kind` | Stable visual identifier and purpose, such as `map_unit` |
| `texture`, `frames` | Relative file path and explicit source rectangles and pivots |
| `logical_frame_px` | Shared output canvas size in logical world pixels |
| `pivot_px` | Anchor measured from the untrimmed frame's top left; x right, y down |
| `clips` | State and facing mapped to frame indices, per-frame milliseconds, loop behavior, and visual cue indices |
| `fallback_visual_id` | An explicit compatible fallback, or null; no lookup by roster index |
| `provenance` | Creator or source, license or usage record, and editable source location |

The implemented contract uses explicit source rectangles `[x, y, width, height]` and source pivots for every frame. Duration arrays match frame-index arrays; cue indices are zero-based positions within a clip. The prototype keeps each class on a fixed untrimmed canvas. A future tightly packed export must restore source offsets and retain the same foot anchor.

The importer MUST reject invalid rectangles, missing textures, unknown directions, duplicate IDs, invalid durations, missing required clips, and incompatible profile versions with an actionable asset ID. Validate transparent gutters and fixed foot placement in a visual contact sheet. Development fallbacks may display a class silhouette with a visible missing-art marker; release builds must have complete mappings.

Keep a portable folder structure such as `source/`, `textures/units/`, `textures/portraits/`, `textures/effects/`, `metadata/`, `previews/`, and `licenses/`. Preserve original and generated asset provenance, including prompts when applicable. Changing the pixel profile requires a version change and review of dependent assets.

## Renderer boundary

The core visual package MUST be independent of a particular game engine. A project adapter translates it into engine resources and resolves game IDs. The map renderer owns projection, terrain drawing, occlusion, picking, and draw order; a sprite player owns clips, pivots, facing, and cosmetic cues.

| Contract | Required behavior |
| --- | --- |
| Map input | Logical cells with stable terrain IDs, occupancy, objectives, and optional elevation |
| Unit input | Stable unit and visual IDs, cell, facing, team, HP, status, and presentation state |
| `cell_to_world` and `world_to_cell` | Convert through the renderer's coordinate system without changing logical cells |
| `screen_to_cell` | Return a valid selectable cell or no hit; separate unit hit areas from decorative art bounds |
| Movement | Animate an already validated cell route; restore the exact origin on cancellation |
| Combat presentation | Consume resolved outcomes, play effects, and signal completion once, including when skipped |
| Overlay input | Legal movement, attack reach, threat, route, target, and objective information from gameplay |
| Camera state | Frame selected cells and restore focus after actions; keep camera state outside campaign saves |

Use logical coordinates `(x, y)` in simulation. A typical 2D adapter places cell centers at `((x + 0.5) * tile_size, (y + 0.5) * tile_size)`; a 3D adapter may use `(x, terrain_height, y)` in world space. Document the selected origin and round-trip conversion in each adapter. Presentation-only elevation must never imply traversability that the rules do not support.

An implementation MUST allow the same roster, map data, input actions, and saved campaign to work with either renderer. Runtime switching is optional: two development scenes or separate builds are sufficient. Do not build both entire environment pipelines before the art test decides the direction.

## Option A with 2D maps

- MUST support independent ground, terrain transition, prop, unit, canopy, and effect layers. Sort overlapping units and props by ground anchor, with explicit exceptions for bridges and roofs.
- Author grass, path, stone, water, forest, wall, bridge, and objective tiles for the art test. Supply connected edges and corners for path and water; avoid visible seams and repetitive rectangular patches.
- Keep collision, movement costs, and terrain bonuses in logical map data. Decorative crowns and roof overhangs may extend beyond blocked cells but must not enlarge their collision footprints.
- Hide or fade foreground trees and roofs that cover selected or targetable units. Keep unit markers and the chosen route legible beneath decoration.
- Use a pixel-aligned camera and consistent render grid for tiles, sprites, and effects. Snap display transforms without changing simulation positions. Review slow pans and diagonal travel for jitter.
- Match shadows and material highlights to the sprite lighting. Carry map terrain identity into a dedicated battle background if that combat option is selected.

## Option B with 3D maps and 2D sprites

- Begin with an orthographic camera, fixed azimuth, and a validated pitch. Free orbit requires additional directional art and a reviewed facing policy; it is outside the initial four-direction budget.
- Use upright sprite cards with their feet anchored to terrain height. Choose and validate a billboard policy for the fixed camera; hovering, pitching the character flat onto the ground, and swimming foot anchors are unacceptable.
- Use deliberate depth handling and alpha cutouts. Characters MUST not appear through entire buildings. Fade obstructing scenery or show an occlusion silhouette; keep tactical markers readable.
- Use grounded contact shadows with consistent size and softness. Flying shadows remain at ground level while the sprite moves above them.
- Build stylized geometry and restrained materials whose detail density supports the pixel characters. Verify sprite edges and texture sampling at every supported zoom; address shimmer through camera and render resolution choices.
- Raycast or otherwise pick the logical ground surface, including elevation. Reject hits on decorative roofs or leaves that would select a different cell.

Terrain meshes, depth, lighting, and 2D tiles are renderer-specific assets. Their colors, terrain IDs, footprint definitions, reference compositions, and source concepts can be shared. Do not promise automatic conversion between finished 2D tiles and 3D environments.

## Shared interface and effects

MUST supply selection and target cursors, team markers, HP bars, movement and attack overlays, a route indicator, objective symbols, status icons, and readable damage and healing feedback. Overlays need distinct shapes or patterns where their colors overlap. Reduce clutter by showing detailed labels on focus or inspection.

Map effects need short melee impact, projectile, spell, heal, miss, critical, and defeat treatments. Tie them to resolved visual cues and preserve the unit's anchor. Support reduced flashes and camera shake, and allow rapid animation playback or skipping without hiding combat results.

At the minimum display size, UI text MUST remain readable without scaling the entire HUD into pixel art. Selection, forecast, terrain information, and route preview must fit together without covering the chosen target. Keyboard focus and pointer selection need equivalent visual feedback.

## Optional 2D close combat

If separate 2D battle scenes are chosen, commission a separate sprite profile after the map art test. Do not enlarge map sprites and assume they are finished combat animation. Start with a 160 by 160 transparent infantry canvas and a 240 by 192 large-unit canvas; validate framing and weapon reach before freezing these sizes.

Required clips are idle, ready, attack or cast, return, hit, dodge, and defeat. Each weapon family needs anticipation, a clear contact or release cue, and recovery; critical variants follow only after ordinary attacks read well. Supply projectiles, impacts, and backgrounds matched to the battlefield terrain. Preserve attacker orientation, target identity, HP changes, skip behavior, and return to the original map focus. A 3D map can use this same battle renderer.

This is an optional production branch. The shared map sprite requirements do not commit the game to it.

## Art test and acceptance

Build one shared 12 by 10 logical test map with grass, path, water, a bridge, a wall, a tree, and an objective. Include six identities: sword infantry, armored lancer, mounted unit, archer, caster or healer, and flyer; show both teams, a spent unit, and an injured unit. Include tall foreground scenery and several adjacent units. Reuse the same layout and sprites in the two map renderers.

First deliver a still composition and idle/movement/contact-sheet preview for one infantry unit and one large unit. Freeze scale and anchor policy, then complete the six-unit scene. This limits discarded animation work if the map direction changes.

| Acceptance check | Required evidence |
| --- | --- |
| Character readability | Label-free screenshot at 1280 by 720; reviewer can distinguish all six roles, teams, selection, spent state, and injury |
| Pixel consistency | Native-size contact sheets plus 2x screenshots; no blurred edges, clipped weapons, atlas bleed, or unintended scale differences |
| Animation | Idle, route travel, attack or heal, hurt, defeat, cancel, and skip recording; stable feet and no duplicate completion |
| Occlusion | Selected and targetable units remain discoverable behind trees, walls, roofs, and on the bridge |
| Picking | Click cell centers, tile edges, and overlapping units at supported zooms; selected cells agree with the grid |
| Gameplay equivalence | Identical action sequence and RNG seed produce identical final simulation state with either renderer |
| UI and motion | Review 1280 by 720 and 1440 by 900, keyboard focus, reduced effects, and the busiest overlay combination |
| Runtime budget | Proposed 60 FPS target: 95th percentile frame time at most 16.7 ms over 60 seconds with 40 visible units and active overlays; record hardware, platform, resolution, and load time |
| Portability | Copy assets, metadata, and the profile to a clean project; load and animate one unit without campaign files or absolute paths |

Record performance per target platform; select the minimum supported hardware before treating the budget as a release gate. The 40-unit case is a proposed stress scene rather than a claim about the current campaign.

Compare the renderers using matched screenshots and recordings. Score tactical readability 30%, sprite and environment cohesion 25%, animation and camera stability 20%, measured performance 15%, and authoring effort 10%, each on a 1–5 scale. Log hours needed to build and revise the same scene. Resolve any failed acceptance check before using the weighted score; the user's preferred result determines the final direction.

## Production sequence

1. Review the proposed pixel profile, produce the two-unit art test, and freeze approved source sizes, palette, camera, and anchors.
2. Implement metadata import and sprite playback behind the shared presentation contract. Complete the six-unit test assets and the common overlay set.
3. Compare limited 2D and 3D map test scenes using the acceptance checks. Record the selected renderer and any profile changes.
4. Produce environment assets for the selected map direction. Expand unit art, portraits, promotions, and effects against a complete asset inventory.
5. Choose close combat presentation independently and budget its additional art. Complete target-platform visual and performance verification.

For a new project, copy this folder, replace the game adapter described in [integration notes](integration-notes.md), and retain the shared profile and manifest semantics. The receiving project owns its engine implementation and final renderer choice.
