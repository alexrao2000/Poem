# Poem — development handoff

Resumed at the user's request on 2026-11-04. Continue development in this chat until the user asks to stop. No scheduled work is requested.

## Resume here

Read this file, the current `DEVELOPMENT.md` checkpoint, and the latest sections of `docs/art-direction.md`. Run the user's Marble sync and read its three indexes as instructed in AGENTS.md. Check Git status before editing; preserve unrelated changes. Resume improving resemblance to Awakening/Fates, with particular attention to complete scenes and animation rather than accumulating isolated geometry details.

The campaign experiments are implemented as independent switches with save version 6: action checkpoints, death’s door/rescue, four-chapter section restarts, escalating enemy preparation, harder forces, death legacies/early volunteers and sacrifice costs/openings. Debug uses an isolated slot, reproducible seeds, pressure controls and restorable reports. Twenty-two relief/retreat/volunteer lines accompany the ledger. See [the experiment guide](docs/campaign-experiments.md) for exact rules and limitations.

Latest delivered source and local packages are at `75a9931` on the primary checkout and both remote branches. That includes browser localStorage recovery beside Godot's asynchronous filesystem saves, journal-only Continue, clickable rescue countdowns, pre-growth healer HP, compact condition inspection, preparation previews and exact terminal enemy-phase checkpoints. Failed action saves block retreat/retry; results offer save retry and live transfer codes.

Recent delivered work includes 24-recruit casualty portrait cards, prompt failure detection in the Godot test runner, downed staff targets, campaign-relative loss validation, debug company training through ordinary growth, deployment recovery previews, gold map drop targets, and focused map-click rescue choices. The healer planner now treats downed/carried allies and approaches distant patients. Its 72 ordinary chapter victories pass; six hard death’s-door runs also clear, with 4–28 staff revivals and 0–22 terminal losses. Detailed measurements and planner limits are in the experiment guide. These changes are synced to the primary checkout, both remote branches and local packages.

Rescue/drop map transitions and a persistent clickable carrier badge are delivered. Actions checkpoint before feedback; Tab skips motion without changing the resolved outcome. Narrow/wide layouts, actual travel/fade/cue behavior, private opacity ownership, save ordering and unchanged RNG/state pass, as do recruit visuals and quick-map exchange regressions. Both exports, packaged carrier-resource smoke and ZIP integrity pass (`/private/tmp/poem-rescue-feedback-export.log`). Sources and local packages are synced.

Current work fixes downed passengers seizing objectives and adds visible retreat previews. All four seize maps reject downed drops and reloads with permadeath on/off; staff revival secures the tile. Eighteen restart previews match actual destination/capped pressure/hard bonuses. Battle-menu and defeat layouts pass at three sizes. Logs: `/private/tmp/poem-downed-objective-tests.log`, `/private/tmp/poem-retreat-preview-tests.log`, `/private/tmp/poem-retreat-preview-final.log`. Both exports, packaged-resource smoke and ZIP integrity pass (`/private/tmp/poem-retreat-preview-export.log`).

The default runner has 76 suites. Recent package logs include `/private/tmp/poem-focused-rescue-export.log` and `/private/tmp/poem-rescue-planner-export.log`; both browser/macOS exports, packaged-resource smoke and ZIP integrity pass. Current assembled visual/audio review and actual browser reload verification remain blocked; do not claim them.

The earlier 72-suite full run stopped at an outdated presentation assertion that treated compact stat-strip labels as HP labels. That check and an Options camera-reset regression were fixed and their focused suites passed. A later full run reached healing, which exposed save sequence metadata leaking into simulation snapshots. Save revisions now exist only in on-disk records; healing, action checkpoints, debug, saves and transfers pass after that correction. Do not describe either interrupted run as a full pass.

The earlier elbow change replaces spherical metal elbows on armored outfits with closed, faceted elbow guards and continues cloth across unarmored elbows. It preserves joints and animation sockets. `scripts/elbow_guard.gd` owns the shared 120-triangle mesh; `scripts/fighters.gd` chooses the covering; `tests/test_equipment_visuals.gd` verifies topology, normals, UVs, armor classification and cloth tint. Explicit face normals fixed the initial smoothed-normal test failure. A standalone eight-panel original geometry study was inspected. This is not a rendered-game review.

Prior completed work includes five class cloak cuts and exposed ranger quivers, enemy/commander camera headroom, repeatable outfit-viewer actions, pale damage/hit/critical rows with immutable pre-exchange forecasts, shaped horse head/body/neck, world-planted infantry/cavalry movement, and a descending arena entrance.

## Project and authorization

- Working title: **Poem**. Godot 4.5.1 / GDScript, local browser and macOS builds.
- Active worktree: `/Users/alexr/.codex/worktrees/combat-presentation/fe-clone`, branch `codex/combat-presentation`.
- Primary checkout: `/Users/alexr/Poem`, branch `main`.
- Public remote: https://github.com/alexrao2000/Poem . The user explicitly authorized keeping it public and pushing on 2026-11-04. Nondestructive commits/pushes are authorized.
- Keep game local. No Sites/Vercel/public hosting, purchases or schedules.
- Preserve primary stash `Preserve shared workshop edits before combined presentation integration`.
- No subagents unless subsequently authorized by applicable instructions.
- Use `open -g` for launching applications; preserve focus.

The campaign has 24 recruits, eight classes, twelve chapters, sixteen promotions and 36 supports. The default test runner has 76 suites. Current rigid roster count is 1,774 source meshes / 1,057 joint batches plus three dynamic reins (the elbow guards now share the existing armor vertex format). Map totals last measured 13,554 sources / 616 batches plus cloth/atmosphere. Do not confuse historical counts in the development log with these current totals.

## Verification and packages

The previous 75-suite baseline has passing output in `build/logs/`. The final full attempt reached `combat_stats`; its numeric representation mismatch was corrected, and 27 affected/remaining suites then passed. The existing snapshot now retains its original numeric values; the save round-trip test compares parsed numeric results. A healer can also treat their own carried ally on the next action.

Final logs: `/private/tmp/poem-experiments-release.log` (partial full run), `/private/tmp/poem-experiments-remainder.log` (27 passing suites), and `/private/tmp/poem-experiments-export.log` (resource import/catalog, web/PCK smoke, native export and packaging). Both zip archives pass integrity checks. Godot cannot save its unrelated editor preferences outside the sandbox; this did not prevent imports or exports. The optional hard-campaign probe cleared six twelve-chapter campaigns across three seeds; these are automated measurements, not human playtesting.

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
4. The viewer now includes a continuous Run / trot action using the combat gait. Six focused suites verify full outfit framing, input/cancellation, authored clips and movement.
5. The elbow format correction is complete: topology/normals and animated rig equivalence pass, restoring 1,057 batches.

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
