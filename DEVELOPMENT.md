# Ashen Standard development

User direction: keep developing continuously in this chat until the user returns/stops work or available usage is exhausted. **Do not schedule anything.** The user clarified that the earlier heartbeat was unwanted; it has been deleted. They authorize model switching if one model is exhausted and another is available, but the current tool surface has no direct self-model switch and usage currently reports a shared Codex pool. The previous geometric prototype was rejected visually; resemblance to Awakening/Fates presentation is the priority, alongside the existing full roster and campaign. Keep local builds; the only authorized remote destination is the private GitHub repository https://github.com/alexrao2000/fe-clone. Never publish to Sites. No purchases.

## Current work

### Latest checkpoint: authored campaign, tactical AI, painted materials and score

All 12 maps now have distinct authored routes, deployment positions, enemy formations, objectives, landmarks and tactical briefings (`scripts/author_maps.py`). Board bounds and objective positions are data-driven. Opening town includes blocked building footprints and a fountain. Enemy planning uses reverse weighted paths to attack positions, respects bow minimum range, holds guards in place and activates sentries. All movement, undo, healing, tonics and attacks use validated simulation actions.

Three full automated campaign runs (seeds 472019, 17, 309) clear all 36 chapter instances using legal actions. This demonstrates progression, not final difficulty balance. Saves use atomic replacement, a previous-save backup, data validation and a per-map layout signature; older/changed battles resume at camp. 525 rules assertions, tactics, saves, campaign, presentation, story and audio suites pass.

Original painted foliage/bark/masonry atlas, more detailed houses and chapter-specific landmarks/lighting. New actor material atlas and toon shading, tapered armor shells, smaller heads, class clothing colors and split coat panels. All original art prompts are in docs. 24 portraits, biographies/epilogues and 103 dialogue lines remain integrated. All 24 recruits now have original individual map sprites matching their portraits; alpha-bound atlas metadata normalizes size across sheets. Browser-inspected opening town, blocked building footprints, unit identities, save migration, forecast and actual textured 3D combat. Hip volume and curved capes corrected after visual inspection. Captures: `build/map-v4.png`, `build/combat-v4.png`.

Original paired score extended to 32 bars / 71.11 seconds, stereo, with shared note/harmony/sample timeline. Calm arrangement uses flute/harp/strings; intense version adds stronger strings/horns/bass/percussion. All voices/effects are synthesized, with no sampled recordings. Stereo loop frame counts verified; combat/healing/phase effects integrated. Regeneration script requires NumPy.

**Remaining limits:** still procedural 3D models, repetitive environment geometry, no equipment/support/promotions system, no full human balance pass. Next: enemy inspection and danger overlays, then character loadouts/progression while continuing visual refinement. No scheduling; keep working in this chat until the user returns or usage is exhausted.

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
