extends RefCounted
## Reproducible starting positions, built from the ordinary campaign rules.
const SETUPS=[
 {"id":"committed_losses","title":"Committed losses & legacies","chapter":2,"permadeath":true,"action_saves":true,"death_door":false,"flags":["section_restarts","reset_pressure","hard_campaign","death_legacies"],"rules":"Chapter 3 · Permadeath and action saves ON. Harder forces, death legacies, section restarts and reset preparation ON.","steps":"In Debug, test Oren falling to earn a legacy credit and an early volunteer. Test Lyra falling, then retry: return to chapter 1 with the loss and credit retained. Visit Campaign experiments at the war council to spend the credit."},
 {"id":"reset_pressure","title":"Enemies prepare after resets","chapter":0,"permadeath":false,"action_saves":true,"death_door":false,"flags":["reset_pressure"],"rules":"Chapter 1 · Permadeath OFF, action saves ON. Reset preparation ON: enemies start with two tonics and Lyra must deploy. All other experiments OFF.","steps":"Use Test reset / section retreat in Debug, then deploy. Enemies gain 2 HP and 1 attack, have one fewer held tonic, and raiders advance. Permadeath can also be enabled in Options to compare the same reset rule."},
 {"id":"rescue","title":"Rescue at death’s door","chapter":0,"permadeath":true,"action_saves":true,"death_door":true,"flags":[],"rules":"Chapter 1 · Permadeath, action saves and death’s door ON. Lyra, Oren and Ivo begin together for rescue practice. Other experiments OFF.","steps":"In Debug, test Oren falling. Select Lyra, then Oren to rescue him. Select Ivo and heal the carried Oren. Carrying pauses the two-phase countdown; healing returns Oren to the field with his action spent."},
 {"id":"sacrifice","title":"Sacrifice & recovery","chapter":0,"permadeath":false,"action_saves":false,"death_door":false,"flags":["hard_campaign","sacrifice_cost"],"rules":"Chapter 1 · Permadeath, action saves and death’s door OFF. Harder forces and sacrifice costs ON.","steps":"In Debug, test Oren falling. Survivors gain 2 attack through the next player turn. Retreat and deploy again: Oren returns 4 HP down with one tonic. His recovery penalty lasts through the next chapter; repeated falls do not grant another opening in the same chapter."}
]

static func start(game,id: String,seed_value: int) -> bool:
 var matches=SETUPS.filter(func(setup):return setup.id==id)
 if matches.is_empty():return false
 var setup=matches[0]
 game.new_campaign(setup.permadeath);game.chapter=setup.chapter
 game.action_saves=setup.action_saves;game.death_door=setup.death_door
 for flag in setup.flags:game.trials.flags[flag]=true
 game.story_seen=["opening_"+str(game.chapter)]
 game.rng.seed=seed_value;game.start_battle()
 if id=="rescue":
  var positions={"lyra":Vector2i(2,2),"oren":Vector2i(3,2),"ivo":Vector2i(1,2)}
  for unit in game.units:
   if positions.has(unit.id):unit.x=positions[unit.id].x;unit.y=positions[unit.id].y
 return true
