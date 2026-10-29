# Tactical sprite foundation

An original sprite and terrain asset package with working Godot 4 adapters for 2D tilemaps and 3D terrain. Both adapters use the same catalog, animation clock, unit IDs, grid data, selection state, and visual effects.

## Run and reuse

In Ashen Standard, choose **Visual workshop · 2D / 3D maps** from the title screen. The workshop is a separate skirmish with movement, undo, forecasts, attacks, healing, enemy turns, and map switching. It has its own simulation and never writes the campaign save. Tab switches map views while idle and skips the active action animation while busy.

For another game, copy the entire `visuals/` directory into a Godot 4 project. Open `res://visuals/preview.tscn` to inspect all eight classes, both maps, and animation states. The preview has no dependency on Ashen Standard's scripts, fonts, roster, saves, or combat rules. Run `python3 scripts/package_visuals.py` in the source repository to create a clean starter project and `build/Reusable2DVisuals.zip`.

The renderer scripts currently use the `res://visuals/` resource root. Keep that directory name or update the resource paths together when relocating it.

## Included artwork

- Eight class identities: sword commander, armored lancer, archer, mage, healer, mounted lancer, axe warrior, and duelist.
- Ninety-six source poses in `assets/units-v2.png`: twelve poses per class, including four facings, movement pairs, attack, and recoil.
- Sixteen regions in `assets/terrain-v1.png`: ground materials, river banks, trees, shrubs, walls, houses, objective, and healing shrine.
- Both original generation prompts and the transparency edit prompt in [generation records](source/generation-prompts.json). Artwork was created with the built-in image generation tool on 2026-10-29. The source repository preserves the earlier generation in `units-v1.png`; the starter omits it and uses `units-v2.png`.

These are prototype art sheets. North, east, and west idle clips hold their facing pose; south has an alternate idle. Actions share one release pose across facings, and defeat reuses recoil. Movement has two source poses per facing. This foundation supports the larger animation budgets in the requirements, but the current artwork is not an 80-frame-per-character production set. Individual recruit costumes, promoted appearances, flyers, and dedicated close-combat sprite sheets remain additional art work.

## Asset contract

`units.json` uses schema version 1 with explicit frame rectangles. Each asset has a stable ID, relative texture path, logical frame size, source frame rectangles and pivots, and five states with four directional clips. Each clip declares frame indices, millisecond durations, looping, and cue positions. The included profile draws a 122 by 124 source frame into a 49 by 50 logical canvas on 32-pixel map tiles; the visible figure is smaller than the padded canvas.

Pivots are source pixel coordinates measured right and down from the frame's top left. Both adapters convert them into their native coordinate systems. Avoid independently trimming or recentering frames. `source/build_catalog.py` regenerates metadata from the recorded atlas layout without changing image pixels. If the source image grid changes, review its dimensions, regions, and pivots before regenerating.

`catalog.gd` validates IDs, safe relative paths, image bounds, pivots, required states and facings, timing, frame references, and cues. It caches imported textures and atlas regions. JSON metadata and PNG source artwork can be used by another engine with a new adapter.

`sprite_player.gd` exposes `configure`, `play`, `advance`, and `skip`, with `cue` and `finished` signals. A non-looping clip completes once even if skipped repeatedly. The player never changes HP, movement, RNG, or turn state.

## Renderer adapter

`map_2d.gd` and `map_3d.gd` accept `setup(catalog, model)`. The supplied model needs:

| Data or method | Meaning |
| --- | --- |
| `units` | Dictionaries with `id`, `job`, `x`, `y`, `hp`, `max_hp`, `team`, and `acted` |
| `board_size()` | Grid width and height as `Vector2i` |
| `terrain(cell)` | Stable terrain symbol for a logical cell |
| `pos(unit)` | Unit position as `Vector2i` |

The current class-to-visual lookup is `JOB_VISUAL` in each map adapter. Replace this mapping with your receiving project's visual IDs when adding different classes or individual characters. `preview_model.gd` supplies the smallest working model example.

Set `selected_id`, `reachable`, `route`, `danger`, `cursor`, and `show_grid`, then call `refresh()`. Geometry and picking use `cell_to_world`, `world_to_cell`, and `screen_to_cell`. The 2D adapter draws cell centers relative to an explicit pixel offset; the 3D adapter uses x/z ground coordinates. Out-of-board picking returns `Vector2i(-1, -1)`.

Use `animate_route(id, path)` after validating a logical route in your game. Use `play_action(actor_id, target_id, reduced_motion)` and `play_hurt(target_id, defeated)` to present resolved combat. `visual_cue` identifies the acting unit and cue name; call `feedback` with already resolved damage or healing. Cues and effects are cosmetic. The controller must lock input and map changes while presentation runs and restore or commit the authoritative logical state before refreshing.

The 2D adapter sorts props and units by ground position and fades obstructing scenery. The 3D adapter uses orthographic projection, billboard sprite cards, depth testing, textured ground and buildings, ground markers, and selected-unit occluder fading. Both share pixel effects and shape-based team markers. Camera orbit is outside this four-direction art profile.

## Validation

From the source project, run `GODOT_BIN=/path/to/godot python3 scripts/test_local.py visuals`. Coverage includes every state and facing, catalog rejection, clip cues and skipping, map switching without RNG changes, coordinate conversion and picking, movement locks, undo, deterministic combat, healing, enemy turns, and workshop entry and return.

In the exported starter, run `godot --headless --path . --script res://visuals/verify.gd` for a self-contained import and renderer smoke test.

For native visual captures, run Godot with `--path . --script scripts/capture_visuals.gd`, adding `-- --visual-3d` for the 3D view. Captures are written to `build/visual-2d.png` and `build/visual-3d.png`. The harness explicitly renders a frame so macOS window occlusion does not stall capture.

The in-game frame-time display is a rolling diagnostic, not a completed minimum-hardware benchmark. Compare the two maps on the same machine and viewport before selecting the production direction.
