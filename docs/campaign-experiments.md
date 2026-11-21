# Campaign experiments

These are independent switches on the new-campaign screen and in Options. Fresh settings start off; existing saves retain their chosen switches. Permadeath remains a separate toggle. Debug mode creates a temporary sandbox with a different save slot; disabling it restores the original live campaign. Use **Open debug tools** to load a chapter, make a selected ally fall, heal/revive units, or test the real retreat path.

Before **Begin the chronicle**, choose any combination of the seven experiment switches and permadeath. The screen starts with the current rule choices, including selections made in title Options. Editing this screen is a draft: cancelling changes no chosen rules or save file. Beginning creates a fresh company with those switches, clearing earlier casualties, credits, pressure and other consequences. The first deployment saves the selected configuration. Starting inside Debug still uses only its separate slot.

Debug opens with campaign controls first. The fixed **Campaign experiments** and **Character studies** buttons jump between sections and move keyboard focus to the first control. Model comparisons and rig previews remain available below the campaign tools.

The debug seed control accepts whole numbers from 0 through 2147483647. **Apply seed to next rolls** changes the sandbox’s random stream immediately. Loading a chapter, clean-resetting a battle or reviving/resetting the company reuses that seed; ordinary penalty retreats follow the campaign’s restart rules. The same seed, settings and sequence of actions reproduce the same results.

**Test pressure and reset battle** accepts pressure 0–10, enables enemy preparation and rebuilds the current chapter using the selected seed. It keeps other trial switches and the consequence ledger. Load the chapter first, then choose pressure; a fresh-roster chapter load clears earlier consequences. The company experiment panel and debug report show the stat bonuses, held tonics and raider advance that will apply on the next deployment.

**Raise company and reset battle** raises currently available recruits to a chosen level, using ordinary growth and the selected combat seed. It never lowers a level, revives permanent losses, unlocks future recruits or removes a promotion. The section checkpoint remains unchanged, so a penalty retreat can still rewind this training. To start lower, load a chapter with a fresh roster; return to preparation to choose promotions once recruits reach level 10.

**Test selected ally falling** accepts only standing allies, so repeated testing cannot turn a permanent casualty back into a downed recruit. **Set rescue countdown** sets an uncarried downed ally to one or two remaining player-phase endings without advancing the turn or consuming RNG. Carried patients are paused and excluded. These actions use only the debug save slot.

**View experiment report** shows the chapter, phase and permadeath toggle, followed by fallen allies, patients awaiting rescue, carried allies, next-deployment recovery, reset pressure and credits. Carried patients are counted separately from those awaiting rescue; camp omits stale battle patient counts. The detailed JSON below records the rules, seed, current random state, casualties, pressure and combatants. It includes a transfer code to restore the exact position in another debug session; **Copy restore code** copies that code by itself. Viewing or copying the report does not change the simulation. Reports stay local unless you choose to share them.

## Complete combat scene starters

In Debug tools, choose **Stage a combat encounter**. Eight starters cover sword, lance, bow, staff healing, axe, magic, duelist and mounted combat across village, river, abbey, harbor, mountain, observatory and furnace settings. The selected ally and marked target are already in range; press **Enter** to preview an attack and **Enter** again to confirm. Healing takes one Enter press. The initial tactical view stays clear of forecast portraits.

Each starter replaces the temporary Debug campaign. It uses fresh recruits, ordinary growth to at least level 3 or the chapter’s one-based number, standard equipment and the selected combat seed. Permadeath and the campaign experiments are off; action saves are on in the separate Debug slot. Repeating a starter reproduces the same position and random stream. Hits, criticals and victories are not forced. The original campaign is restored when Debug is disabled.

While in a Debug battle, **M → Combat encounters** opens the same list directly. Escape or its Return button goes back to the battle menu without changing the current position. The shortcut shares a row with Options and is absent from ordinary campaigns.

The encounter list offers **Current roster** and **Revised models · preview** buttons for all ally and enemy classes in this Debug sandbox. Its status distinguishes current, revised and mixed class choices; individual switches remain in Debug tools. These choices do not write saves, alter campaign/RNG state or change the ordinary campaign’s device preference. Use **Options → Presentation → All 3D battles** for the full scene. Quick map mode stays available for comparison. The starters exercise the map zoom, chapter scenery, combat camera, health display, soundtrack transition and return through normal gameplay.

The full-company chooser also offers equipment choices for every compatible item, alongside normal equipment. Explicit choices place the target at the item’s maximum range: throwing spears at two tiles, Watchtower bows at three, and Beacon staves at two. The starter uses a chapter where both recruit and equipment are available, then equips the item through the ordinary rules. Its detail text shows the resulting chapter and distance before starting. Recruitment, promotion and equipment choices remain selected when returning to the chooser; changing recruit resets training and equipment. The original eight quick starters retain their normal equipment and placement.

## Current rules

| Switch | Behavior |
| --- | --- |
| Permadeath | Dead recruits remain unavailable after victory. Read support memories and memorial dossiers remain. Lyra falling loses the attempt. |
| Save every action | Movement, combat, healing, rescue/drop and phase changes save before their presentation. No movement undo. With permadeath, deaths commit during battle and survive retries. Saves include RNG and enemy action flags, so resuming an interrupted enemy phase does not repeat its resolved attacks. |
| Restart the current section | With permadeath on, defeat or a requested retreat returns to chapters 1, 5 or 9. Growth and chapter progress rewind to that section’s checkpoint; recorded casualties, legacy purchases, volunteers, injuries and pressure persist. Lyra must deploy. |
| Enemies prepare after resets | Works with either permadeath setting. Defeat/retreat raises pressure by one, capped at ten. Each pressure point adds 2 enemy HP and 1 power. Enemies begin with two held healing tonics, reduced by pressure, and can use remaining tonics when badly hurt. Non-boss Corsairs and Rangers take a free movement action before the retry. Lyra must deploy and her death ends the attempt. Reloading an in-progress save resumes it without an additional penalty. |
| Death’s door & rescue | A lethal hit downs an ally for two player-phase endings. They occupy their tile but cannot act, counter or be attacked. A clickable map badge shows the remaining two or one player-phase endings. Any ally on the same or an adjacent tile can rescue them, consuming an action. With a ready non-staff ally selected, click the adjacent downed unit to open their rescue choice and countdown; returning to battle preserves your move. Staff clicks retain direct healing. Carrying pauses bleeding and costs 2 movement. A persistent badge identifies the carrier. Rescue/drop have short skippable map feedback after their action checkpoint. Drop consumes an action and needs a free adjacent tile. Choose **Rescue & triage → Choose drop tile**, then click a gold tile or use arrows/Enter. Escape or right-click cancels the drop choice without undoing the carrier’s movement. Staff healing revives a downed ally with their action spent; a carried healed ally is placed on a free adjacent tile if possible, otherwise remains carried until dropped. Victory evacuates downed allies. A downed unit dropped onto a seize objective cannot secure it; healing them to positive HP can. If nobody can act, the attempt is lost. |
| Harder enemy forces | At deployment, enemies gain `6 + chapter index` HP, `2 + floor(chapter index / 2)` power, `1 + floor(chapter index / 4)` speed and `floor(chapter index / 3)` defense. This combines with reset pressure. Fresh deployments in chapters 5, 9 and 12 also add one Field Warden who heals injured enemies. |
| Death events & legacy supplies | With permadeath, each non-lord death commits immediately and grants one legacy credit, once per recruit. The first loss can bring Faye early; the third can bring Noor early. The war council’s experiment panel offers early shared access to a tempered sword (1 credit/1 loss), war hammer (2/2) and longbow (3/3). Purchased stock cannot be bought repeatedly. Once an item reaches its normal chapter unlock, it says “Available in arsenal” and cannot consume credits. Earlier purchases remain secured through section restarts. These use existing recruits and equipment; they are not additional roster/art assets. |
| Sacrifice costs & openings | The first terminal fall per recruit in a chapter grants surviving allies +2 attack through the next player turn. If they return, they start attempts through the following chapter with 4 HP missing and one tonic instead of two. Base maximum HP and permanent growth are unchanged. Healing can restore the missing health. This works with either permadeath setting. |

Hard support is announced in the camp briefing. Field Wardens use the same healing rules and staff presentation as allied healers, gain no experience, and cannot attack. Inspection shows their healing power and intent; enemy danger overlays still represent attacks. Existing version-6 battle saves retain their exact formation when loaded. Changing the switch affects the next deployment, without inserting or removing units from a live battle.

A paired nine-run heuristic survey compared three seeds across ordinary, hard recovery and committed-section campaigns. Ordinary runs matched exactly. New Wardens performed 22 healing actions; the number of completed campaigns stayed the same, while casualties increased in some runs and decreased in others. This demonstrates support behavior and tactical variation, not a uniformly harder campaign or human balance approval.

The war council marks recovering recruits and previews their actual starting HP; their dossier explains the reduced tonic supply. These previews use the same rules as deployment and disappear when the cost expires or its switch is disabled.

Gold target tiles identify adjacent allies a selected non-staff unit can rescue; staff targets remain green. The end-phase button warns how many uncarried allies will bleed out, with their names on hover. Carrying or healing them clears the warning. No extra confirmation is added.

If a carrier falls with no free adjacent tile, both allies remain at that position. A two-person badge opens a chooser with each ally's health or bleed-out countdown. Escape or **Return to battle** keeps the current selection and movement. Standing allies take precedence for ordinary tile occupancy; the chooser still reaches the patient underneath. The first revival can stand at the shared position. If another ally is already standing there, a second revival needs a free adjacent tile and appears there with its action spent. If no tile is free, healing consumes nothing; rescue remains available, including from the same tile. A healed carried ally can still remain safely carried until a drop is possible. Triage explains a blocked revival and offers reachable revival actions alongside rescue.

Selected units show carrying, recovery and active sacrifice openings in one compact status line. Hover it for the effective carrying movement, bonus duration and recovery explanation.

Staff revival now identifies the recovery at the moment the healing light arrives: **REVIVED · ACTION SPENT** in a close-up, or **Revived · +HP** in quick map feedback. The recovered ally still waits until their next action, including when surrounded and safely remaining carried. Ordinary healing keeps its existing health-only feedback. Skipping does not change the already committed recovery.

Casualty portrait cards distinguish needing rescue, withdrawing and permanent loss. All 24 recruits have original lines; Lyra withdraws rather than receiving a permanent-death line. Cards follow both full and quick battles, including bleed-outs, and can be skipped with a click or Tab. They do not change the resolved action or its checkpoint.

At section breaks, the relief-column event brings recruits scheduled for that chapter and the following chapter to the rally point. Thirty-one original lines cover relief arrivals, early volunteers, retreats and section memorials. These scenes play once at camp, persist across section restarts and can be replayed as named company memories. With death legacies enabled, the first permanent loss in each section earns its memorial; downed or returning allies do not. A final-battle memorial plays before the epilogue. Completed campaigns retain an archive whose return controls lead back to the epilogue, without reopening preparation or purchases. Retreats describe the regent retaking the road while survivors withdraw to a rally point. Chapter dialogue now adapts to permanent losses as described below; a fuller branching story and bespoke death-triggered recruits are still future content work.

A toggle change applies immediately where possible. Enemy difficulty and returning-unit supplies apply when deploying the next attempt. Disabling a switch does not erase already committed deaths, purchases or pressure. Debug tools can intentionally bypass consequences for inspection: **Reset current battle** is a clean rebuild; **Test reset / section retreat** exercises the actual penalty path.

## Story after permanent losses

Opening and closing scenes preserve mission information even when their original speaker has died. Personal exchanges also check the companions they address: for example, a lost Oren receives a short memorial after the first battle instead of Lyra telling him he can go home. The campaign contains 59 authored alternate lines; all 103 original lines and their order remain when their participants survive.

Closing scenes include casualties from the current battle before chapter progression records them. Downed allies who can be evacuated and ordinary knockouts with permadeath off keep their original conversations. Section restarts retain dialogue appropriate to committed losses. Previously read support conversations remain replayable memories with their original speakers. Resolution changes no campaign resources, saved story flags or RNG.

Authoring uses optional `requires` companion IDs on a line and an ordered `when_absent` list of alternatives. A line needs its speaker and required companions alive; otherwise the first available alternative is used, or the line is omitted. Alternatives carry mission reports or a rewritten response rather than silently handing a dead character’s personal history to someone else. All 180 relevant loss combinations retain a scene, and the actual original/alternate lines fit the dialogue panel at three supported sizes.

## Save recovery and limits

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

The driver records 45 runs (nine configurations × five matching seeds), including failed campaigns, in `build/review/matched-experiments.json`. Use `--output path/to/result.json` for a separate record. It captures the source revision, whether the checkout was dirty, rules-file hashes and engine output. Script failures stop the run; a campaign losing within its two-retry limit is retained as a valid result. No player saves are accessed.

At source `338e125b4584d1198818eec8b66c5b26055f6bd3`, ordinary recovery, Hard recovery, Hard recovery with sacrifice costs and Hard permadeath with death’s door each completed all five seeds. Hard permadeath alone, with legacies, with section relief, with reset pressure, and with all three each completed four. Death’s door reduced the completed-campaign median permanent losses from 19.5 to 1, but one seed still ended with 23 losses. These small deterministic samples do not establish human win rates or fair difficulty.

All 48 chapter outcomes, turn counts and terminal-fall lists for the four matching seed-472019 runs agree with the separate actual app campaigns. The comparison itself runs only Rules and the existing tactical planner: default equipment, earned promotions/supports, no carrying strategy and no disk/UI verification. Eligible legacy purchases are recorded but not equipped. Reset pressure also changes the first deployment by supplying two enemy tonics and requiring Lyra, so its toggle is not an isolated stat-scaling comparison. No balance values changed in response to this survey.

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
