# Authored combat models

The game can now use authored skeletal characters without changing campaign data, combat rules or saved games. The shipped catalog is empty: all current characters still use the procedural figures. Two locally supplied CC0 Quaternius rigs are now assembled and imported as source prototypes. Both are available as debug model studies with a fitted original sword. Character styling and broader combat presentation remain unfinished, so they are not enabled in the campaign catalog.

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

The assembler verifies the named bone hierarchy, preserves separate mesh inverse binds, trims the base body below the head/neck influences, and converts mannequin animation offsets to the outfit rest pose. It includes seven in-place clips: idle, sword-ready, sword attack, jog, chest hit, death and roll. Godot removes the `_Loop` suffix from imported clip names. Two broken eye/hair normal filenames in the source archive are resolved only when the adjacent bytes match its explicitly labeled Unity/Godot texture copy.

Unused body vertices, mannequin data and unselected animations are removed; the two binary buffers total about 3.8 MB. Original texture bytes remain intact, with Godot imports capped at 1024 pixels and mipmaps enabled. An isolated software pose study showed coherent head/clothing attachment. Its image was byte-identical before and after buffer compaction; it is not a game screenshot or shader review.

Validation: `python3 -m unittest discover -s tests -p test_quaternius_import.py -v` checks source hashes/licenses, buffer reachability, indices, normalized attributes, rotation remapping and import settings. `GODOT_BIN=/path/to/godot python3 scripts/test_local.py source_models models` checks 70 actual imported poses (over one million skinned-vertex samples), one shared 65-bone skeleton per model, eye attachment, bounded geometry, clip track types, runtime texture dimensions and the authored adapter. These checks do not establish weapon contact, character identity or rendered-game quality.

## Inspecting the source models

Enable **Debug mode** in Options, open **Debug tools**, then choose **View female duelist rig** or **View male duelist rig**. Both open the ordinary rotating/zooming outfit viewer with the imported skeleton, selected clips and an original Poem iron sword. The source figures are labeled as studies; they do not replace a recruit or write a save. Closing the viewer returns to the same debug tools; leaving debug restores the original campaign.

The two wrapper scenes attach the sword to `hand_r`, plus chest/eye and blade-edge sockets. The palm offset is fixed through animation. The sword clip uses 0–0.36 s for preparation, 0.36–0.433 s for the forward crossing, and 0.433 s onward for recovery. The measured crossing is approximately 1.6 m forward and 1.3 m high; this is the unmodified source clip. The optional arm fit described below adjusts that crossing to the actual opponent.

The viewer now samples animated bone-space bounds, rather than imported rest-pose mesh boxes. Each mesh's weighted vertices are enclosed by its influencing bones' bind-space boxes; only those box corners are transformed during playback. Actual skinned-vertex checks verify containment. Direct animation seeks also synchronize bone attachments before weapon/contact sampling. Source-study tests cover 720 pose/rotation/viewport layouts, wrist attachment, fixed palm offsets, clip sections, replay and debug isolation; ordinary outfit framing and adapter regressions remain covered. Assembled visual review remains outstanding.

Both imported scene instances declare `[editable path="Rig"]` in their wrappers. Direct project loading retained nested additions without it, but the release PCK dropped their weapon/chest/face attachments. The declaration fixes both exported rigs; packaged-resource smoke exercises the real debug preview and its blade sockets.

## Optional authored arm contact

A model entry may define `contact` with `skeleton` (a relative node path) and `bones` (wrist, elbow, upper arm, in that order). All three must form a direct parent chain. Its `trail_inner` and `trail_tip` sockets must belong to a BoneAttachment3D on that wrist. Invalid bindings reject that candidate and preserve the library's existing fallback behavior.

The presentation modifier runs after the animation, following Godot's [SkeletonModifier3D contract](https://docs.godotengine.org/en/4.5/classes/class_skeletonmodifier3d.html). It chooses a contact point on the blade's solid outer section, solves the two arm lengths with the authored elbow side, then refines rotations within bounded joint offsets. It does not translate or scale bones, move the grip, alter weapon range, change hit rolls or apply damage. Strike blends into the correction; recovery blends back to the authored motion. Direct socket samples restore the original animation input to avoid accumulating corrections.

The debug viewer's **Target** selector compares the original strike with standing/mounted target heights. The marker follows model rotation; selecting a target replays the attack. Disabling it restores the source motion. Twenty fitted targets across both rigs and directions pass within 6 mm of the actual blade segment. Eight full cinematic checks cover mounted hits and shield blocks, including counterattacks/criticals, within the same measured tolerance. Grip transforms, arm lengths/scales, repeated samples, invalid bindings, campaign state and RNG remain checked. An isolated skinned pose study was inspected; actual rendered gameplay, browser performance and complete roster styling still need review.
