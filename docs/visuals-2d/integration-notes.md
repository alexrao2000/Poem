# Poem visual integration notes

This is the project-specific companion to the [portable requirements](README.md). The title screen now opens a working visual workshop with both map renderers, a shared catalog and sprite player, movement, combat, healing, effects, and enemy turns. Implementation and reuse instructions are in [the visual package](../../visuals/README.md). The main campaign retains its existing rendering path; the workshop owns a separate simulation and writes no campaign saves.

## Existing foundation

| Current component | Reusable foundation | Work required for the proposed profile |
| --- | --- | --- |
| `scripts/rules.gd` and `scripts/tactics.gd` | Grid simulation, legal routes, occupancy, terrain, combat outcomes | Retain as the authority for both map renderers |
| `scripts/portraits.gd` | Individual portrait and map-sprite lookup | Add stable visual mappings and versioned animation metadata; keep portrait lookup separate |
| `data/sprite_regions.json` | Per-character atlas rectangles for existing art | Existing entries describe single cropped images; they lack clip timing, facing, and foot pivots |
| `assets/sprites/company-a.png` through `company-c.png` | Existing original character identity and costume references | Author consistent pixel animation sheets; high resolution cropped illustrations do not satisfy the proposed pixel profile |
| `assets/art/class-sprites.png` | Existing class fallback imagery | Replace with profile-compatible animated class fallbacks before final delivery |
| `scripts/main.gd` | Unit transforms, route travel, map input, HUD, camera handoff | Extract presentation responsibilities behind map and sprite adapters before adding a second renderer |
| `scripts/scenery.gd` and `scripts/static_batch.gd` | Existing 3D terrain, props, materials, batching | Retain for the 3D map option; the 2D option needs its own tile and prop assets |
| `scripts/fighters.gd` and `scripts/fighter_actor.gd` | Existing separate 3D battle presentation | Retain while evaluating maps; separate 2D battle sprites are an optional later choice |
| `scripts/preferences.gd` | Existing full, player-only, and map combat preferences | These choose combat playback, not map dimensions; do not reinterpret their values |

Current map sprites use full billboarding, dynamic size normalization by texture height, and disabled depth testing. The proposed hybrid renderer needs stable authored pivots and source scale plus deliberate occlusion handling. The present setup must not be counted as satisfying those requirements simply because it already draws sprites over terrain.

The current project viewport is 1440 by 900 with canvas-item stretching. The proposed 640 by 360 world layer requires an explicit rendering and HUD-layout experiment; it is not the current project setting.

## Suggested adapter responsibilities

Create a visual catalog that resolves a character or class to a portable visual ID. Let a sprite player load the declared clips and expose state, facing, frame timing, and completion. Keep Godot-specific texture resources and node classes outside the portable metadata.

Provide two map adapters only for the comparison scene initially: a 2D adapter with layered tile and prop rendering, and a 3D adapter using the existing world. Both receive the same rules snapshot and legal route. Both expose cell projection, picking, overlays, unit movement, cancellation, and camera focus to the controller. Existing combat presentation receives resolved outcomes through a separate interface.

Do not move rules, combat RNG, or turn advancement into animation callbacks. Existing route and input locks need one clear owner so cancellation, quick combat, and camera return cannot leave the controller waiting for an animation that was skipped.

## Remaining production integration

1. Review the working eight-class sprite profile and both map compositions. The prototype uses two movement poses per facing, a shared release pose, held side/back idle poses, and recoil for defeat. Expand these into the authored production animation budgets after the visual direction is selected.
2. Produce individual recruit and promoted costume variants, plus a dedicated flyer identity if the receiving game needs one. Match them to existing portraits and combat identities.
3. Choose the production map direction, then generalize its environment adapters beyond the workshop's bridge, village, and forest composition. Both current adapters already consume the same logical model and legal routes.
4. Connect the selected renderer to campaign orchestration without moving damage, RNG, or turns into sprite callbacks. Keep existing save fields and combat preference semantics.
5. Complete minimum-hardware and browser performance review, then verify the full campaign's movement, undo, enemy turns, quick combat, cinematic combat, and camera restoration. Dedicated 2D close combat remains an independent art and implementation branch.

## Exporting to another project

Copy this folder's portable README and example manifest as the starting contract. Add the actual `source`, `textures`, `metadata`, `previews`, and `licenses` folders once assets are produced. Resolve engine resources and game-specific IDs in the receiving adapter.

Poem's roster, story, procedural combat actors, renderer, and save format are not dependencies of the shared asset package. Existing art can be reused where its provenance permits, but it still needs review against the chosen pixel profile. This integration note can be omitted when transferring the package.
