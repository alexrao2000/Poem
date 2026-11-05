# Campaign experiments

These are independent switches in Options, all off for an existing campaign unless its save already enabled them. Permadeath remains a separate toggle. Debug mode creates a temporary sandbox with a different save slot; disabling it restores the original live campaign. Use **Open debug tools** to load a chapter, make a selected ally fall, heal/revive units, or test the real retreat path.

The debug seed control accepts whole numbers from 0 through 2147483647. **Apply seed to next rolls** changes the sandbox’s random stream immediately. Loading a chapter, clean-resetting a battle or reviving/resetting the company reuses that seed; ordinary penalty retreats follow the campaign’s restart rules. The same seed, settings and sequence of actions reproduce the same results.

**Test pressure and reset battle** accepts pressure 0–10, enables enemy preparation and rebuilds the current chapter using the selected seed. It keeps other trial switches and the consequence ledger. Load the chapter first, then choose pressure; a fresh-roster chapter load clears earlier consequences. The company experiment panel and debug report show the stat bonuses, held tonics and raider advance that will apply on the next deployment.

**View experiment report** opens a read-only JSON record of the rules, seed, current random state, casualties, pressure and combatants. It includes a transfer code to restore the exact position in another debug session; **Copy restore code** copies that code by itself. Viewing or copying the report does not change the simulation. Reports stay local unless you choose to share them.

## Current rules

| Switch | Behavior |
| --- | --- |
| Permadeath | Dead recruits remain unavailable after victory. Read support memories and memorial dossiers remain. Lyra falling loses the attempt. |
| Save every action | Movement, combat, healing, rescue/drop and phase changes save before their presentation. No movement undo. With permadeath, deaths commit during battle and survive retries. Saves include RNG and enemy action flags, so resuming an interrupted enemy phase does not repeat its resolved attacks. |
| Restart the current section | With permadeath on, defeat or a requested retreat returns to chapters 1, 5 or 9. Growth and chapter progress rewind to that section’s checkpoint; recorded casualties, legacy purchases, volunteers, injuries and pressure persist. Lyra must deploy. |
| Enemies prepare after resets | Works with either permadeath setting. Defeat/retreat raises pressure by one, capped at ten. Each pressure point adds 2 enemy HP and 1 power. Enemies begin with two held healing tonics, reduced by pressure, and can use remaining tonics when badly hurt. Non-boss Corsairs and Rangers take a free movement action before the retry. Lyra must deploy and her death ends the attempt. Reloading an in-progress save resumes it without an additional penalty. |
| Death’s door & rescue | A lethal hit downs an ally for two player-phase endings. They occupy their tile but cannot act, counter or be attacked. A clickable map badge shows the remaining two or one player-phase endings. Any adjacent ally can rescue them, consuming an action. Carrying pauses bleeding and costs 2 movement. Drop consumes an action and needs a free adjacent tile. Staff healing revives a downed ally with their action spent; a carried healed ally is placed on a free adjacent tile if possible, otherwise remains carried until dropped. Victory evacuates downed allies. If nobody can act, the attempt is lost. |
| Harder enemy forces | At deployment, enemies gain `6 + chapter index` HP, `2 + floor(chapter index / 2)` power, `1 + floor(chapter index / 4)` speed and `floor(chapter index / 3)` defense. This combines with reset pressure. |
| Death events & legacy supplies | With permadeath, each non-lord death commits immediately and grants one legacy credit, once per recruit. The first loss can bring Faye early; the third can bring Noor early. The war council’s experiment panel offers early shared access to a tempered sword (1 credit/1 loss), war hammer (2/2) and longbow (3/3). Purchased stock cannot be bought repeatedly. These use existing recruits and equipment; they are not additional roster/art assets. |
| Sacrifice costs & openings | A fallen ally grants surviving allies +2 attack through the next player turn. If they return, they start attempts through the following chapter with 4 HP missing and one tonic instead of two. Base maximum HP and permanent growth are unchanged. Healing can restore the missing health. This works with either permadeath setting. |

Selected units show carrying, recovery and active sacrifice openings in one compact status line. Hover it for the effective carrying movement, bonus duration and recovery explanation.

At section breaks, the relief-column event brings recruits scheduled for that chapter and the following chapter to the rally point. Twenty-two original lines cover relief arrivals, early volunteers and retreats. These scenes play once at camp, persist across section restarts and can be replayed as company memories. Retreats describe the regent retaking the road while survivors withdraw to a rally point. The original chapter dialogue remains; a fuller branching story and bespoke death-triggered recruits are still future content work.

A toggle change applies immediately where possible. Enemy difficulty and returning-unit supplies apply when deploying the next attempt. Disabling a switch does not erase already committed deaths, purchases or pressure. Debug tools can intentionally bypass consequences for inspection: **Reset current battle** is a clean rebuild; **Test reset / section retreat** exercises the actual penalty path.

## Save recovery and limits

Saves use an increasing sequence number. Loading selects the newest validated primary, recovery or completed temporary checkpoint. With action saving enabled, both the primary and recovery files contain the current checkpoint; recovery cannot silently rewind to the previous action. A failed checkpoint displays a warning and blocks further player actions until saving succeeds. An interrupted enemy phase resumes only enemies that have not acted.

Browser builds also write and read back one localStorage recovery record per save slot before reporting success. Loading compares that record with the filesystem checkpoints, including when the filesystem has no campaign yet. This covers a reload while the engine's asynchronous IndexedDB flush is pending. The normal and debug records remain separate. If browser storage rejects a write or its read-back check, saving reports failure; use a transfer code to keep the current position. This path is covered by JavaScript storage doubles and headless recovery/failure tests; actual browser reload verification remains outstanding.

The extra record uses the public [Web Storage API](https://developer.mozilla.org/en-US/docs/Web/API/Storage/setItem) through [JavaScriptBridge](https://docs.godotengine.org/en/4.5/classes/class_javascriptbridge.html). It avoids depending on Godot's private filesystem internals. [Godot 4.5.1's implementation](https://github.com/godotengine/godot/blob/4.5.1-stable/platform/web/js/libs/library_godot_os.js) performs the filesystem sync asynchronously without returning storage errors to the game script. Browser data clearing, private-session disposal, storage eviction and device failure can still remove local saves; keep transfer-code backups for long experiments.

This is a local experimentation harness, not tamper-resistant ironman enforcement. Players can deliberately change toggles, use debug tools, or import an older exported save. An external process killing the game before a resolved action can finish writing is outside the guarantee. No server-side authority is involved.

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
