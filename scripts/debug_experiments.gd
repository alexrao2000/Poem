extends RefCounted
## Reproducible starting positions, built from the ordinary campaign rules.
const SETUPS=[
 {"id":"committed_losses","title":"Committed losses & legacies","chapter":2,"permadeath":true,"action_saves":true,"death_door":false,"flags":["section_restarts","reset_pressure","hard_campaign","death_legacies"],"rules":"Chapter 3 · Permadeath and action saves ON. Harder forces, death legacies, section restarts and reset preparation ON.","steps":"In Debug, test Oren falling to earn a legacy credit and an early volunteer. Test Lyra falling, then retry: return to chapter 1 with the loss and credit retained. Visit Campaign experiments at the war council to spend the credit."},
 {"id":"reset_pressure","title":"Enemies prepare after Lyra falls","chapter":0,"permadeath":false,"action_saves":true,"death_door":false,"flags":["reset_pressure"],"rules":"Cinderford · Permadeath OFF. Action saves and reset preparation ON. Lyra starts exposed at 1 HP.","steps":"End the phase with Lyra exposed on the bridge approach. Regroup and deploy. Enemies gain 2 HP and 1 attack, spend one tonic and give raiders up to one move. Retreat again to see two moves and empty tonic stocks."},
 {"id":"section_retreat","title":"Retreat with a permanent loss","chapter":5,"permadeath":true,"action_saves":true,"death_door":false,"flags":["section_restarts","reset_pressure","hard_campaign","death_legacies"],"rules":"Glass Harbor · Permadeath, action saves, section restarts, reset preparation, Hard forces and death legacies ON. Oren has fallen and earned one legacy credit.","steps":"Open the battle menu and choose War council (restart section). Read the company scenes and deploy at Kingsroad. Oren’s loss and the credit survive the return to Chapter 5. The new attempt adds one level of pressure."},
 {"id":"rescue","title":"Rescue at death’s door","chapter":0,"permadeath":true,"action_saves":true,"death_door":true,"flags":[],"rules":"Chapter 1 · Permadeath, action saves and death’s door ON. Lyra, Oren and Ivo begin together for rescue practice. Other experiments OFF.","steps":"In Debug, test Oren falling. Select Lyra, then Oren to rescue him. Select Ivo and heal the carried Oren. Carrying pauses the two-phase countdown; healing returns Oren to the field with his action spent."},
 {"id":"last_rescue","title":"Last chance rescue","chapter":0,"permadeath":true,"action_saves":true,"death_door":true,"flags":[],"rules":"Chapter 1 · Permadeath, action saves and death’s door ON. Oren is already down with one countdown tick left; Ivo has spent his action. Other experiments OFF.","steps":"Select Lyra, then adjacent Oren, and rescue him before ending the phase. Carrying pauses the countdown. Next turn, move Lyra west beside Ivo and heal Oren while he is carried. Restart this setup and end the first phase without rescuing him to compare the permanent loss."},
 {"id":"legacy_recruits","title":"Who answers the loss","chapter":3,"permadeath":true,"action_saves":true,"death_door":true,"flags":["section_restarts","death_legacies"],"rules":"Hallow Abbey · Permadeath, action saves, death’s door and death legacies ON. Ivo and Sera each have one phase ending left.","steps":"Select Esme and heal one patient before ending the phase. Move Lyra beside the other patient if you want to rescue both. Return to the war council to read any arrival scenes."},
 {"id":"sacrifice","title":"Sacrifice & recovery","chapter":0,"permadeath":false,"action_saves":true,"death_door":false,"flags":["hard_campaign","sacrifice_cost"],"rules":"Cinderford · Permadeath OFF. Action saves, Hard forces and sacrifice costs ON. Oren starts at 1 HP and the Ash guard is wounded.","steps":"End the phase. After Oren withdraws, move Sera to (4, 5) and target the Ash guard at (5, 6). The opening raises her forecast from 5 to 7 damage. Retreat and deploy to see Oren return with 4 HP missing and one tonic. Start this setup again and turn off Sacrifice costs & openings before ending the phase to compare."}
]

static func start(game,id: String,seed_value: int) -> bool:
 var matches=SETUPS.filter(func(setup):return setup.id==id)
 if matches.is_empty():return false
 var setup=matches[0]
 game.new_campaign(setup.permadeath);game.rng.seed=seed_value
 game.action_saves=setup.action_saves;game.death_door=setup.death_door
 for flag in setup.flags:game.trials.flags[flag]=true
 if id=="section_retreat":
  game.chapter=game.trials.section_start(setup.chapter)
  for chapter in range(setup.chapter):game.story_seen.append("opening_"+str(chapter))
  game.trials.arrive(game);game.trials.capture_section(game)
 game.chapter=setup.chapter
 if id=="legacy_recruits":game.deployed=["lyra","sera","ivo","esme"]
 game.story_seen.append("opening_"+str(game.chapter));game.start_battle()
 if id=="reset_pressure":
  var lyra=game.living("player").filter(func(unit):return unit.id=="lyra")[0]
  lyra.x=8;lyra.y=4;lyra.hp=1
 elif id=="section_retreat":
  var oren=game.living("player").filter(func(unit):return unit.id=="oren")[0]
  oren.hp=0;game.DeathDoor.fall(game,oren);game.commit_casualties()
 elif id=="sacrifice":
  for unit in game.units:
   if unit.id=="oren":unit.x=8;unit.y=4;unit.hp=1
   elif unit.id=="enemy_4":unit.hp=6
 elif id=="rescue":
  var positions={"lyra":Vector2i(2,2),"oren":Vector2i(3,2),"ivo":Vector2i(1,2)}
  for unit in game.units:
   if positions.has(unit.id):unit.x=positions[unit.id].x;unit.y=positions[unit.id].y
 elif id=="last_rescue":
  var positions={"lyra":Vector2i(3,4),"oren":Vector2i(4,4),"ivo":Vector2i(0,4),"sera":Vector2i(1,5)}
  for unit in game.units:
   if positions.has(unit.id):unit.x=positions[unit.id].x;unit.y=positions[unit.id].y
   if unit.id=="oren":unit.hp=0;game.DeathDoor.fall(game,unit);unit.bleed_turns=1
   elif unit.id=="ivo":unit.acted=true
 elif id=="legacy_recruits":
  var positions={"lyra":Vector2i(2,4),"ivo":Vector2i(1,3),"sera":Vector2i(3,3),"esme":Vector2i(2,3)}
  for unit in game.living("player"):
   var cell=positions[unit.id]
   unit.x=cell.x;unit.y=cell.y
   if unit.id in ["ivo","sera"]:
    unit.hp=0;game.DeathDoor.fall(game,unit);unit.bleed_turns=1
 return true
