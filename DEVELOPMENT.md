# Ashen Standard development

User direction: keep developing until explicitly stopped. The previous geometric prototype was rejected visually; resemblance to Awakening/Fates presentation is the priority, alongside the existing full roster and campaign. Keep local builds; the only authorized remote destination is the private GitHub repository https://github.com/alexrao2000/fe-clone. Never publish to Sites. No purchases.

## Current work

### Latest checkpoint: first visual rebuild

Implemented and browser-inspected: original generated terrain atlas with world-space sampling/mipmaps; continuous terrain and canal beyond board edges; cobbled starting plaza, textured roofs, village houses, trees and distant hills; original eight-class sprite atlas and compact HP strips; translucent movement overlays; cream/gold UI; articulated 3D actors with faces, armor, capes, weapons and a mounted Rider; battle HP bars, damage numbers, hit sparks and camera shake. Modules split into `scenery.gd` and `fighters.gd`. Both local exports rebuilt with `scripts/build_local.sh`. All 528 rules checks pass; presentation checks cover 12 chapter scenes, all 24 actor constructions, cinematic return and ending. Browser console has been clean during observed gameplay. Representative captures are in ignored `build/map-v2.png` and `build/combat-v2.png` (combat capture is an earlier moment in this same pass).

**Still visibly short of the reference:** 3D figures are procedural and stiff; foliage and houses are repetitive; sprite identities are shared by class; all combat arenas use one environment; UI has little ornament; transitions do not yet track the selected tile. Music, chapter layout depth, equipment and campaign balance remain prototype-level. Prioritize another meaningful visual improvement next, particularly animated character posing and environment-specific battle staging. Do not spend another run only restating the plan.

Run `GODOT_BIN=/private/tmp/ashen-godot/Godot.app/Contents/MacOS/Godot scripts/build_local.sh` to import, test, build and package both targets. Logs are in ignored `build/logs`. Native staging avoids system Trash permissions. Private GitHub main is the delivery branch; commit/push tested changes. The `.openai/` hosting metadata is ignored and must not be used to publish.

2026-10-29: private GitHub repository created and verified private. A 30-minute heartbeat named `build-ashen-standard` continues work in this chat until stopped. Source originally had no Git history; preserve the initial prototype in the first commit.

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
