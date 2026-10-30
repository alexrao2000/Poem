# Authored combat models

The game can now use authored skeletal characters without changing campaign data, combat rules or saved games. The shipped catalog is empty: all current characters still use the procedural figures. No external models have been acquired. This adapter is infrastructure for replacing those figures, not a claim that their visual quality has improved.

Godot 4.5 imports `.glb` and `.gltf` into scenes and exports those imported resources for both browser and native builds. Put model files and their textures under `assets/models/`. Prefer a `.tscn` wrapper around the imported scene when adding weapons, a mount, `BoneAttachment3D` effect sockets, or other accessories. The wrapper and all dependencies must remain local. The project exports all resources, so catalog references are included even when no `.tscn` directly references them.

## Authoring contract

- Model faces local **-Z**, Y is up, feet sit at Y=0. The existing camera expects a roughly 1.8–2-unit standing character. Use catalog scale/yaw/offset for an explicit correction. There is no automatic bounding-box normalization.
- Bake locomotion in place. The cinematic moves the outer actor; root translation inside a walk/attack clip would otherwise double its movement.
- Keep the imported skeleton, skin, mesh and animation tracks together. The adapter does not retarget bones or combine unrelated skeletons.
- Include an AnimationPlayer and clips covering idle, advance, windup, strike, hit, evade and down. Map existing asset names; no renaming is required. Idle/advance loop. Other phases hold their final frame. A single slash can be split into windup and strike at its contact frame.
- Animation sections are played at a speed that fits the cinematic phase duration. Animations do not apply damage, consume randomness or dispatch gameplay events. Avoid method, audio and gameplay-property tracks in supplied clips.
- Optional `projectile` and `impact` sockets point to Node3D nodes within the model. A Marker3D under BoneAttachment3D is suitable. Without sockets, effects use the existing chest-height position.
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

`from` defaults to zero and `to` defaults to the clip length, in seconds. Named animation libraries use Godot's `library/clip` name. Optional `throw_windup` / `throw` and `cast_windup` / `cast` mappings fall back to windup and strike. Supply dedicated staff-casting clips for healers; their `projectile` socket should sit at the staff crown. Optional `guard`, `recover` and `victory` fall back to idle. Supply a `victory` section for the brief finishing hold after a resolved defeat. All paths are relative to the instantiated model root. Each actor gets its own animation resources, so sharing a clip between an idle loop and an attack segment does not change the other actor's playback.

Run `GODOT_BIN=/path/to/godot python3 scripts/test_local.py models` for adapter and full cinematic checks using an in-memory authored scene fixture. The fixture is never included in the game. Run `scripts/check_combat_models.gd` through Godot after adding assets to validate the actual catalog. Headless checks cannot establish visual quality; a final art review is still required.

References: [Godot 4.5 model formats](https://docs.godotengine.org/en/4.5/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html), [AnimationPlayer sections](https://docs.godotengine.org/en/4.5/classes/class_animationplayer.html), [BoneAttachment3D](https://docs.godotengine.org/en/4.5/classes/class_boneattachment3d.html).
