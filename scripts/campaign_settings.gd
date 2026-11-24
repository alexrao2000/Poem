extends RefCounted
## Shared names and behavior for campaign creation and live Options.
const SWITCHES=[
 {
  "key": "action_saves",
  "name": "Save every action",
  "text": "Commit movement and combat before animation. No movement undo. With permadeath, deaths survive retries."
 },
 {
  "key": "death_door",
  "name": "Death’s door & rescue",
  "text": "Downed allies have two player turns for rescue or staff healing. Carrying pauses the countdown and costs 2 movement."
 },
 {
  "key": "section_restarts",
  "name": "Restart the current section",
  "text": "With permadeath: retries return to the start of the four-chapter section. Deaths and legacy supplies remain. Relief recruits arrive at section breaks."
 },
 {
  "key": "reset_pressure",
  "name": "Enemies prepare after resets",
  "text": "Enemies start with two tonics. Retries add stats, use up tonics and advance raiders. Lyra must deploy; her fall ends the attempt. Works with permadeath on or off."
 },
 {
  "key": "hard_campaign",
  "name": "Harder enemy forces",
  "text": "On the next deployment: enemies gain health, attack, speed and later defense. Later garrisons also field healers."
 },
 {
  "key": "death_legacies",
  "name": "Death events & legacy supplies",
  "text": "With permadeath: each loss grants a supply credit and may bring a volunteer. Losing a Warden can bring a hospice keeper into the company."
 },
 {
  "key": "sacrifice_cost",
  "name": "Sacrifice costs & openings",
  "text": "Returning allies start attempts through the next chapter 4 HP down, with one tonic. The first fall per recruit in a chapter gives survivors +2 attack through the next player turn."
 }
]

static func enabled(game,key: String) -> bool:
 return game.trials.flags[key] if game.trials.flags.has(key) else game.get(key)

static func set_enabled(game,key: String,value: bool):
 if game.trials.flags.has(key):game.trials.flags[key]=value
 else:game.set(key,value)

static func snapshot(game) -> Dictionary:
 var values={"permadeath":game.permadeath}
 for setting in SWITCHES:values[setting.key]=enabled(game,setting.key)
 return values

static func preparation_lines(game) -> Array[String]:
 var lines: Array[String]=[]
 if game.permadeath and game.trials.flags.section_restarts:
  var rally=game.trials.section_start(game.chapter)
  lines.append("Section %d · Rally point Chapter %02d"%[game.trials.section_index(game.chapter)+1,rally+1])
 if game.trials.flags.reset_pressure:
  var enemies=game.trials.enemy_modifiers(game.chapter)
  var stock=int(enemies.held_tonics)
  lines.append("Enemy pressure %d / 10 · %d held tonic%s per enemy"%[game.trials.pressure,stock,"" if stock==1 else "s"])
  if enemies.raiders_advance:lines.append("Raiders may advance before deployment.")
 return lines
