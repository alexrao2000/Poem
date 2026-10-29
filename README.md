# Ashen Standard

An original, playable tactical RPG prototype in Godot 4.5.1 / GDScript.

## Included

- 24 named recruits across 8 classes, individual original portraits, character dossiers, epilogues, deployment selection, persistent levels and experience, and 16 advanced promotion paths.
- 12 individually authored battlefields with 103 lines of opening/closing dialogue, a campaign ending, and rout, seize, boss and six-turn defense objectives.
- Authored enemy equipment across all 12 chapters, including ranged spears, longbows, stronger tomes and specialist weapons visible in enemy inspection and forecasts.
- Weighted terrain movement, occupancy, weapon triangle, two-roll hit checks, critical hits, counters, speed follow-ups, healing, enemy turns and casual recovery.
- 24 individual original map sprites on a textured 3D landscape, village scenery, parchment UI, and a camera handoff to articulated 3D combatants with armor, capes, weapons, impact effects and combat health bars.
- Original 71-second, 32-bar stereo score with calm/intense arrangements on the same sample timeline, plus synthesized combat/healing/phase effects.
- Save/load during the player phase and at camp; autosaves after actions. Saves include RNG state, validate loaded data, retain the previous save as a backup, and migrate changed map layouts back to preparation.
- 36 original support conversations (192 lines) across 12 partnerships covering the full roster; earned ranks grant proximity bonuses.
- Animated XP and level-up rewards, complete two-sided forecasts, chapter results, a rotatable 3D character viewer, and skippable critical portrait accents with original battle calls for all 24 recruits.
- Browser and macOS exports.

This is a complete campaign **prototype**, not finished commercial content. The first visual rebuild adds painted materials and distinct class silhouettes, but 3D characters and animation still need substantial refinement to approach the Awakening/Fates reference quality. Music is synthesized, and 3D characters remain procedural despite textured materials and class-specific silhouettes. Portraits are original generated illustrations. There is no voice acting, weapon durability, or multiplayer. Five automated campaigns clear all 12 chapters using legal actions, including both promotion branches, but campaign balance still needs a complete human playthrough. Recruitment occurs automatically at the relevant chapter's war council. Fallen units recover when the map is restarted or the chapter ends.

## Play

The game stays local. Serve `build/web` using `python3 -m http.server 8060 --directory build/web`, then visit http://localhost:8060. Browser music starts after Begin/Continue. Use a desktop-size browser for the current interface. Private source repository: https://github.com/alexrao2000/fe-clone.

Select an ally, hover a reachable tile to preview its route, click to travel along it, select an enemy and confirm the attack. Waiting commits movement. Right-click or Escape undoes an uncommitted move. Arrow keys move the map cursor; Enter selects a tile or confirms a forecasted attack. Q/E cycle ready allies and W waits. Space ends the player phase. Tab skips the remainder of a combat scene. R toggles enemy threat ranges; clicking a foe inspects its stats and reach. A Warden heals by clicking an injured ally within the equipped staff’s range. Open a recruit’s portrait at the war council, then Equipment, to choose from 22 weapons and staves. Supplies unlock by chapter; equipment is freely shared. Weight reduces combat speed, and a four-point speed advantage grants a follow-up. Physical attacks check Defense; magic checks Resistance. Seamfinder and War hammer triple weapon might against armored Knights; Rider-stop pike does so against mounted Riders. Forecasts flag effective attacks and counters. At level 10, open **Advanced training** in a recruit’s dossier to compare two permanent promotion paths. Training retains level, experience and equipment, and costs no consumable. Use **Support conversations** in the dossier to read or replay a bond scene. Fighting or healing within two tiles of a partner earns one point per pair per turn, capped at three per chapter. Readiness appears on camp cards. Read ranks grant +5 Hit/Avoid per rank while the partner is nearby; rank A also adds one damage. Pale cross and golden objective tiles heal 6 HP at the start of a player turn.

Use **Transfer a local save** on the title screen or war council, or **Transfer code** in battle, to copy an ASHEN1 code into another build. Battle transfer exports the live state and returns to the same map. Failed autosaves show a warning and a phase-status marker; the transfer code remains available if device storage cannot be written. In a browser, **Open browser copy / paste** provides a native text field; choose **Use code**, then **Import pasted code**. The previous save is retained as a backup. Nothing is uploaded.

**Options** is available from the title, war council and battle sidebar. It controls full 3D/player-only/quick-map battles, music and effects volume, dialogue speed, and automatic phase ending. Preferences stay on the device separately from campaign saves.

Save files are local to the device/browser origin. Browser storage can be cleared by the browser. Returning to the war council restarts the current map from its pre-battle roster.

## Develop

Open `project.godot` in Godot 4.5.1 (standard edition). Use the Compatibility renderer for web parity. No third-party packages are needed.

Visual exploration: [reusable 2D visual requirements](docs/visuals-2d/README.md) specify shared sprite assets for either 2D or 3D maps, with an example asset manifest and project integration notes. The proposed profile is separate from the current implementation.

- `scripts/rules.gd`: scene-independent simulation, validated actions, campaign state and backup persistence.
- `scripts/tactics.gd`: weighted pathfinding, guard/sentry/pursuit behavior, combat evaluation and automated playtest planning.
- `scripts/main.gd`: menus, board renderer, input, AI orchestration, combat presentation and music.
- `scripts/scenery.gd`: textured terrain, environment construction and material caching.
- `scripts/static_batch.gd`: spatial/material batching for static scenery, with correct normals under nonuniform scaling. The current 12 maps combine 13,633 mesh objects into 674 batches; browser FPS has not yet been measured.
- `scripts/fighters.gd` and `fighter_actor.gd`: articulated class actors, joint poses, weapons and class-specific attack animations.
- `scripts/combat_models.gd`, `imported_fighter.gd` and `data/combat_models.json`: optional authored glTF/scene replacement with animation segments and effect sockets. The catalog is initially empty; see `docs/combat-models.md` for asset integration.
- `assets/art/`: original generated terrain atlas and class sprite atlas. Prompts and provenance are recorded in `docs/art-direction.md`.
- `data/campaign.json`: editable roster, classes and chapter definitions.
- `scripts/supports.gd` and `data/supports.json`: bounded relationship progress, combat proximity checks and authored camp conversations.
- `data/promotions.json`: two advanced paths per base class, eligibility and stat/combat bonuses.
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

Validation: 525 rules assertions, pathfinding/action tests, save recovery/migration, 60 chapter victories across three seeds and both promotion branches, dialogue/portrait checks, audio timeline tests and scene checks pass. Browser smoke testing covers loading, recruitment/deployment screens, movement, forecasts, attacks, enemy turns and save continuation. This is not a complete human campaign balance playthrough.

Export templates are not checked in. Download the official 4.5.1 export templates and place `web_nothreads_debug.zip`, `web_nothreads_release.zip`, and `macos.zip` in `.tools/templates`, renaming the web files to `web_debug.zip` and `web_release.zip`. Alternatively clear custom template paths in the export settings and install standard templates through Godot.

Browser build: `godot --headless --path . --export-release Web`, then `python3 scripts/pack_web.py`. The postprocessor compresses the WASM engine and uses the browser DecompressionStream API so static hosting needs no special response headers. Native build: `godot --headless --path . --export-release macOS`.

To import, run all twenty test suites, and package both local builds in one step: `GODOT_BIN=/path/to/godot scripts/build_local.sh`.

Apart from the openly licensed display font, all game assets and story content are original prototype work, including generated raster art and procedural 3D models. The game includes no Nintendo code, art, characters or music. Reference repositories informed mechanical architecture; the implementation is new GDScript.

Local QA checkpoints can be generated with `godot --headless --path . --script scripts/make_qa_saves.gd`; codes are written under ignored `build/qa-saves/` and excluded from release archives.
