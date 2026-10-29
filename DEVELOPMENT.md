# Ashen Standard development

User direction: keep developing until explicitly stopped. The previous geometric prototype was rejected visually; resemblance to Awakening/Fates presentation is the priority, alongside the existing full roster and campaign. Keep local builds; the only authorized remote destination is the private GitHub repository https://github.com/alexrao2000/fe-clone. Never publish to Sites. No purchases.

## Current work

2026-10-29: private GitHub repository created and verified private. A 30-minute heartbeat named `build-ashen-standard` continues work in this chat until stopped. Source originally had no Git history; preserve the initial prototype in the first commit.

Original prototype: Godot 4.5.1, GDScript, 24 recruits, 8 classes, 12 chapter campaign. Rules tests pass 528 assertions and presentation tests exercise all chapter scenes. No full balance playthrough yet. Browser and macOS exports work. Engine is locally at `/private/tmp/ashen-godot/Godot.app/Contents/MacOS/Godot`; pass `--log-file /private/tmp/ashen-<task>.log` in sandbox to avoid user-library logging errors. Custom export templates reside in ignored `.tools/templates`. Web postprocessor `python3 scripts/pack_web.py` compresses WASM. Local generated builds are ignored.

## Visual references inspected

- Awakening map: https://imgur.com/NKfaHAv — overhead map occupies viewport; dense pale cobbles, dark canal, bridges and market scenery; tiny detailed sprites and compact HP bars. Avoid the exposed floating checkerboard and oversized flat panels of our first version.
- Fates combat: https://static.gamesmen.com.au/media/catalog/product/cache/57ddbad6affa8d28869fa47188b75842/f/i/fire_emblem_fates_screenshot_4__2.jpg — low perspective with horizon and sky; textured ground continues into background; articulated silhouettes, attack poses, bright impact effects and damage numerals. No wooden mannequin limbs or empty black void.

These are reference links only. Do not copy Nintendo assets into the game or repository.

## Prioritized work

1. Replace flat ground with painted textures, continuous landscape, paths, bridges, village props, atmospheric backdrop and readable camera.
2. Replace identical map silhouettes with original class sprites; maintain clear unit picking and terrain overlays.
3. Rework tactical UI into compact cream/parchment panels with dark text, ornate but restrained gold edges and readable forecasts.
4. Build articulated original 3D battle actors, class-specific silhouettes, weapon animations, camera motion, impact VFX and live combat HP display. Do not substitute 2D combat characters.
5. Character portraits and dialogue presentation; deepen recruitment scenes and chapter-specific maps.
6. Extend paired music arrangements, seamless loop boundary, attack sounds and spell effects.
7. Simulate/play all 12 chapters, tune progression and AI, improve equipment and promotion systems with tests.

## Working rules

Make real implemented improvements, then inspect gameplay screenshots and run relevant tests before committing/pushing. Keep a concise checkpoint here with honest limitations and the next task. Do not repeatedly claim completion of the overall game. No unsolicited hosting, public releases or new conversations.
