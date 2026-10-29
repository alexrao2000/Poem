# Ashen Standard

An original, playable tactical RPG prototype in Godot 4.5.1 / GDScript.

## Included

- 24 named recruits across 8 classes, individual original portraits, character dossiers, epilogues, deployment selection, persistent levels and experience.
- 12 connected chapters with 103 lines of opening/closing dialogue, a campaign ending, and rout, seize, boss and six-turn defense objectives.
- Weighted terrain movement, occupancy, weapon triangle, two-roll hit checks, critical hits, counters, speed follow-ups, healing, enemy turns and casual recovery.
- Detailed original class sprites on a textured 3D landscape, village scenery, parchment UI, and a camera handoff to articulated 3D combatants with armor, capes, weapons, impact effects and combat health bars.
- Original synchronized calm/intense musical sketches. Both streams loop on the same timeline.
- Save/load during the player phase and at camp; autosaves after actions. Saves include RNG state.
- Browser and macOS exports.

This is a complete campaign **prototype**, not finished commercial content. The first visual rebuild adds painted materials and distinct class silhouettes, but 3D characters and animation still need substantial refinement to approach the Awakening/Fates reference quality. Map sprites currently share appearances within each class, music is a short synthesized sketch, and chapter maps use four layout families. Portraits are original generated illustrations. There is no voice acting, support conversation system, equipment inventory, weapon durability, promotions, or multiplayer. Campaign balance has not had a human playthrough. Recruitment occurs automatically at the relevant chapter's war council. Fallen units recover when the map is restarted or the chapter ends.

## Play

The game stays local. Serve `build/web` using `python3 -m http.server 8060 --directory build/web`, then visit http://localhost:8060. Browser music starts after Begin/Continue. Use a desktop-size browser for the current interface. Private source repository: https://github.com/alexrao2000/fe-clone.

Select an ally, click a reachable tile, select an enemy and confirm the attack. Waiting commits movement. Right-click or Escape undoes an uncommitted move. Space ends the player phase. Tab skips the remainder of a combat scene. A Warden heals by clicking an adjacent injured ally. Pale cross and golden objective tiles heal 6 HP at the start of a player turn.

Save files are local to the device/browser origin. Browser storage can be cleared by the browser. Returning to the war council restarts the current map from its pre-battle roster.

## Develop

Open `project.godot` in Godot 4.5.1 (standard edition). Use the Compatibility renderer for web parity. No third-party packages are needed.

- `scripts/rules.gd`: scene-independent simulation, campaign state and persistence.
- `scripts/main.gd`: menus, board renderer, input, AI orchestration, combat presentation and music.
- `scripts/scenery.gd`: textured terrain, environment construction and material caching.
- `scripts/fighters.gd` and `fighter_actor.gd`: articulated class actors, joint poses, weapons and class-specific attack animations.
- `assets/art/`: original generated terrain atlas and class sprite atlas. Prompts and provenance are recorded in `docs/art-direction.md`.
- `data/campaign.json`: editable roster, classes and chapter definitions.
- `data/story.json` and `characters.json`: chapter dialogue, biographies, appearance and epilogues.
- `scripts/portraits.gd`: individual portrait atlas selection.
- `assets/fonts/`: Cormorant Garamond under the included SIL Open Font License.
- `scripts/generate_content.py`: reproducible initial content, pixel sprites and music generation. Running it overwrites generated content/assets.
- `tests/test_rules.gd`: headless rules, all-map connectivity, outcome and persistence tests.
- `tests/test_presentation.gd`: all 12 camp/map scenes, combat camera return, UI restoration and ending.

Run all suites: `GODOT_BIN=/path/to/godot python3 scripts/test_local.py`. The runner detects script errors and times out hung assertions.

Validation: 528 rules assertions and the scene checks pass. Browser smoke testing covers loading, recruitment/deployment screens, movement, forecasts, attacks, enemy turns and save continuation. This is not a complete campaign balance playthrough.

Export templates are not checked in. Download the official 4.5.1 export templates and place `web_nothreads_debug.zip`, `web_nothreads_release.zip`, and `macos.zip` in `.tools/templates`, renaming the web files to `web_debug.zip` and `web_release.zip`. Alternatively clear custom template paths in the export settings and install standard templates through Godot.

Browser build: `godot --headless --path . --export-release Web`, then `python3 scripts/pack_web.py`. The postprocessor compresses the WASM engine and uses the browser DecompressionStream API so static hosting needs no special response headers. Native build: `godot --headless --path . --export-release macOS`.

To import, run all three test suites, and package both local builds in one step: `GODOT_BIN=/path/to/godot scripts/build_local.sh`.

Apart from the openly licensed display font, all game assets and story content are original prototype work, including generated raster art and procedural 3D models. The game includes no Nintendo code, art, characters or music. Reference repositories informed mechanical architecture; the implementation is new GDScript.
