# Ashen Standard development

User direction: keep developing continuously in this chat until the user returns/stops work or available usage is exhausted. **Do not schedule anything.** The user clarified that the earlier heartbeat was unwanted; it has been deleted. They authorize model switching if one model is exhausted and another is available, but the current tool surface has no direct self-model switch and usage currently reports a shared Codex pool. The previous geometric prototype was rejected visually; resemblance to Awakening/Fates presentation is the priority, alongside the existing full roster and campaign. Keep local builds; the only authorized remote destination is the private GitHub repository https://github.com/alexrao2000/fe-clone. Never publish to Sites. No purchases.

## Current work

### Latest checkpoint: portraits, chapter dialogue and combat animation

24 original portraits, biographies and individual epilogues; 103 authored dialogue lines across all 12 chapter introductions/outros; text reveal/skip controls and remembered scenes in save version 2 (version 1 supported); character dossiers; open-license serif display headings. Art prompts and font license are checked in. Browser-inspected title, dialogue, camp, dossier, selected-unit controls, forecast and actual combat frames. Captures in ignored `build/dossier-v3.png` and `build/combat-v3.png`.

Combat now has elbow/knee articulation, breathing, walking, class-specific preparation/strike, dodge/recoil/falling poses, projectiles, terrain-themed arenas/lighting and tile-centered zoom. Music crossfades cancel earlier fades without restarting the synchronized streams. Browser testing caught and fixed backward arm rotation and collapsing HP text; presentation tests now inspect the live HUD bounds and text widths. Test runner enforces a deadline and detects script errors.

**Still visibly short of the reference:** procedural characters, repetitive foliage and simple houses. Portraits are much stronger than the 3D meshes. Class map sprites are shared. Maps still use four procedural layout families; enemy pursuit uses Manhattan distance and can stall. Music is still a short synthesized loop. Next work: individually authored chapter maps, obstacle-aware pursuit, meaningful campaign simulation and progression tuning; then continue the environment/mesh art pass.

Run `GODOT_BIN=/private/tmp/ashen-godot/Godot.app/Contents/MacOS/Godot scripts/build_local.sh` to import, test, build and package both targets. Logs are in ignored `build/logs`. Native staging avoids system Trash permissions. Private GitHub main is the delivery branch; commit/push tested changes. The `.openai/` hosting metadata is ignored and must not be used to publish.

2026-10-29: private GitHub repository created and verified private. The mistaken `build-ashen-standard` heartbeat was deleted at the user's request. Source originally had no Git history; the initial prototype is preserved in the first commit.

Original prototype: Godot 4.5.1, GDScript, 24 recruits, 8 classes, 12 chapter campaign. Rules tests pass 528 assertions and presentation tests exercise all chapter scenes. No full balance playthrough yet. Browser and macOS exports work. Engine is locally at `/private/tmp/ashen-godot/Godot.app/Contents/MacOS/Godot`; pass `--log-file /private/tmp/ashen-<task>.log` in sandbox to avoid user-library logging errors. Custom export templates reside in ignored `.tools/templates`. Web postprocessor `python3 scripts/pack_web.py` compresses WASM. Local generated builds are ignored.

## Visual references inspected

- Awakening map: https://imgur.com/NKfaHAv — overhead map occupies viewport; dense pale cobbles, dark canal, bridges and market scenery; tiny detailed sprites and compact HP bars. Avoid the exposed floating checkerboard and oversized flat panels of our first version.
- Fates combat: https://static.gamesmen.com.au/media/catalog/product/cache/57ddbad6affa8d28869fa47188b75842/f/i/fire_emblem_fates_screenshot_4__2.jpg — low perspective with horizon and sky; textured ground continues into background; articulated silhouettes, attack poses, bright impact effects and damage numerals. No wooden mannequin limbs or empty black void.

These are reference links only. Do not copy Nintendo assets into the game or repository.

## Prioritized work

1. Refine the textured landscape, replacing repetitive round foliage and toy houses with richer original assets and distinct chapter environments.
2. Give the shared class sprites individual character identity; maintain clear picking and terrain overlays.
3. Add restrained ornament and portraits to the cream/parchment UI, keeping controls within the viewport at 1280x720.
4. Build articulated original 3D battle actors, class-specific silhouettes, weapon animations, camera motion, impact VFX and live combat HP display. Do not substitute 2D combat characters.
5. Character portraits and dialogue presentation; deepen recruitment scenes and chapter-specific maps.
6. Extend paired music arrangements, seamless loop boundary, attack sounds and spell effects.
7. Simulate/play all 12 chapters, tune progression and AI, improve equipment and promotion systems with tests.

## Working rules

Make real implemented improvements, then inspect gameplay screenshots and run relevant tests before committing/pushing. Keep a concise checkpoint here with honest limitations and the next task. Do not repeatedly claim completion of the overall game. No unsolicited hosting, public releases or new conversations.
