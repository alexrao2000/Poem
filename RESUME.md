# Poem — paused handoff

Paused at the user's request on 2026-10-30. **Do not continue development until the user says “go” or otherwise asks to resume.** No scheduled work or background development is requested.

## Resume here

Read this file, the current `DEVELOPMENT.md` checkpoint, and the latest sections of `docs/art-direction.md`. Run the user's Marble sync and read its three indexes as instructed in AGENTS.md. Check Git status before editing; preserve unrelated changes. Resume improving resemblance to Awakening/Fates, with particular attention to complete scenes and animation rather than accumulating isolated geometry details.

The final completed change replaces spherical metal elbows on armored outfits with closed, faceted elbow guards and continues cloth across unarmored elbows. It preserves joints and animation sockets. `scripts/elbow_guard.gd` owns the shared 120-triangle mesh; `scripts/fighters.gd` chooses the covering; `tests/test_equipment_visuals.gd` verifies topology, normals, UVs, armor classification and cloth tint. Explicit face normals fixed the initial smoothed-normal test failure. A standalone eight-panel original geometry study was inspected. This is not a rendered-game review.

Prior completed work includes five class cloak cuts and exposed ranger quivers, enemy/commander camera headroom, repeatable outfit-viewer actions, pale damage/hit/critical rows with immutable pre-exchange forecasts, shaped horse head/body/neck, world-planted infantry/cavalry movement, and a descending arena entrance.

## Project and authorization

- Working title: **Poem**. Godot 4.5.1 / GDScript, local browser and macOS builds.
- Active worktree: `/Users/alexr/.codex/worktrees/combat-presentation/fe-clone`, branch `codex/combat-presentation`.
- Primary checkout: `/Users/alexr/Poem`, branch `main`.
- Private remote: https://github.com/alexrao2000/Poem . Nondestructive commits/pushes already authorized.
- Keep game local. No Sites/Vercel/public hosting, purchases or schedules.
- Preserve primary stash `Preserve shared workshop edits before combined presentation integration`.
- No subagents unless subsequently authorized by applicable instructions.
- Use `open -g` for launching applications; preserve focus.

The campaign has 24 recruits, eight classes, twelve chapters, sixteen promotions and 36 supports. The default test runner has 70 suites. Current rigid roster count is 1,774 source meshes / 1,073 joint batches plus three dynamic reins (the elbow update adds sixteen batches). Map totals last measured 13,554 sources / 616 batches plus cloth/atmosphere. Do not confuse historical counts in the development log with these current totals.

## Verification and packages

All seven final focused suites passed: `equipment_visuals rig_batching slash_contact locomotion preview_camera costumes combat_defeat`. The release pipeline also completed successfully: resource import, model catalog check, web export/packing, exported-resource smoke checks, macOS export and web archive packaging. The complete 70-suite default run was not repeated for this bounded geometry change.

Use:

```sh
GODOT_BIN=/private/tmp/ashen-godot/Godot.app/Contents/MacOS/Godot python3 scripts/test_local.py equipment_visuals rig_batching slash_contact locomotion preview_camera costumes combat_defeat
GODOT_BIN=/private/tmp/ashen-godot/Godot.app/Contents/MacOS/Godot scripts/build_local.sh
```

`build_local.sh` runs the full default suite. The final focused release used `/private/tmp/poem-export-verified.sh`, a temporary helper omitting the already-run test suite; it is not required for future work. Keep sources unchanged during a test/export pipeline. Test logs are `build/logs/<suite>.log`; temporary final-run logs are `/private/tmp/poem-elbow-final-tests.log` and `/private/tmp/poem-elbow-final-release.log`.

Local distributables: `/Users/alexr/Poem/build/native/Poem.zip`, `/Users/alexr/Poem/build/Poem-Web.zip`, and `/Users/alexr/Poem/build/web/`. They are generated and ignored by Git. Serve the extracted web build using the repository's local workflow; do not publish it.

## Outstanding review and useful next work

1. Assembled visual review, audio listening and browser FPS measurement remain outstanding. The user authorized local browser testing, but previous tool-level saved/managed denials blocked `http://127.0.0.1:8060`, Quaternius itch.io and native Codex access. Do not bypass those denials through another browser, raw CDP, alternate asset host, or headless assembled-game capture. If the approved surface becomes available, inspect actual map → combat → return flows first.
2. Compare complete presentation against the already-inspected Awakening/Fates references: readable map sprites on terrain, restrained camera motion, character silhouette/materials, pale stat rows and calm/Ablaze transitions. Prior geometry-only checks cannot establish visual fidelity.
3. The model catalog remains empty; combat characters are procedural. No downloaded authored characters are available. Do not claim otherwise.
4. The viewer replays individual actions; a continuous travel-preview loop was considered but not implemented. Only pursue if it helps inspect movement.
5. Consider whether the elbow mesh can share existing vertex formats to avoid sixteen additional batches, after measuring; do not sacrifice normals/outline correctness merely for a count.

Reference images previously inspected, if their temporary paths still exist: `/private/tmp/ashen-fates-hud-reference.png`, `/private/tmp/ashen-awakening-combat-reference.jpg`, `/private/tmp/poem-cavalier-reference.jpg`. Final isolated elbow study: `/private/tmp/poem-elbow-study.png` (software flat shading, not the actual game shader). References are not shipped Nintendo assets.

## Technical pitfalls

- GDScript helper assertions may print failure while a parent later prints PASS; use `scripts/test_local.py`, which scans errors and enforces a timeout.
- macOS `get_system_ca_certificates` error is the known exception; do not suppress other errors.
- Give standalone headless probes a writable `--log-file /private/tmp/...` and a timeout.
- Outline setup clones meshes; compare source vertices, not resource identity. Painted faces are intentionally excluded from rigid batching.
- Godot Compatibility does not implement built-in alpha hash; defeat copies use alpha blending and custom shaders use explicit coverage discard.
- Headless root windows may report 64×64; input tests set the logical 1440×900 root and send complete press/release sequences.
- Material-bound GradientTexture2D readback may become stale under the dummy renderer; see the indexed Marble observation before interpreting software studies.
- `clear_world()` and `reset_ui()` replace roots; reconnect watchers after setup. Await a frame before inspecting a newly-added configured actor.
- Stop audio and allow its shutdown drain before freeing game fixtures.
- Use exact promotion IDs from Rules, not guessed IDs.

Delivery procedure: stage explicit files, commit on the worktree branch, fast-forward the primary checkout, push `main` and `codex/combat-presentation`, then copy web/native packages into the primary checkout. Outside-root Git operations need the tool's escalation review, but the user's authorization is already present. Do not force-push or disturb the unrelated stash.
