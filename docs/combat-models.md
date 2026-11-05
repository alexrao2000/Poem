# Authored combat models

The game can now use authored skeletal characters without changing campaign data, combat rules or saved games. The shipped default catalog is empty: the current presentation remains the default. **Options → Character models → Revised models · preview** selects the five revised recruits in ordinary campaign battles and outfit previews. Two locally supplied CC0 Quaternius rigs are now assembled and imported as source prototypes. Both are available as debug duelist studies with a fitted original sword. Two casting studies use the male/female bodies with supported original folios. Optional styling adds Lyra, Nell, Silas, Tarin or Vela’s original identity. Broader combat presentation remains unfinished, so the normal campaign catalog remains empty. Independent debug toggles select the styled duelists or casters for battle comparison. The normal preference stays local to the device and is absent from campaign saves/transfer codes. Older preference files load the current presentation; malformed values are rejected. Debug sessions inherit the selected appearance, then temporarily override it with their independent model switches.

Godot 4.5 imports `.glb` and `.gltf` into scenes and exports those imported resources for both browser and native builds. Put model files and their textures under `assets/models/`. Prefer a `.tscn` wrapper around the imported scene when adding weapons, a mount, `BoneAttachment3D` effect sockets, or other accessories. The wrapper and all dependencies must remain local. The project exports all resources, so catalog references are included even when no `.tscn` directly references them.

## Authoring contract

- Model faces local **-Z**, Y is up, feet sit at Y=0. The existing camera expects a roughly 1.8–2-unit standing character. Use catalog scale/yaw/offset for an explicit correction. There is no automatic bounding-box normalization.
- Bake locomotion in place. The cinematic moves the outer actor; root translation inside a walk/attack clip would otherwise double its movement.
- Keep the imported skeleton, skin, mesh and animation tracks together. The adapter does not retarget bones or combine unrelated skeletons.
- Include an AnimationPlayer and clips covering idle, advance, windup, strike, hit, evade and down. Map existing asset names; no renaming is required. Idle/advance loop. Other phases hold their final frame. A single slash can be split into windup and strike at its contact frame.
- Animation sections are played at a speed that fits the cinematic phase duration. Animations do not apply damage, consume randomness or dispatch gameplay events. Avoid method, audio and gameplay-property tracks in supplied clips.
- Optional `projectile`, `impact` and `gaze` sockets point to Node3D nodes within the model. Place `gaze` at eye height so a procedural opponent can look toward it; without one, the adapter uses a point 0.55 units above the impact socket. A Marker3D under BoneAttachment3D is suitable. Without sockets, effects use the existing chest-height position.
- Include weapons, class clothing, and mounted geometry in the scene. The adapter does not graft procedural equipment onto an authored skeleton.
- Use compact meshes and atlas textures with the Compatibility renderer in mind. Keep separate enemy palettes and test the model gallery, melee, ranged, hit, dodge and defeat poses in both target builds before considering an asset complete.
- Record author, license, source URL and any modifications alongside each acquired asset. Do not include Nintendo assets.

## Catalog

`data/combat_models.json` contains `version: 1` and four dictionaries. Selection tries `characters[unit.id]`, then `promotions[unit.promotion]`, then `classes[unit.job]` for allies or `enemy_classes[unit.job]` for enemies. An invalid candidate is recorded in the model library's `issues` list and the next candidate is attempted. If none succeeds, the existing procedural actor is used.

Example entry inside `characters` (the example asset is not shipped):

```json
{
  "lyra": {
    "scene": "res://assets/models/lyra/lyra.tscn",
    "player": "Rig/AnimationPlayer",
    "scale": 1.0,
    "yaw": 0.0,
    "offset": [0, 0, 0],
    "sockets": {
      "projectile": "Rig/Skeleton3D/WeaponHand/Release",
      "impact": "Rig/Skeleton3D/Chest/Impact"
    },
    "poses": {
      "idle": {"clip": "Idle"},
      "advance": {"clip": "Run"},
      "windup": {"clip": "SwordSlash", "from": 0, "to": 0.42},
      "strike": {"clip": "SwordSlash", "from": 0.42, "to": 0.68},
      "hit": {"clip": "Hit"},
      "evade": {"clip": "Dodge"},
      "down": {"clip": "Defeat"}
    }
  }
}
```

`from` defaults to zero and `to` defaults to the clip length, in seconds. Named animation libraries use Godot's `library/clip` name. Optional `throw_windup` / `throw` and `cast_windup` / `cast` mappings fall back to windup and strike. Supply dedicated staff-casting clips for healers; their `projectile` socket should sit at the staff crown. Optional `critical_hit` falls back to the authored `hit` section. Optional `guard`, `recover` and `victory` fall back to idle. A `guard` socket can place blocked projectiles and contact flashes on a shield; without one they use the authored `impact` socket. Supply a `victory` section for the brief finishing hold after a resolved defeat. An optional `victory_flourish` plays for 220 ms before this hold; models without it go straight to the existing finish. All paths are relative to the instantiated model root. Each actor gets its own animation resources, so sharing a clip between an idle loop and an attack segment does not change the other actor's playback.

Run `GODOT_BIN=/path/to/godot python3 scripts/test_local.py models` for adapter and full cinematic checks using an in-memory authored scene fixture. The fixture is never included in the game. Run `scripts/check_combat_models.gd` through Godot after adding assets to validate the actual catalog. Headless checks cannot establish visual quality; a final art review is still required.

References: [Godot 4.5 model formats](https://docs.godotengine.org/en/4.5/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html), [AnimationPlayer sections](https://docs.godotengine.org/en/4.5/classes/class_animationplayer.html), [BoneAttachment3D](https://docs.godotengine.org/en/4.5/classes/class_boneattachment3d.html).

Optional `trail_inner` and `trail_tip` sockets enable swept melee ribbons. Both must resolve to distinct animated Node3D positions on the held weapon. Their world positions are sampled during the strike, including the model's scale/yaw/offset. Models without a usable pair keep the painted contact-accent fallback. These presentation sockets do not change weapon reach or combat rules.

## Local CC0 source prototypes

`assets/models/quaternius/` contains female/male peasant outfits, trimmed head/neck meshes, eyes, brows and rigged hair assembled from the locally supplied Standard packs. These packs contain only peasant/ranger outfits, not the entire armor collection shown in the promotional image. The [provenance manifest](../assets/models/quaternius/provenance.json) records archive hashes and modifications; the supplied licenses are retained beside it and in both exported packages.

Regenerate with Python's standard library and the three local ZIPs:

```sh
python3 scripts/import_quaternius.py --outfits /path/to/outfits.zip --base /path/to/base.zip --animations /path/to/animations.zip
```

The assembler verifies the named bone hierarchy, preserves separate mesh inverse binds, trims the base body below the head/neck influences, and converts mannequin animation offsets to the outfit rest pose. It includes eleven in-place clips: idle, sword-ready, sword attack, jog, chest hit, death, roll and four casting clips (enter, exit, held idle and release). Godot removes the `_Loop` suffix from imported clip names. Two broken eye/hair normal filenames in the source archive are resolved only when the adjacent bytes match its explicitly labeled Unity/Godot texture copy.

Unused body vertices, mannequin data and unselected animations are removed; the two binary buffers total about 4.5 MB. Original texture bytes remain intact, with Godot imports capped at 1024 pixels and mipmaps enabled. An isolated software pose study showed coherent head/clothing attachment. Its image was byte-identical before and after buffer compaction; it is not a game screenshot or shader review.

Validation: `python3 -m unittest discover -s tests -p test_quaternius_import.py -v` checks source hashes/licenses, buffer reachability, indices, normalized attributes, rotation remapping and import settings. `GODOT_BIN=/path/to/godot python3 scripts/test_local.py source_models models` checks 110 actual imported poses (about 1.58 million skinned-vertex samples), one shared 65-bone skeleton per model, eye attachment, bounded geometry, clip track types, runtime texture dimensions and the authored adapter. These checks do not establish weapon contact, character identity or rendered-game quality.

## Inspecting the source models

Enable **Debug mode** in Options, open **Debug tools**, then choose **View female duelist rig** or **View male duelist rig**. Both open the ordinary rotating/zooming outfit viewer with the imported skeleton, selected clips and an original Poem iron sword. The source figures are labeled as studies; they do not replace a recruit or write a save. Closing the viewer returns to the same debug tools; leaving debug restores the original campaign.

The two wrapper scenes attach the sword to `hand_r`, plus chest/eye and blade-edge sockets. The palm offset is fixed through animation. The sword clip uses 0–0.36 s for preparation, 0.36–0.433 s for the forward crossing, and 0.433 s onward for recovery. The measured crossing is approximately 1.6 m forward and 1.3 m high; this is the unmodified source clip. The optional arm fit described below adjusts that crossing to the actual opponent.

The viewer now samples animated bone-space bounds, rather than imported rest-pose mesh boxes. Each mesh's weighted vertices are enclosed by its influencing bones' bind-space boxes; only those box corners are transformed during playback. Actual skinned-vertex checks verify containment. Direct animation seeks also synchronize bone attachments before weapon/contact sampling. Source-study tests cover 720 pose/rotation/viewport layouts, wrist attachment, fixed palm offsets, clip sections, replay and debug isolation; ordinary outfit framing and adapter regressions remain covered. Assembled visual review remains outstanding.

Both imported scene instances declare `[editable path="Rig"]` in their wrappers. Direct project loading retained nested additions without it, but the release PCK dropped their weapon/chest/face attachments. The declaration fixes both exported rigs; packaged-resource smoke exercises the real debug preview and its blade sockets.

## Optional authored arm contact

A model entry may define `contact` with `skeleton` (a relative node path) and `bones` (wrist, elbow, upper arm, in that order). All three must form a direct parent chain. Its `trail_inner` and `trail_tip` sockets must belong to a BoneAttachment3D on that wrist. Invalid bindings reject that candidate and preserve the library's existing fallback behavior.

The presentation modifier runs after the animation, following Godot's [SkeletonModifier3D contract](https://docs.godotengine.org/en/4.5/classes/class_skeletonmodifier3d.html). It chooses a contact point on the blade's solid outer section, solves the two arm lengths with the authored elbow side, then refines rotations within bounded joint offsets. It does not translate or scale bones, move the grip, alter weapon range, change hit rolls or apply damage. Strike blends into the correction; recovery blends back to the authored motion. Direct socket samples restore the original animation input to avoid accumulating corrections.

The debug viewer's **Target** selector compares the original strike with standing/mounted target heights. The marker follows model rotation; selecting a target replays the attack. Disabling it restores the source motion. Twenty fitted targets across both rigs and directions pass within 6 mm of the actual blade segment. Eight full cinematic checks cover mounted hits and shield blocks, including counterattacks/criticals, within the same measured tolerance. Grip transforms, arm lengths/scales, repeated samples, invalid bindings, campaign state and RNG remain checked. An isolated skinned pose study was inspected; actual rendered gameplay, browser performance and complete roster styling still need review.

## Equipped swords and motion compatibility

The debug studies offer iron, dueling and tempered swords. Selection rebuilds the actor with the existing game's exact blade, guard, material colors and trail endpoints, retaining the inspection angle. It does not equip or unlock an item in the campaign. Both source rigs keep fitted contact with all three swords.

An optional model entry `equipment` identifies a node implementing `configure_equipment(kind, item) -> String`; it returns an empty string on success. Equipment is built before animation/effect sockets are resolved. Optional `supported_items` is a nonempty list of item IDs. An item outside that list skips the candidate and preserves normal fallback, without treating an intentional exclusion as a broken model. The current source slash rigs exclude the estoc, preserving its existing procedural point-first animation.

Six actual rig/item combinations verify original mesh vertices, colors, trails and fitted contact. Runtime viewer switching, active-target replacement, compact controls and unchanged campaign/RNG are covered; exported-package smoke uses a tempered sword and a mounted target. Invalid equipment specifications leave no partial actor. The catalog checker now supplies a declared supported item and cannot silently pass a filtered-out entry without instantiating it.

## Original character styling

**Character styling** in either debug study switches between the supplied source figure and Nell (female rig) or Silas (male rig). Their original sculpted head, painted face, hair and skin/cloth palette follow the imported skeleton. Brown leather retains the supplied texture; cloth tint preserves its shading and normals. All replacements/materials belong to the actor instance. Changing swords keeps styling and facing; turning styling off restores the source figure. Neither choice changes the campaign.

Optional model-spec `appearance` names a node implementing `configure_identity(id) -> String`, with an empty string meaning success. The adapter forwards pose changes and opponent references to descendant listeners implementing `combat_pose`; the original blink/reaction controller respects hit-stop. Dyed materials participate in the existing defeat fade. The shared original face-index mapping is unchanged for procedural actors.

Validation covers private materials and expressions, original source visibility, equipment switches, contact fitting, all three viewer sizes and head/hair framing through rotated action poses. Standalone exported-package smoke builds both styled figures. An isolated software geometry/material comparison was inspected for silhouettes, head/neck fit and palette masking; it is not an in-game screenshot or a GPU shader review. Actual rendered-game review remains outstanding.

## Ground-distance playback

Optional `stride` entries specify `length` (model-space metres per cycle), a `skeleton` path, two `feet` bone names and two ascending `contacts` phases in [0, 1). Only the `advance` pose uses this clock. Actual signed ground travel advances the clip, including easing, reversal, actor/model scale and facing. Stationary actors hold the pose; relocations exceeding two cycles rebase without a burst of footfalls. Existing imported entries without `stride` retain ordinary timed playback.

The source root-motion jog covers 5 m per loop, but the outfit retarget changes the foot path. Least-squares fits to both toe bones over planted phases .06–.18 and .56–.68 give 5.4124 m/cycle for the female rig and 5.6643 for the male rig. Contacts occur at .05/.55. These values reduce measured horizontal stance slip to about 1.2 cm across that interval; this is timing calibration, not a full foot-lock solver. Ground effects use the lowest toe projected onto the arena floor. The debug viewer explicitly supplies virtual travel at the clip's nominal speed while keeping the figure in place.

Paused `AnimationPlayer.seek` does not advance an active crossfade in Godot 4.5.1. The adapter advances its blend clock by the travelled clip-time equivalent before seeking, preventing the old pose from freezing underneath a moving cursor. This was isolated with two constant-property clips; the source clips contain bone transforms only. See the [AnimationPlayer API](https://docs.godotengine.org/en/4.5/classes/class_animationplayer.html).

`authored_stride` checks 54 eased approaches across rates, scales and headings, stationary/reverse/teleport behavior, real toe drift, invalid configuration cleanup and four actual cinematic approaches with sound-contact/dust signals and unchanged simulation/RNG. Source-study preview and standalone exported-package smoke exercise in-place playback.

## Trying the revised duelists in battles

In **Options → Debug mode → Open debug tools**, enable **Revised duelist models**. Nell and Silas then use the styled skeletal models in normal battles and outfit previews with iron, dueling or tempered swords, before promotion. Estoc thrusts, promotion costumes, other recruits and enemies keep their current models. The toggle starts off each debug session and clears when Debug mode ends. It does not change equipment, stats, RNG, the normal model catalog or either campaign save; experiment reports include the presentation choice separately from the restore code.

`debug_models` exercises the actual toggle, six rig/item bindings, ordinary outfit preview, critical-hit, missed, victory and defeat exchanges and fallback boundaries. It verifies exact live-campaign restoration and an untouched normal disk save. A battle-menu regression found during this check is also fixed: returning from Debug tools, or rebuilding Options after restoring preferences, no longer tries to update a freed tactical panel. Existing debug controls still pass at three viewport sizes.

The combat evade mapping uses the first 0.1667 s of `Hit_Chest` as a standing recoil alongside the existing sideways dodge. The full supplied unarmed `Roll` remains in the source asset but is no longer used for armed evasion: measured held-sword geometry penetrated the floor by over 40 cm midway through the roll. Seventeen samples for each rig/sword combination keep the standing dodge's actual blade and guard above the floor; an isolated idle/recoil geometry study was inspected.

Optional `framing` supplies per-shot camera distance margins from 1 to 2 for `wide`, `windup`, `impact` and `finish`. The director uses the largest requested margin among the two actors, preserves the same focus/lens/axis, and eases to that distance through the normal shot tween. The duelist studies request 1.14 only for windup: the original camera put raised blades inside the top HUD margin at 1024×640 and 1280×720. All 1,080 sampled head/weapon layouts now fit across both directions, infantry/mounted opponents, five pose/shot combinations and three viewport sizes. Ordinary combat framing and impact/finish distances remain unchanged.


## Opponent attention on styled rigs

Styled Nell/Silas turn their heads toward the opponent during ready, approach, attack and recovery poses. `authored_gaze.gd` bounds the target in actor space to about 26 degrees horizontally and 18 degrees vertically, then uses Godot's native `LookAtModifier3D` on the Head bone. This avoids interpreting the supplied rig's tilted rest axes as anatomical yaw/pitch. Influence enters gradually; hit, evade, defeat and finishing clips retain their complete authored head motion. Hidden, rear, invalid or removed targets release tracking, and hit-stop freezes it with the actor.

The original replacement heads now meet a small cropped section of the supplied skinned neck, retaining its weights, UVs, normals and inverse binds. The crop excludes the source chin so it cannot protrude through the smaller original face. Immutable neck meshes are cached across previews; palette and defeat opacity remain private to each actor. Unstyled source figures remain unchanged.

`authored_gaze` checks both final head attachments and skin poses across 36 headings/target heights/offsets, normalized neck weights, bounded deformation, source preservation, cache reuse, reaction release, hit-stop and invalid-target teardown. Export smoke also exercises a mounted-height gaze. The inspected four-panel software geometry study is an asset review, not assembled-game or GPU rendering.


## Company cloaks on the revised duelists

Styled Nell/Silas retain their original blue forked company cloaks, including the shared embroidered mark and individual palette. `authored_cloak.gd` fits the original 72-triangle cut to the supplied shoulder width and upper-spine rest transform. The existing bounded cloth motion follows combat poses and freezes during hit-stop. Only these instance-owned materials opt into a world-height floor clamp after cloth displacement, preventing the falling source clip from sending the cloak below the arena. This is a simple floor constraint, not simulated fabric or body collision.

Imported presentation listeners can implement `materials_remapped(copies)` to keep live controllers bound when defeat creates private fading materials. The cloak and original face use this hook; surviving actors and source material caches stay untouched. Tests cover 306 actual shoulder-edge samples, identity/material isolation, floor-plane relocation, hit-stop/hidden clocks, fade rebinding, original cloak regressions, wide/finish framing and complete debug battles. The eight-panel isolated software asset study was inspected; GPU floor shading and assembled appearance still require review.


## Fitted equipped grip

Source fall and recoil clips open the sword hand. Equipment may now implement `configure_animations(player) -> String`, called after the adapter creates private animation copies. The duelist equipment derives fifteen right-finger rotations from its sword-ready pose, relaxing them slightly toward rest to leave room for the hilt, and uses that grip throughout those copies. Missing profiles return an error; repeated setup does not accumulate tracks or progressively reopen the fingers. The free hand, wrist, arm, translations/scales, clip timing and shared source assets remain unchanged.

The imported handles have 14 mm (female) / 17 mm (male) radii instead of the larger procedural actors' 27 mm radius. Their lengths, guards, blades and effect sockets remain unchanged. An isolated hand study caught finger intersections with the old thick handle; the fitted grasp was inspected from the palm side. `authored_grip` checks 1,836 clip samples across both rigs, three swords and two headings, actual fingertip-to-hilt proximity, every non-finger bone, source independence, repeat setup and missing-profile errors. Other equipment/source/contact/debug regressions and packaged falling-grip smoke cover integration.


## Casting study

**Debug tools → View male casting rig / View female casting rig** open separate source studies. **Character styling** gives them Tarin or Vela's original face, hair, palette and full company cloak. Ember, Gale and Thunder keep their original printed folios; the source animation casts with the free left hand. The right hand supports the tome in front of the torso using `skeletal_hold.gd`, a two-bone arm solve driven by the current chest pose. Reach clamps during the fall instead of stretching the arm. The separate **Revised casting models** toggle opts Tarin and Vela into debug battles and outfit previews before promotion. It is independent of the duelist comparison and resets when Debug mode ends. Enemies, other recruits, changed classes and unsupported equipment retain the normal model builder.

The common `authored_hand_pose.gd` fits private equipment finger tracks, leaving the casting fingers untouched. Imported actors sample custom skeletal constraints for immediate socket queries as well as native animation updates; direct sampling respects modifier influence and restores the source pose. The new wrapper retains the required editable Rig declaration. Source-study identity, label and default equipment now come from the study catalog.

`authored_caster` checks 918 poses across three folios and two headings, stable repeated sampling, unchanged bone transforms, book floor clearance, native/direct blend agreement and hit-stop. Standing targets resolve within 0.1 mm; the unreachable fall target stays within 4.6 cm while preserving arm lengths. The actual viewer is exercised at three sizes with style/equipment switches and replay. Three complete elemental cinematics verify charge and projectile origins at the free palm with unchanged campaign/RNG. The inspected four-pose software asset study is not assembled-game rendering; the outfit remains a body/casting prototype.

`debug_caster` checks six complete exchanges, all three elements, mounted opponents, criticals, dodges, finish/defeat and four phase-specific skips. Campaign, disk save, RNG, camera and audio-clock ownership survive the comparison unchanged. `caster_framing` samples 648 head/folio/casting-palm layouts across both headings, foot/mounted targets, six poses and three window sizes, including full cape bounds in wide/finish shots. These are input/resource/projection checks, not an assembled rendering review.

Styled imported identities now bind their original loose hair beneath the attached head. The shared bounded motion controller retains braid/long-hair scalp roots, keeps fringe/face geometry fixed, and obeys actor hit-stop and visibility. Defeat fades include loose meshes. The female caster reuses the source clip library without duplicating its buffers, and her support solve clamps the unreachable fall target within 8 mm. Her isolated four-pose asset study was inspected; assembled GPU rendering is still unreviewed.


## Skinned caster robes

Styled Tarin/Vela retain the original folded mage garment and gold hem over the source outfit. `authored_robe.gd` fits the waist and length in skeleton rest space, pins the waistband to the pelvis, then blends each side through its thigh/lower leg. An open front and rear vent let opposite legs move without pulling one continuous back panel. The gold hem joins the final fabric row without an overlapping surface, so it stays visible during deformation. The denser vertical fold mesh stays shared per fitted body; each actor owns its fabric and trim materials. Existing procedural garment defaults are unchanged.

The shared character shader now permits floor contact independently of cape flutter and embroidery. This keeps a falling skinned robe above the actor's current arena floor. The browser renderer applies skinning in its [skeleton pass](https://github.com/godotengine/godot/blob/4.5-stable/drivers/gles3/shaders/skeleton.glsl) before the material's [vertex stage](https://github.com/godotengine/godot/blob/4.5-stable/drivers/gles3/shaders/scene.glsl); the floor constraint therefore operates on the posed garment. This remains a simple floor constraint, not body collision or cloth physics. Assembled GPU appearance is unreviewed.

Material-remap listeners are discovered independently of pose listeners, allowing a nonanimated garment controller to rebind its floor uniforms after defeat clones its materials. `authored_robe` checks 612 actual skinned poses, inverse binds, packed normalized weights, fixed waist, finite deformation, edge stretch, animated bounds, cache reuse, private materials and relocated floor contact after fading. Camera checks include the skinned robe in wide and finishing shots. Isolated idle/cast/fall and eight running-phase studies inform the fit.


## Lyra’s Vanguard model

The Vanguard study reuses the female sword rig and fits Lyra’s original long hair, soft face, ivory shoulder mantle, lapels, gold fastening and full company cloak. The normal revised-model preference includes her from chapter one with supported swords before promotion. Debug tools provides an independent **Revised Lyra model** switch and source study. Enemies, unsupported weapons and promotion outfits retain the normal builder.

`authored_mantle.gd` fits the garment to the upper spine, with separate private fabric/metal batches and floor/fade bindings. A diagnostic asset close-up exposed intersections with the supplied bodice. The final collar flare and lapel depth were checked against actual skinned torso vertices in nine poses; the covered region clears the body. The original source outfit is unchanged beneath it. Pose, viewer, mounted-contact and camera checks include the mantle. The isolated software asset study is not an assembled-game rendering review.


### Revised silhouette outlines

Styled source actors use `authored_outline.gd` and `authored-outline.gdshader`, with a 2.5 mm maximum local shell. Unlike the rigid procedural helper, this pass uses native `NORMAL`, which follows the renderer's skin transform; no source mesh/color/skin buffers are rewritten. Each actor owns its main-material copies and shell passes. All surface slots are handled, including the two male arm materials. Hidden source heads, painted expression cards, printed folio pages, transparent/emissive materials and unknown shaders are excluded.

The outline driver runs after the cloth drivers, copying the exact cloth clock/drive and floor plane. Flattened shells sit 0.5 mm below the fabric plane to avoid coplanar ink. The defeat material remap updates both sides of each pair and the identity's live dye references. Inherited hit-stop and visibility suspend motion. This adds one draw pass per eligible surface; actual browser GPU cost and assembled appearance still need measurement. Isolated software comparisons are asset studies, not GPU screenshots.


Revised cloak/robe/mantle linen uses `fabric_detail=0.25` in the original character shader. The mix is centered on the current atlas quadrant’s measured linear RGB mean `(0.661445, 0.568573, 0.449824)`, preserving mean brightness and color rather than whitening the material. The company embroidery is composed afterward and retains its contrast. Other users keep the shader default `1.0`. Before/after close studies used bilinear sampling to avoid exaggerating weave with nearest-neighbor sampling; actual GPU appearance remains unreviewed. If the linen atlas is replaced, remeasure this neutral point.


### Additional recruit identities

A study may list `campaign_characters` to offer its fitted rig to additional canonical recruits of the same base class and weapon. Each gets a separate specification and live identity/material state; meshes and source animations remain shared. Missing or incompatible recruits are rejected. `study_character` remains the representative in the source viewer. Female Duelist now covers Nell/Yuna; female Arcanist covers Vela/Noor. Together with Lyra, Silas and Tarin, seven recruits use the opt-in revised campaign models. Promotions, enemy units, changed classes and unsupported items still fall back. No campaign save or simulation changes are involved.
