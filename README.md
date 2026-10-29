# Ashen Standard

An original, playable tactical RPG prototype in Godot 4.5.1 / GDScript.

## Included

- 24 named recruits across 8 classes, individual original portraits, character dossiers, epilogues, deployment selection, persistent levels and experience.
- 12 individually authored battlefields with 103 lines of opening/closing dialogue, a campaign ending, and rout, seize, boss and six-turn defense objectives.
- Weighted terrain movement, occupancy, weapon triangle, two-roll hit checks, critical hits, counters, speed follow-ups, healing, enemy turns and casual recovery.
- 24 individual original map sprites on a textured 3D landscape, village scenery, parchment UI, and a camera handoff to articulated 3D combatants with armor, capes, weapons, impact effects and combat health bars.
- Original 71-second, 32-bar stereo score with calm/intense arrangements on the same sample timeline, plus synthesized combat/healing/phase effects.
- Save/load during the player phase and at camp; autosaves after actions. Saves include RNG state, validate loaded data, retain the previous save as a backup, and migrate changed map layouts back to preparation.
- Animated XP and level-up rewards, complete two-sided forecasts, chapter results, and a rotatable 3D character viewer.
- Browser and macOS exports.

This is a complete campaign **prototype**, not finished commercial content. The first visual rebuild adds painted materials and distinct class silhouettes, but 3D characters and animation still need substantial refinement to approach the Awakening/Fates reference quality. Music is synthesized, and 3D characters remain procedural despite textured materials and class-specific silhouettes. Portraits are original generated illustrations. There is no voice acting, support conversation system, weapon durability, promotions, or multiplayer. Three automated campaigns clear all 12 chapters using legal actions, but campaign balance still needs a complete human playthrough. Recruitment occurs automatically at the relevant chapter's war council. Fallen units recover when the map is restarted or the chapter ends.

## Play

The game stays local. Serve `build/web` using `python3 -m http.server 8060 --directory build/web`, then visit http://localhost:8060. Browser music starts after Begin/Continue. Use a desktop-size browser for the current interface. Private source repository: https://github.com/alexrao2000/fe-clone.

Select an ally, click a reachable tile, select an enemy and confirm the attack. Waiting commits movement. Right-click or Escape undoes an uncommitted move. Space ends the player phase. Tab skips the remainder of a combat scene. R toggles enemy threat ranges; clicking a foe inspects its stats and reach. A Warden heals by clicking an injured ally within the equipped staff’s range. Open a recruit’s portrait at the war council, then Equipment, to choose from 19 weapons and staves. Supplies unlock by chapter; equipment is freely shared. Weight reduces combat speed, and a four-point speed advantage grants a follow-up. Pale cross and golden objective tiles heal 6 HP at the start of a player turn.

Use **Transfer a local save** on the title screen or war council to copy an ASHEN1 code into another build. In a browser, **Open browser copy / paste** provides a native text field; choose **Use code**, then **Import pasted code**. The previous save is retained as a backup. Nothing is uploaded.

Save files are local to the device/browser origin. Browser storage can be cleared by the browser. Returning to the war council restarts the current map from its pre-battle roster.

## Develop

Open `project.godot` in Godot 4.5.1 (standard edition). Use the Compatibility renderer for web parity. No third-party packages are needed.

- `scripts/rules.gd`: scene-independent simulation, validated actions, campaign state and backup persistence.
- `scripts/tactics.gd`: weighted pathfinding, guard/sentry/pursuit behavior, combat evaluation and automated playtest planning.
- `scripts/main.gd`: menus, board renderer, input, AI orchestration, combat presentation and music.
- `scripts/scenery.gd`: textured terrain, environment construction and material caching.
- `scripts/fighters.gd` and `fighter_actor.gd`: articulated class actors, joint poses, weapons and class-specific attack animations.
- `assets/art/`: original generated terrain atlas and class sprite atlas. Prompts and provenance are recorded in `docs/art-direction.md`.
- `data/campaign.json`: editable roster, classes and chapter definitions.
- `data/story.json` and `characters.json`: chapter dialogue, biographies, appearance and epilogues.
- `scripts/portraits.gd`: individual portrait and map-sprite atlas selection.
- `scripts/index_sprites.gd`: reads alpha bounds to generate sprite region metadata without modifying the source images.
- `assets/fonts/`: Cormorant Garamond under the included SIL Open Font License.
- `scripts/author_maps.py`: authored map geometry, deployment, squads, landmarks and tactical briefings.
- `scripts/generate_score.py`: original score and effects synthesis; requires NumPy for regeneration.
- `scripts/generate_content.py`: legacy full content regeneration. Running it overwrites campaign data, original placeholder sprites and audio; use focused authoring scripts for normal edits.
- `tests/test_rules.gd`: headless rules, all-map connectivity, outcome and persistence tests.
- `tests/test_presentation.gd`: all 12 camp/map scenes, combat camera return, UI restoration and ending.

Run all suites: `GODOT_BIN=/path/to/godot python3 scripts/test_local.py`. The runner detects script errors and times out hung assertions.

Validation: 525 rules assertions, pathfinding/action tests, save recovery/migration, 36 chapter victories across three campaign seeds, dialogue/portrait checks, audio timeline tests and scene checks pass. Browser smoke testing covers loading, recruitment/deployment screens, movement, forecasts, attacks, enemy turns and save continuation. This is not a complete human campaign balance playthrough.

Export templates are not checked in. Download the official 4.5.1 export templates and place `web_nothreads_debug.zip`, `web_nothreads_release.zip`, and `macos.zip` in `.tools/templates`, renaming the web files to `web_debug.zip` and `web_release.zip`. Alternatively clear custom template paths in the export settings and install standard templates through Godot.

Browser build: `godot --headless --path . --export-release Web`, then `python3 scripts/pack_web.py`. The postprocessor compresses the WASM engine and uses the browser DecompressionStream API so static hosting needs no special response headers. Native build: `godot --headless --path . --export-release macOS`.

To import, run all seven test suites, and package both local builds in one step: `GODOT_BIN=/path/to/godot scripts/build_local.sh`.

Apart from the openly licensed display font, all game assets and story content are original prototype work, including generated raster art and procedural 3D models. The game includes no Nintendo code, art, characters or music. Reference repositories informed mechanical architecture; the implementation is new GDScript.

Local QA checkpoints can be generated with `godot --headless --path . --script scripts/make_qa_saves.gd`; codes are written under ignored `build/qa-saves/` and excluded from release archives.
