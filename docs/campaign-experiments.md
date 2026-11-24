# Campaign experiments

These are independent switches on the new-campaign screen and in Options. Fresh settings start off; existing saves retain their chosen switches. Permadeath remains a separate toggle. Debug mode creates a temporary sandbox with a different save slot; disabling it restores the original live campaign. Use **Open debug tools** to load a chapter, make a selected ally fall, heal/revive units, or test the real retreat path.

Before **Begin the chronicle**, choose any combination of the seven experiment switches and permadeath. The screen starts with the current rule choices, including selections made in title Options. Editing this screen is a draft: cancelling changes no chosen rules or save file. Beginning creates a fresh company with those switches, clearing earlier casualties, credits, pressure and other consequences. The first deployment saves the selected configuration. Starting inside Debug still uses only its separate slot.

Debug opens with campaign controls first. The fixed **Campaign experiments** and **Character studies** buttons jump between sections and move keyboard focus to the first control. Model comparisons and rig previews remain available below the campaign tools.

Use **Save experiment checkpoint** to remember the current war council or battle position and chosen combat seed. **Restore experiment checkpoint** returns to that position so you can try another action, loadout or retreat. The saved point is reusable during the current Debug session. Each restore writes to the Debug slot and appears in the experiment report.

The casualty card names the effects earned by that loss. Legacy awards show the credit and any volunteer who joins. A sacrifice can show the company’s attack bonus and recovery on redeployment. A downed recruit keeps the rescue cue while their countdown is active.

The battle forecast shows what an ordinary hit sequence can do. **Downed if hits land** leaves a rescue opportunity. **Lost if hits land** marks an immediate permanent loss. **Defeat if hits land** warns that the fall can end the battle. A healed passenger can keep fighting after their carrier falls and releases them.

The debug seed control accepts whole numbers from 0 through 2147483647. **Apply seed to next rolls** changes the sandbox’s random stream immediately. Loading a chapter, clean-resetting a battle or reviving/resetting the company reuses that seed; ordinary penalty retreats follow the campaign’s restart rules. The same seed, settings and sequence of actions reproduce the same results.

**Test pressure and reset battle** accepts pressure 0–10, enables enemy preparation and rebuilds the current chapter using the selected seed. It keeps other trial switches and the consequence ledger. Load the chapter first, then choose pressure; a fresh-roster chapter load clears earlier consequences. The company experiment panel and debug report show the stat bonuses, held tonics and raider advance that will apply on the next deployment.

**Raise company and reset battle** raises currently available recruits to a chosen level, using ordinary growth and the selected combat seed. It never lowers a level, revives permanent losses, unlocks future recruits or removes a promotion. The section checkpoint remains unchanged, so a penalty retreat can still rewind this training. To start lower, load a chapter with a fresh roster; return to preparation to choose promotions once recruits reach level 10.

**Test selected ally falling** accepts only standing allies, so repeated testing cannot turn a permanent casualty back into a downed recruit. **Set rescue countdown** sets an uncarried downed ally to one or two remaining player-phase endings without advancing the turn or consuming RNG. Carried patients are paused and excluded. These actions use only the debug save slot.

**View experiment report** shows the chapter, phase and permadeath toggle, followed by fallen allies, patients awaiting rescue, carried allies, next-deployment recovery, reset pressure and credits. Carried patients are counted separately from those awaiting rescue; camp omits stale battle patient counts. The detailed JSON below records the rules, seed, current random state, casualties, pressure and combatants. It includes a transfer code to restore the exact position in another debug session; **Copy restore code** copies that code by itself. Viewing or copying the report does not change the simulation. Reports stay local unless you choose to share them.

**Choose an experiment setup** includes three positions that use the ordinary phase, result and battle-menu controls. With the default combat seed `472019`, **Enemies prepare after Lyra falls** starts Lyra at 1 HP on the bridge approach. End the phase and regroup after the defeat. **Retreat with a permanent loss** starts at Glass Harbor with Oren lost. The battle menu returns you to Kingsroad with his legacy credit intact. **Sacrifice & recovery** starts Oren exposed and the Ash guard wounded. End the phase, then move Sera to (4, 5) and attack the guard at (5, 6). Start that setup again and turn off **Sacrifice costs & openings** in Options to compare the forecast, shot outcome and Oren’s subsequent deployment.

With reset pressure enabled during a battle, the report shows the chapter, pressure and number of raiders that would advance after a retry. Choose **Compare enemies** to see each enemy’s tile, health, attack, speed, defense and held tonics at that destination. A changed field shows its pressure-zero value followed by the retry value. The copied report keeps both values under `retry_deployment`. The preview uses the rally point selected by the campaign rules.

**Choose an experiment setup → Last chance rescue** starts Oren downed with one player-phase ending left, Lyra beside him and Ivo already spent. Save an experiment checkpoint before acting. Select Lyra, then Oren, and choose **Rescue Oren** before ending the phase. After the enemies act, move Lyra west beside Ivo, select Ivo and use **Rescue & triage → Heal carried Oren**. The countdown stays paused while carried, and healing returns Oren with his action spent. Restore the experiment checkpoint and end the first phase to observe the committed loss from the same position and seed. Both branches use ordinary rules and the separate Debug slot. The original rescue tutorial remains available with everyone ready.

With a ready staff user selected, a carrier’s tile turns green when their passenger can be healed. Click the carrying badge above the carrier to open triage for that patient. **Heal carried** confirms the action. Escape returns to the map with the staff user still selected.

**Choose an experiment setup → Who answers the loss** places Ivo and Sera at Hallow Abbey with one phase ending left. Select Esme and heal Ivo to test Tovin’s arrival, or heal Sera to test Maelin’s arrival. Lyra can move beside the other patient and rescue them before the phase ends. Save an experiment checkpoint to try both choices from the same position and seed. Return to the war council to read the earned arrival scenes.

In Quick map battles, a lethal hit that leaves an ally at death’s door keeps their figure visible in the wounded pose and shows the countdown immediately. A fallen carrier’s carrying badge clears when the passenger is released. Ordinary defeated units still fade away.

## Starting positions

At the war council, choose **Positions** to arrange the selected company before deployment. Select two numbered tiles or list entries to swap them; empty starting tiles can be used too. The preview includes Hard reinforcements and any raider advance from reset pressure. Select a red marker or use the enemy chooser to inspect the prepared enemy’s portrait, equipment, health, effective stats and possible attack reach. Stationary guards show attacks from their own tile; mobile foes include reachable positions. Staff users show healing power and no attack overlay. Selecting a blue starting tile returns to swapping. **All enemy reach** or **R** adds pale red coverage for every prepared enemy while keeping an inspected foe’s reach darker. A **!** on a blue slot marks possible enemy attack reach, including empty starting tiles. These overlays update with the draft and reset when the planning screen closes. Preparing the draft does not advance the live campaign, countdowns or random stream. **Restore default positions** resets the draft; **Cancel** or Escape discards it; **Apply formation** keeps the positions and saves the camp.

Position choices carry forward to the next chapter’s numbered starting tiles. Removing or losing an ally leaves the surviving placements intact, and new selections fill free slots. Experiments that require Lyra still require her deployment, but she can use any starting tile. Old saves without a formation keep their previous placement; loading an active battle preserves its existing unit positions.

## Complete combat scene starters

In Debug tools, choose **Stage a combat encounter**. Eight starters cover sword, lance, bow, staff healing, axe, magic, duelist and mounted combat across village, river, abbey, harbor, mountain, observatory and furnace settings. The selected ally and marked target are already in range; press **Enter** to preview an attack and **Enter** again to confirm. Healing takes one Enter press. The initial tactical view stays clear of forecast portraits.

Each starter replaces the temporary Debug campaign. It uses fresh recruits, ordinary growth to at least level 3 or the chapter’s one-based number, standard equipment and the selected combat seed. Permadeath and the campaign experiments are off; action saves are on in the separate Debug slot. Repeating a starter reproduces the same position and random stream. Hits, criticals and victories are not forced. The original campaign is restored when Debug is disabled.

While in a Debug battle, **M → Combat encounters** opens the same list directly. Escape or its Return button goes back to the battle menu without changing the current position. The shortcut shares a row with Options and is absent from ordinary campaigns.

The encounter list offers **Original models** and **Revised models** buttons for all ally and enemy classes. Its status shows whether the sandbox uses the original, revised or mixed set. Debug tools also offers individual class switches. Both controls apply to the temporary Debug campaign. Use **Options → Presentation → All 3D battles** for the full scene, or Quick map mode to compare. The starters exercise the map zoom, chapter scenery, combat camera, health display, soundtrack transition and return through normal gameplay.

The full-company chooser also offers equipment choices for every compatible item, alongside normal equipment. Explicit choices place the target at the item’s maximum range: throwing spears at two tiles, Watchtower bows at three, and Beacon staves at two. The starter uses a chapter where both recruit and equipment are available, then equips the item through the ordinary rules. Its detail text shows the resulting chapter and distance before starting. Recruitment, promotion and equipment choices remain selected when returning to the chooser; changing recruit resets training and equipment. The original eight quick starters retain their normal equipment and placement.

Choose a battlefield to use that chapter’s tactical map, enemies, lighting and close-up scenery. All twelve chapters are listed; those before the recruit or equipment unlock are disabled. **Suggested battlefield** uses the original starter location, adjusted for unlocks. A selected chapter stays selected across model comparisons and compatible loadout changes. An incompatible recruit or item returns it to Suggested battlefield. The details show the training level before staging: chapter changes can alter stats and combat odds, so use the same chapter and seed when comparing models. Browsing the selector does not write a save or change the campaign; staging records the chosen chapter in Debug’s action history.

**Face the chapter commander** places an attacking recruit in weapon range of that battlefield’s named commander. The detail text names the opponent. Confirming the attack plays the normal first-encounter caption. Restaging starts a fresh sandbox encounter and plays the line again. The switch clears when selecting a staff user, so healing continues to target an injured ally.

## Current rules

| Switch | Behavior |
| --- | --- |
| Permadeath | Dead recruits remain unavailable after victory. Read support memories and memorial dossiers remain. Lyra falling loses the attempt. |
| Save every action | Movement, combat, healing, rescue/drop and phase changes save before their presentation. No movement undo. With permadeath, deaths commit during battle and survive retries. Saves include RNG and enemy action flags, so resuming an interrupted enemy phase does not repeat its resolved attacks. |
| Restart the current section | With permadeath on, defeat or a requested retreat returns to chapters 1, 5 or 9. Growth and chapter progress rewind to that section’s checkpoint; recorded casualties, legacy purchases, volunteers, injuries and pressure persist. Lyra must deploy. |
| Enemies prepare after resets | Works with either permadeath setting. Defeat/retreat raises pressure by one, capped at ten. Each pressure point adds 2 enemy HP and 1 power. Enemies begin with two held healing tonics, reduced by pressure, and can use remaining tonics when badly hurt. Non-boss Corsairs and Rangers take a free movement action before the retry. Lyra must deploy and her death ends the attempt. Reloading an in-progress save resumes it without an additional penalty. |
| Death’s door & rescue | A lethal hit downs an ally for two player-phase endings. They occupy their tile but cannot act, counter or be attacked. A clickable map badge shows the remaining two or one player-phase endings. Any ally on the same or an adjacent tile can rescue them, consuming an action. With a ready non-staff ally selected, click the adjacent downed unit to open their rescue choice and countdown; returning to battle preserves your move. Staff clicks retain direct healing. Carrying pauses bleeding and costs 2 movement. A persistent badge identifies the carrier. Rescue/drop have short skippable map feedback after their action checkpoint. Drop consumes an action and needs a free adjacent tile. Choose **Rescue & triage → Choose drop tile**, then click a gold tile or use arrows/Enter. Escape or right-click cancels the drop choice without undoing the carrier’s movement. Staff healing revives a downed ally with their action spent; a carried healed ally is placed on a free adjacent tile if possible, otherwise remains carried until dropped. Victory evacuates downed allies. A downed unit dropped onto a seize objective cannot secure it; healing them to positive HP can. If nobody can act, the attempt is lost. |
| Harder enemy forces | At deployment, enemies gain `6 + chapter index` HP, `2 + floor(chapter index / 2)` power, `1 + floor(chapter index / 4)` speed and `floor(chapter index / 3)` defense. This combines with reset pressure. Fresh deployments in chapters 5, 9 and 12 also add one Field Warden who heals injured enemies. |
| Death events & legacy supplies | With permadeath, each non-lord death commits immediately and grants one legacy credit, once per recruit. The first loss can bring Faye early; the third can bring Noor early. The first permanent Warden loss enlists Maelin, and the first permanent Ranger loss enlists Tovin. They can deploy from the next war council, where their arrival scenes enter Company memories. The war council’s experiment panel offers early shared equipment access: tempered sword (1 credit/1 loss), war hammer (2/2), Watchtower bow (3/3), Rally lance (2/2) and Vigil staff (2/2). Purchased stock cannot be bought repeatedly. Once an item reaches its normal chapter unlock, it says “Available in arsenal” and cannot consume credits. Purchases and enlistments persist through section restarts. |
| Sacrifice costs & openings | The first terminal fall per recruit in a chapter grants surviving allies +2 attack through the next player turn. If they return, they start attempts through the following chapter with 4 HP missing and one tonic instead of two. Base maximum HP and permanent growth are unchanged. Healing can restore the missing health. This works with either permadeath setting. |

The Rally lance and Vigil staff keep early-access choices available into later sections. The lance unlocks normally in chapter 10: compared with the Gatekeeper pike, it trades one might for 15 accuracy and two less weight. Effective speed still has a zero floor. The staff unlocks in chapter 11 and heals 16 HP at one or two tiles, six more than the Beacon staff, but weighs three more. Promotion healing bonuses apply normally. Each early legacy purchase costs two credits after at least two permanent losses; either item is freely available at its normal chapter without casualties. Purchases survive section rewinds and remain usable if the legacy switch is disabled. The arsenal's equipped summary shows healing power for staves. Alternative items preview actual attack or healing and effective speed with signed changes from the equipped item, including promotion bonuses and the zero-speed floor. Locked items can be compared without unlocking or equipping them. These are experimental choices, not a claim that loss rewards are balanced.

Hard support is announced in the camp briefing. Field Wardens use the same healing rules and staff presentation as allied healers, gain no experience, and cannot attack. Inspection shows their healing power and intent; enemy danger overlays still represent attacks. Existing version-6 battle saves retain their exact formation when loaded. Changing the switch affects the next deployment, without inserting or removing units from a live battle.

A paired nine-run heuristic survey compared three seeds across ordinary, hard recovery and committed-section campaigns. Ordinary runs matched exactly. New Wardens performed 22 healing actions; the number of completed campaigns stayed the same, while casualties increased in some runs and decreased in others. This demonstrates support behavior and tactical variation, not a uniformly harder campaign or human balance approval.

The war council marks recovering recruits and previews their actual starting HP; their dossier explains the reduced tonic supply. These previews use the same rules as deployment and disappear when the cost expires or its switch is disabled.

Gold target tiles identify adjacent allies a selected non-staff unit can rescue; staff targets remain green. The end-phase button warns how many uncarried allies will bleed out, with their names on hover. Carrying or healing them clears the warning. No extra confirmation is added.

If a carrier falls with no free adjacent tile, both allies remain at that position. A two-person badge opens a chooser with each ally's health or bleed-out countdown. Escape or **Return to battle** keeps the current selection and movement. Standing allies take precedence for ordinary tile occupancy; the chooser still reaches the patient underneath. The first revival can stand at the shared position. If another ally is already standing there, a second revival needs a free adjacent tile and appears there with its action spent. If no tile is free, healing consumes nothing; rescue remains available, including from the same tile. A healed carried ally can still remain safely carried until a drop is possible. Triage explains a blocked revival and offers reachable revival actions alongside rescue.

Selected units show carrying, recovery and active sacrifice openings in one compact status line. Hover it for the effective carrying movement, bonus duration and recovery explanation.

Staff revival now identifies the recovery at the moment the healing light arrives: **REVIVED · ACTION SPENT** in a close-up, or **Revived · +HP** in quick map feedback. The recovered ally still waits until their next action, including when surrounded and safely remaining carried. Ordinary healing keeps its existing health-only feedback. Skipping does not change the already committed recovery.

Casualty portrait cards distinguish needing rescue, withdrawing and permanent loss. Every recruit has original lines. Lyra receives a withdrawal line. Cards follow both full and quick battles, including bleed-outs, and can be skipped with a click or Tab.

At section breaks, the relief-column event brings recruits scheduled for that chapter and the following chapter to the rally point. Thirty-nine original lines cover relief arrivals, volunteers, retreats and section memorials. These scenes play once at camp, persist across section restarts and can be replayed as named company memories. With death legacies enabled, the first permanent loss in each section earns its memorial. A final-battle memorial plays before the epilogue. Completed campaigns retain an archive whose return controls lead back to the epilogue. Retreats describe the regent retaking the road while survivors withdraw to a rally point. Chapter dialogue adapts to permanent losses as described below.

Each memorial names the recruits whose permanent losses earned legacy credits in that section. Replay from **Company memories** includes names added after the first reading. The roll uses the existing ledger and stays available after a retreat or save transfer.

A toggle change applies immediately where possible. Enemy difficulty and returning-unit supplies apply when deploying the next attempt. Disabling a switch does not erase already committed deaths, purchases or pressure. Debug tools can intentionally bypass consequences for inspection: **Reset current battle** is a clean rebuild; **Test reset / section retreat** exercises the actual penalty path.

## Story after permanent losses

Opening and closing scenes preserve mission information even when their original speaker has died. Personal exchanges also check the companions they address: for example, a lost Oren receives a short memorial after the first battle instead of Lyra telling him he can go home. The campaign contains 59 authored alternate lines; all 103 original lines and their order remain when their participants survive.

Closing scenes include casualties from the current battle before chapter progression records them. Downed allies who can be evacuated and ordinary knockouts with permadeath off keep their original conversations. Section restarts retain dialogue appropriate to committed losses. Previously read support conversations remain replayable memories with their original speakers. Resolution changes no campaign resources, saved story flags or RNG.

Authoring uses optional `requires` companion IDs on a line and an ordered `when_absent` list of alternatives. A line needs its speaker and required companions alive; otherwise the first available alternative is used, or the line is omitted. Alternatives carry mission reports or a rewritten response rather than silently handing a dead character’s personal history to someone else. All 180 relevant loss combinations retain a scene, and the actual original/alternate lines fit the dialogue panel at three supported sizes.

## Save recovery and limits

When a named commander first fights your company, the game records the line as seen with the resolved action. **Save every action** commits both before the caption appears. An interrupted reload keeps the line seen and the attack resolved. A section retreat restores the story flags from the section checkpoint, so commanders can speak when you reach them again. Debug records stay in the sandbox save.

Saves use an increasing sequence number. Loading selects the newest validated primary, recovery or completed temporary checkpoint. With action saving enabled, both the primary and recovery files contain the current checkpoint; recovery cannot silently rewind to the previous action. A failed checkpoint displays a warning and blocks further player actions until saving succeeds. An interrupted enemy phase resumes only enemies that have not acted. A decisive enemy exchange ends without incrementing the turn or applying next-phase terrain healing. Result screens offer a transfer code for the current outcome and a save retry if needed; action-save failures also block retreat or retry until the checkpoint can be written.

Browser builds also write and read back one localStorage recovery record per save slot before reporting success. Loading compares that record with the filesystem checkpoints, including when the filesystem has no campaign yet. This covers a reload while the engine's asynchronous IndexedDB flush is pending. The normal and debug records remain separate. If browser storage rejects a write or its read-back check, saving reports failure; use a transfer code to keep the current position. This path is covered by JavaScript storage doubles and headless recovery/failure tests; actual browser reload verification remains outstanding.

The extra record uses the public [Web Storage API](https://developer.mozilla.org/en-US/docs/Web/API/Storage/setItem) through [JavaScriptBridge](https://docs.godotengine.org/en/4.5/classes/class_javascriptbridge.html). It avoids depending on Godot's private filesystem internals. [Godot 4.5.1's implementation](https://github.com/godotengine/godot/blob/4.5.1-stable/platform/web/js/libs/library_godot_os.js) performs the filesystem sync asynchronously without returning storage errors to the game script. Browser data clearing, private-session disposal, storage eviction and device failure can still remove local saves; keep transfer-code backups for long experiments.

This is a local experimentation harness, not tamper-resistant ironman enforcement. Players can deliberately change toggles, use debug tools, or import an older exported save. An external process killing the game before a resolved action can finish writing is outside the guarantee. No server-side authority is involved.

With section restarts and permadeath enabled, the route map marks reached section starts with diamonds and identifies the current retreat point. Selecting a historical chapter shows its own four-chapter section without moving the current rally point or exposing future briefings. The section aids disappear when either switch is off.

Before retreating, the battle menu and defeat screen show the destination chapter, next pressure level, enemy bonuses, held tonics and raider preparation. The preview includes section rewinds and caps pressure at 10. Viewing it does not advance pressure, consume RNG or change the save.

## Matched experiment comparison

Run the bounded nine-configuration comparison with the project’s Godot binary:

```sh
GODOT_BIN=godot python3 scripts/benchmark_experiments.py
```

The default driver records 45 runs (nine configurations × five matching seeds), including failed campaigns, in `build/review/matched-experiments.json`. Use `--output path/to/result.json` for a separate record. It captures the source revision, whether the checkout was dirty, rules-file hashes and engine output. Script failures stop the run; a campaign losing within its two-retry limit is retained as a valid result. No player saves are accessed.

Repeat `--profile` and `--seed` to select a smaller matched comparison. Add `--equip ITEM_ID` for up to one preferred item per weapon kind. During preparation, compatible recruits switch only once the item is normally unlocked or purchased through the existing legacy rules. Before then they retain their current equipment. The report records each actual change and every deployed recruit's item. This is an explicit loadout experiment, not an optimal-equipment strategy; legacy purchases still follow their fixed stock order, which can spend credits before a requested item is affordable.

```sh
GODOT_BIN=godot python3 scripts/benchmark_experiments.py \
  --profile ordinary --profile hard_legacy --profile hard_committed \
  --seed 309 --seed 17 --equip rally_lance --equip vigil_staff \
  --output build/review/late-supply-comparison.json
```

For a matched baseline, run the same profiles and seeds without `--equip`, using a different output path. Invalid IDs, repeated profiles/seeds and conflicting items of the same weapon kind are rejected before starting the engine. Seeds from 0 through 2^63 − 1 retain their exact integer value. Existing completed comparison records are historical evidence; use separate output paths to preserve them.

### Carrying patients

Use `--carry-patients` to give the benchmark planners a rescue strategy in profiles with death’s door. An ally can spend their action picking up a patient who is about to bleed out when no ready healer can reach them. Carriers try to reach healing range while avoiding exposed tiles. Each battle records rescues, revivals, phase endings with a paused countdown, and bleed-outs, with the units involved and the turn of each event.

```sh
GODOT_BIN=godot python3 scripts/benchmark_experiments.py \
  --profile hard_death_door --output build/review/death-door-baseline.json
GODOT_BIN=godot python3 scripts/benchmark_experiments.py \
  --profile hard_death_door --carry-patients --output build/review/death-door-carrying.json
```

Both strategies reached the ending on all five fixed seeds. The carrying strategy performed four rescues, three carried revivals, and held the countdown through three player-phase endings. Permanent losses fell by one on seeds 472019, 17, and 8675309. Seed 2026 finished with no losses and seed 309 with 23 in both runs. The sample measures the behavior of these two planners under the same seeds.

### Earlier comparison

At source `338e125b4584d1198818eec8b66c5b26055f6bd3`, ordinary recovery, Hard recovery, Hard recovery with sacrifice costs and Hard permadeath with death’s door each completed all five seeds. Hard permadeath alone, with legacies, with section relief, with reset pressure, and with all three each completed four. Death’s door reduced the completed-campaign median permanent losses from 19.5 to 1, but one seed still ended with 23 losses. These small deterministic samples do not establish human win rates or fair difficulty.

All 48 chapter outcomes, turn counts and terminal-fall lists for the four matching seed-472019 runs agree with the separate actual app campaigns. The comparison itself runs only Rules and the existing tactical planner: default equipment, earned promotions/supports, no carrying strategy and no disk/UI verification. Eligible legacy purchases are recorded but not equipped. Reset pressure also changes the first deployment by supplying two enemy tonics and requiring Lyra, so its toggle is not an isolated stat-scaling comparison. No balance values changed in response to this survey.

### Later-section app continuity

At source `e653e32bdf3f4f71007db124c2d0f56c7a8c444d`, a targeted campaign started through the new rule controls with permadeath, action saving, Hard forces, section restarts, reset pressure and death legacies enabled. It used seed 309 because the earlier survey reached the ending with few losses, increasing the chance of reaching both later-section checks. This selection is not a representative balance sample.

The actual battle-menu retreats from chapters 6 to 5 and 10 to 9 preserved the casualty/supply ledger and restored surviving roster records from their section-start checkpoints. A natural lord defeat during the replayed chapter 5 exercised an additional result-screen retry. Pressure reached 3. All eight rule values stayed intact through 996 exact save comparisons; 470 legal player actions completed 15 played attempts over 107 turns. The ending retained 17 permanent losses and seven available recruits. The two voluntary retreats happened before acting and are recorded separately from those played attempts.

The first five chapter outcomes, turn counts and casualty lists matched the earlier no-retreat rules run. Later growth and outcomes changed after the actual rewinds and pressure increases. Twelve promotions and six support conversations are event counts, including possible repetition after rewinds. Dialogue and announcements were dismissed through their normal input paths. This is headless app integration, with no forced wins or losses, and does not establish rendered quality, physical input, browser behavior or human difficulty.

## Initial balance measurements

The optional [automated probe](../scripts/benchmark_trials.gd) runs three seeds with permadeath off and on, hard forces, sacrifice costs, action saving and the first promotion branch. It uses legal tactical actions and no reset-pressure bonuses. On November 4, 2026, all six runs cleared twelve chapters:

| Seed | Permadeath off: total turns | Permadeath on: total turns |
| --- | ---: | ---: |
| 472019 | 75 | 80 |
| 17 | 72 | 81 |
| 309 | 81 | 86 |

The third permadeath run ended with two standing allies in its final six chapters. These results show greater attrition and longer fights than the baseline campaign, not that the difficulty is fair for a person. Rescue decisions, repeated-reset escalation, legacy purchases and alternate deployments need playtesting. The ordinary campaign regression remains separate so tuning the experiment cannot silently change its default rules.

Run the probe with the project’s Godot binary:

```sh
godot --headless --path . --script scripts/benchmark_trials.gd
```

### Death’s-door probe

On November 5, 2026, the same six hard-campaign runs were repeated with death’s door enabled. The planner now recognizes downed and carried patients, prioritizes imminent bleed-outs, and approaches patients outside staff range. Planning does not mutate the battle or consume random rolls. All six runs cleared twelve chapters:

| Seed | Permadeath | Total turns | Staff revivals | Terminal losses |
| --- | --- | ---: | ---: | ---: |
| 472019 | Off | 71 | 6 | 0 |
| 472019 | On | 71 | 6 | 0 |
| 17 | Off | 74 | 17 | 1 |
| 17 | On | 76 | 22 | 2 |
| 309 | Off | 78 | 28 | 4 |
| 309 | On | 86 | 4 | 22 |

A revival is a successful staff action that returns a downed unit to positive HP; repeated revivals count separately. Terminal losses count defeat episodes across chapters, so returning units can be counted again with permadeath off. Victory evacuation is not counted as a staff revival. The large difference between the two seed-309 runs is evidence that attrition remains sensitive to campaign state. The planner still does not choose carrying/dropping actions, so these runs measure staff recovery rather than the full rescue strategy. They do not establish human fairness or visual quality.

```sh
godot --headless --log-file /tmp/poem-rescue-probe.log --path . --script scripts/benchmark_trials.gd -- --death-door
```
