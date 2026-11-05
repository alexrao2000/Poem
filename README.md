# Poem

A playable tactical RPG prototype built with Godot 4.5.1 and GDScript. Lead 24 recruits through a 12-chapter campaign, choose their equipment and promotions, and build relationships between battles.

The campaign uses animated 2D map sprites over textured 3D terrain, with separate 3D combat scenes. Browser and macOS exports run locally.

[Play](#play) · [Controls](#controls) · [Campaign guide](#campaign-guide) · [Saves and options](#saves-and-options) · [Development](#development) · [Testing](#testing) · [Builds](#builds) · [Assets and credits](#assets-and-credits)

## Play

### From source

1. Install **Godot 4.5.1, standard edition**. The project uses GDScript and the Compatibility renderer; no third-party runtime packages are required.
2. Import [project.godot](project.godot) in the editor and let asset imports finish.
3. Press **F5** to launch the game. Choose **Begin** on the title screen to start a campaign.

### From a local export

For a browser build, serve the exported folder from the repository root:

```sh
python3 -m http.server 8060 --bind 127.0.0.1 --directory build/web
```

Open [localhost:8060](http://localhost:8060) in a desktop-size browser. Music starts after **Begin** or **Continue**. Keep the exported files together and serve them over HTTP.

For macOS, extract `build/native/Poem.zip` and launch the application inside it.

Exports are generated locally and ignored by Git. If `build/web/index.html` or the native archive is missing, follow [Builds](#builds) first. You can also play directly in the editor without export templates.

### Your first battle

1. At the war council, choose your deployment and open recruit portraits to inspect equipment and abilities.
2. Select an ally, then hover a reachable tile to preview the route. Click the tile to move.
3. Select an enemy, review the forecast, and confirm the attack. A staff user can instead select an injured ally within range to heal.
4. Use **Wait** to commit movement without attacking. Right-click or press **Escape** to undo an uncommitted move.
5. End the player phase when ready. Complete the displayed objective to advance to the next chapter.

## Controls

These controls apply to campaign battles; menus and the visual workshop have their own context-sensitive actions.

| Action | Control |
| --- | --- |
| Select a unit, move, or choose a target | Left-click |
| Move the map cursor | Arrow keys |
| Select a tile or confirm a forecasted attack | Enter |
| Cycle ready allies | Q / E |
| Wait with the selected ally | W |
| Cancel a drop choice, selection, or uncommitted move | Right-click / Escape |
| Rescue a downed ally | Select an adjacent ready ally, then click the patient or choose Rescue & triage |
| Place a carried ally | Rescue & triage → Choose drop tile, then click a gold tile or press Enter |
| End the player phase | Space |
| Toggle enemy threat ranges | R |
| Open or close the battle menu | M; Escape also closes it |
| Zoom the tactical map | Mouse wheel / + / − |
| Pan the tactical map | Middle-button drag |
| Reset the map view | Home |
| Skip a chapter card, phase announcement, combat scene, or casualty card | Tab |
| Play combat animation at double speed | Hold Shift |
| Advance dialogue | Space / Enter |
| Skip the current dialogue sequence | Escape |

Click an enemy to inspect its stats and reach. The terrain card follows the pointer or keyboard cursor and shows movement costs and bonuses. Keyboard cursor movement keeps distant tiles in view; map zoom and pan are preserved when returning from combat. Chapter and casualty cards also accept a click to skip.

## Campaign guide

### Roster and objectives

- **24 named recruits across 8 classes**, each with a portrait, dossier, battle call, casualty dialogue, and epilogue. Recruitment happens automatically at the relevant chapter's war council.
- **12 authored battlefields** with rout, seize, boss, and six-turn defense objectives, opening and closing dialogue, and a campaign ending.
- **12 named enemy commanders** with individual portraits, model palettes, critical calls, and clickable crown markers on the map.
- Persistent levels and experience, deployment selection, and an experimental permadeath toggle.

### Equipment and combat

Open a recruit's portrait at the war council, then **Equipment**, to choose from 22 weapons and staves. Supplies unlock by chapter, and equipment is freely shared. Enemy equipment appears in models, inspection panels, and forecasts.

**Permadeath** is a toggle on the new-campaign screen and in **Options**. Ordinary permadeath commits casualties after a chapter victory. With **Save every action**, deaths commit during battle and survive a retry; movement cannot be undone. Memorial records and read support scenes remain available. Turning permadeath off preserves earlier losses.

Options also exposes independent campaign experiments: section restarts, increasing enemy preparation after resets, rescuable downed allies, stronger enemy forces, death-triggered legacy supplies, and sacrifice costs/openings. See the [experiment rules and initial balance measurements](docs/campaign-experiments.md) for the exact behavior and current limits.

Enable **Debug mode · temporary sandbox**, then open **Debug tools**, to try these safely. Tools load any chapter, set a reproducible combat seed or reset pressure, heal or revive the company, make a selected ally fall, and exercise the actual reset/section-retreat path. Experiment reports include a restore code for the current position. Debug saves use a separate slot. Turning Debug mode off restores the campaign state from when you enabled it, including unsaved progress. The normal campaign save remains untouched during experiments.

Combat includes weighted terrain movement, occupancy, the weapon triangle, two-roll hit checks, critical hits, counters, and speed follow-ups. Equipment weight reduces combat speed; a four-point speed advantage grants a follow-up. Physical attacks check Defense, while magic checks Resistance.

**Seamfinder** and **War hammer** triple weapon might against armored Knights; **Rider-stop pike** does so against mounted Riders. Forecasts show effective attacks and counters. Pale cross and golden objective tiles restore 6 HP at the start of a player turn.

Presentation includes weapon-specific projectiles, distinct Ember/Gale/Thunder spells, continuous counters and follow-ups, critical portrait accents, animated health meters, and terrain-matched arenas. Options let you choose full 3D, player-only, or quick-map battles.

### Promotions and supports

At level 10, open **Advanced training** in a recruit's dossier to compare two permanent promotion paths. There are 16 advanced paths across the eight base classes. Training retains level, experience, and equipment, and costs no consumable.

The roster has 36 support conversations across 12 partnerships. Fighting or healing within two tiles of a partner earns one point per pair per turn, capped at three per chapter. Camp cards show when a conversation is ready; open **Support conversations** in the dossier to read or replay it.

Read support ranks grant +5 Hit/Avoid per rank while the partner is nearby. Rank A also adds one damage.

### Character viewer and workshop

Open **View character** from a dossier to rotate a recruit's 3D preview and choose attack, reaction, defeat, or finishing poses. Staff users can preview healing. **Run / trot** loops the combat gait in place while you rotate or zoom the outfit. **Play again** restarts the selected action; **Escape** returns to the record or training choice.

The title screen's **Character & map workshop** runs a separate skirmish with the same animated sprite foundation over either 2D tiles or 3D terrain. It does not write campaign saves. See the [reusable sprite package](visuals/README.md) for its preview scene, controls, and integration contract.

### Prototype status

The full campaign is implemented, but visual quality and balance still need review. Combat figures are procedural, portraits are generated illustrations, and character models and animation need further refinement. There is no voice acting, weapon durability, or multiplayer.

Automated campaign coverage does not replace a complete human balance playthrough. Rendered review of the latest presentation changes and browser performance measurement are also pending.

## Saves and options

Saves are local to the device and, in a browser, the browser origin. The game supports saving during the player phase and at camp, with autosaves after actions. Saves include RNG state, validate loaded data, retain the previous save as a backup, and move changed map layouts back to preparation.

Browser storage can be cleared by the browser. Returning to the war council restarts the current map from its pre-battle roster.

### Transfer a save

1. Choose **Transfer a local save** on the title screen or at the war council, or **Transfer code** from the battle menu or result screen.
2. Copy the `POEM1:` code. Battle transfer exports the live state and returns to the same map.
3. In the destination build, open the transfer screen, paste the code, and choose **Import pasted code**.

In a browser, **Open browser copy / paste** provides a native text field. Paste there, choose **Use code**, then **Import pasted code**. Nothing is uploaded.

Failed autosaves display a warning and a phase-status marker. Keep the game open and use a transfer code to preserve current progress if device storage cannot be written.

### Preferences

**Options** is available from the title screen, war council, and battle sidebar. It controls combat presentation, music and effects volume, dialogue speed, and automatic phase ending. Preferences are stored on the device separately from campaign saves. Holding Shift speeds up combat animation without changing the music.

## Development

Run commands below from the repository root. Python 3 is required for the test runner and packaging tools. Node.js runs the browser-storage unit checks; playing the game does not require it. NumPy supports optional audio/texture generation, and Pillow is also needed for texture generation.

The [project configuration](project.godot) selects the Compatibility renderer for browser parity and a 1440 × 900 logical viewport. Keep gameplay rules independent of presentation.

| Area | Entry points |
| --- | --- |
| Simulation, actions, campaign state, and persistence | [rules.gd](scripts/rules.gd) |
| Pathfinding, enemy behavior, and automated play planning | [tactics.gd](scripts/tactics.gd) |
| Menus, input, board rendering, and orchestration | [main.gd](scripts/main.gd) |
| Roster, classes, and chapters | [campaign.json](data/campaign.json) |
| Dialogue, biographies, and epilogues | [story.json](data/story.json), [characters.json](data/characters.json), [casualty_lines.json](data/casualty_lines.json) |
| Promotions and support conversations | [promotions.json](data/promotions.json), [supports.json](data/supports.json), [supports.gd](scripts/supports.gd) |
| Map sprites and reusable renderers | [campaign_map_unit.gd](scripts/campaign_map_unit.gd), [visual package](visuals/README.md) |
| Map navigation and tactical overlays | [tactical_camera.gd](scripts/tactical_camera.gd), [map_overlay.gd](scripts/map_overlay.gd), [terrain_card.gd](scripts/terrain_card.gd) |
| Combat actors and playback | [fighters.gd](scripts/fighters.gd), [fighter_actor.gd](scripts/fighter_actor.gd), [combat_playback.gd](scripts/combat_playback.gd) |
| Combat framing and feedback | [combat_camera.gd](scripts/combat_camera.gd), [combat_hud.gd](scripts/combat_hud.gd), [combat_transition.gd](scripts/combat_transition.gd) |
| Scenery and static batching | [scenery.gd](scripts/scenery.gd), [static_batch.gd](scripts/static_batch.gd) |
| Optional authored combat models | [combat_models.gd](scripts/combat_models.gd), [model catalog](data/combat_models.json), [integration guide](docs/combat-models.md) |

The authored combat-model catalog starts empty; procedural actors remain the fallback. See [art direction](docs/art-direction.md) and [visual requirements](docs/visuals-2d/README.md) for asset provenance and production targets.

### Authoring tools

- [author_maps.py](scripts/author_maps.py) authors map geometry, deployment, squads, landmarks, and tactical briefings.
- [index_sprites.gd](scripts/index_sprites.gd) generates sprite-region metadata from alpha bounds without modifying source images.
- [package_visuals.py](scripts/package_visuals.py) creates a clean starter project and `build/Reusable2DVisuals.zip` for reuse in another game.
- [generate_score.py](scripts/generate_score.py) renders the initial score and effects; [render_campaign_music.py](scripts/render_campaign_music.py) renders the two later campaign themes. Both require NumPy. Run [fetch_score_samples.py](scripts/fetch_score_samples.py) first to populate the ignored local sample cache. The initial generator also supports `--synthetic` for oscillator-only rendering.

**Regeneration warning:** [generate_content.py](scripts/generate_content.py) is a legacy full-content generator. Running it overwrites campaign data, original placeholder sprites, and audio. Use focused authoring scripts for normal edits.

## Testing

After importing the project in the editor, run all default Godot suites:

```sh
GODOT_BIN=/path/to/godot python3 scripts/test_local.py
```

Replace `/path/to/godot` with the executable for Godot 4.5.1. If `godot` is already on your `PATH`, omit `GODOT_BIN`.

Run selected suites by passing their names:

```sh
GODOT_BIN=/path/to/godot python3 scripts/test_local.py rules saves controls
```

The [runner](scripts/test_local.py) writes logs to `build/logs/`, stops promptly on script errors, and gives each suite a 90-second deadline. Default suites cover rules, movement, persistence, campaign progression, controls, menus, audio, and presentation. The [campaign suite](tests/test_campaign.gd) checks 72 chapter victories across three seeds, both promotion branches, and a complete permadeath campaign with saved casualties.

The Python score-render check is separate from the default runner. It requires NumPy and the cached instrument bank:

```sh
python3 tests/test_score_render.py
```

To generate local QA checkpoints, run:

```sh
mkdir -p build/logs
godot --headless --log-file "$PWD/build/logs/qa-saves.log" --path . --script scripts/make_qa_saves.gd
```

Transfer codes are written to `build/qa-saves/`, which is ignored and excluded from release archives.

## Builds

### Export templates

Use the official **4.5.1** export templates to match the engine. The checked-in [export presets](export_presets.cfg) expect these local files:

| Downloaded template | Local path |
| --- | --- |
| `web_nothreads_debug.zip` | `.tools/templates/web_debug.zip` |
| `web_nothreads_release.zip` | `.tools/templates/web_release.zip` |
| `macos.zip` | `.tools/templates/macos.zip` |

Alternatively, clear the presets' custom template paths and install the standard templates through Godot. Templates are not checked in.

### Build and validate both targets

```sh
GODOT_BIN=/path/to/godot scripts/build_local.sh
```

The [build script](scripts/build_local.sh) imports assets, validates the model catalog, runs all default suites, exports and postprocesses the browser build, tests its packed resources, and packages macOS.

| Output | Purpose |
| --- | --- |
| `build/web/` | Browser files to serve locally |
| `build/Poem-Web.zip` | Browser archive with local serving instructions |
| `build/native/Poem.zip` | macOS application archive |
| `build/logs/` | Import, test, and export logs |

### Export individual targets

With `godot` on your `PATH` and assets already imported:

```sh
mkdir -p build/web build/native build/logs
godot --headless --log-file "$PWD/build/logs/web.log" --path . --export-release Web
python3 scripts/pack_web.py
godot --headless --log-file "$PWD/build/logs/native.log" --path . --export-release macOS
```

Run [pack_web.py](scripts/pack_web.py) after every Web export. It compresses the WASM engine and adds browser-side decompression through `DecompressionStream`, so static hosting does not need special response headers. Use a browser that supports that API. Individual exports do not run the test suites or create `build/Poem-Web.zip`.

## Assets and credits

Story, music composition, raster illustrations, and procedural 3D figures are original prototype work. The score includes three 32-bar stereo themes with calm/Ablaze arrangements sharing a sample timeline, plus separate combat, healing, and phase effects.

- Font license: [SIL Open Font License](assets/fonts/OFL.txt).
- Instrument recordings: [CC0 license](assets/audio/VSCO-LICENSE.txt), [credits](assets/audio/VSCO-CREDITS.txt), and [source paths and hashes](assets/audio/orchestra-sources.json).
- Generated art: [prompts and provenance](docs/art-direction.md) and [portable sprite generation records](visuals/source/generation-prompts.json).

Font and instrument licenses and credits are included in the local exports.
