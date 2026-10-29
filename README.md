# Ashen Standard

An original, playable tactical RPG prototype in Godot 4.5.1 / GDScript.

## Included

- 24 named recruits across 8 classes, biographies, deployment selection, persistent levels and experience.
- 12 connected chapters with opening/closing narrative, a campaign ending, and rout, seize, boss and six-turn defense objectives.
- Weighted terrain movement, occupancy, weapon triangle, two-roll hit checks, critical hits, counters, speed follow-ups, healing, enemy turns and casual recovery.
- 2D map sprites on a 3D board and a camera handoff to animated procedural 3D combatants.
- Original synchronized calm/intense musical sketches. Both streams loop on the same timeline.
- Save/load during the player phase and at camp; autosaves after actions. Saves include RNG state.
- Browser and macOS exports.

This is a complete campaign **prototype**, not finished commercial content. Models and animation are geometric placeholders, sprites share a base silhouette, music is a short synthesized sketch, and chapter maps use four layout families. There are no finished portraits, voice acting, support conversations, equipment inventory, weapon durability, promotions, or multiplayer. Campaign balance has not had a human playthrough. Recruitment occurs automatically at the relevant chapter's war council. Fallen units recover when the map is restarted or the chapter ends.

## Play

Open the hosted build or serve `build/web` using `python3 -m http.server 8060 --directory build/web`, then visit http://localhost:8060. Browser music starts after Begin/Continue. Use a desktop-size browser for the current interface.

Select an ally, click a reachable tile, select an enemy and confirm the attack. Waiting commits movement. Right-click or Escape undoes an uncommitted move. Space ends the player phase. Tab skips the remainder of a combat scene. A Warden heals by clicking an adjacent injured ally. Pale cross and golden objective tiles heal 6 HP at the start of a player turn.

Save files are local to the device/browser origin. Browser storage can be cleared by the browser. Returning to the war council restarts the current map from its pre-battle roster.

## Develop

Open `project.godot` in Godot 4.5.1 (standard edition). Use the Compatibility renderer for web parity. No third-party packages are needed.

- `scripts/rules.gd`: scene-independent simulation, campaign state and persistence.
- `scripts/main.gd`: menus, board renderer, input, AI orchestration, combat presentation and music.
- `data/campaign.json`: editable roster, classes and chapter definitions.
- `scripts/generate_content.py`: reproducible initial content, pixel sprites and music generation. Running it overwrites generated content/assets.
- `tests/test_rules.gd`: headless rules, all-map connectivity, outcome and persistence tests.
- `tests/test_presentation.gd`: all 12 camp/map scenes, combat camera return, UI restoration and ending.

Run tests: `godot --headless --path . --script tests/test_rules.gd`.
Run scene checks: `godot --headless --path . --script tests/test_presentation.gd`.

Validation: 528 rules assertions and the scene checks pass. Browser smoke testing covers loading, recruitment/deployment screens, movement, forecasts, attacks, enemy turns and save continuation. This is not a complete campaign balance playthrough.

Export templates are not checked in. Download the official 4.5.1 export templates and place `web_nothreads_debug.zip`, `web_nothreads_release.zip`, and `macos.zip` in `.tools/templates`, renaming the web files to `web_debug.zip` and `web_release.zip`. Alternatively clear custom template paths in the export settings and install standard templates through Godot.

Browser build: `godot --headless --path . --export-release Web`, then `python3 scripts/pack_web.py`. The postprocessor compresses the WASM engine and uses the browser DecompressionStream API so static hosting needs no special response headers. Native build: `godot --headless --path . --export-release macOS`.

All game assets and story content in this project are original procedural prototype work. The game includes no Nintendo code, art, characters or music. Reference repositories informed mechanical architecture; the implementation is new GDScript.
