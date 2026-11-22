extends SceneTree
# Formation is optional preparation data. Defaults and existing battle saves
# keep their placement; explicit swaps only choose among legal starting slots.

const Rules=preload("res://scripts/rules.gd")
func _initialize():call_deferred("run")
func canonical(data):return JSON.parse_string(JSON.stringify(data))
func run():
 var g=Rules.new();var checks=0
 for chapter in range(12):
  g.new_campaign(true);g.chapter=chapter;g.deployed=g.available().slice(0,6).map(func(unit):return unit.id)
  var defaults=g.deployment_slots();var selected=g.deployed.duplicate();var rng=g.rng.state
  assert(defaults.filter(func(id):return not id.is_empty())==g.available().filter(func(unit):return unit.id in g.deployed).map(func(unit):return unit.id))
  var old=g.save_data("camp").duplicate(true);old.erase("formation_order")
  for first in range(defaults.size()):
   for second in range(defaults.size()):
    var order=defaults.duplicate();var prior=order[first];order[first]=order[second];order[second]=prior
    assert(g.set_formation_order(order));order[first]="caller edit"
    assert(g.deployment_slots()[first]!=order[first],"Formation owns its copied draft")
    g.start_battle()
    for unit in g.living("player"):
     var slot=g.deployment_slots().find(unit.id);var tile=g.info().deployment_positions[slot]
     assert(g.pos(unit)==Vector2i(tile[0],tile[1]) and g.terrain(g.pos(unit)) not in ["#","~"])
    assert(g.deployed==selected and g.rng.state==rng)
    var saved=canonical(g.save_data("battle"));var restored=Rules.new();assert(restored.restore_save(saved)=="battle")
    assert(canonical(restored.save_data("battle"))==saved,"Formation round trip preserves exact active battle state")
    restored.formation_order.clear();assert(canonical(restored.units)==saved.units,"Future placement preferences do not reposition a current battle")
    checks+=1
  assert(g.restore_save(old)=="camp" and g.formation_order.is_empty() and g.deployment_slots()==defaults,"Missing optional field restores the legacy placement")
  for invalid in [null,"lyra",["unknown"],["lyra","lyra"],[1],["","","","","","",""]]:
   var malformed=old.duplicate(true);malformed.formation_order=invalid;assert(not g.valid_save(malformed))
  var before=canonical(g.save_data("camp"))
  assert(not g.set_formation_order(["lyra"]) and not g.set_formation_order(["lyra","lyra","","","",""]))
  assert(canonical(g.save_data("camp"))==before,"Invalid draft never changes the company")
 for mode in ["pressure","sections"]:
  g.new_campaign(true);g.chapter=5;g.deployed=g.available().filter(func(unit):return unit.id!="lyra").slice(0,6).map(func(unit):return unit.id)
  g.trials.flags.reset_pressure=mode=="pressure";g.trials.flags.section_restarts=mode=="sections"
  var before=g.deployed.duplicate();var draft=g.deployment_slots();assert("lyra" in draft and g.deployed==before)
  draft.reverse();assert(g.set_formation_order(draft));g.start_battle()
  assert("lyra" in g.deployed and g.units[0].team=="player" and g.deployment_slots()==draft)
  var lord=g.units.filter(func(unit):return unit.id=="lyra")[0];var point=g.info().deployment_positions[draft.find("lyra")]
  assert(g.pos(lord)==Vector2i(point[0],point[1]),"Required leader may use any starting tile while remaining deployed")
 g.new_campaign(true);g.action_saves=true;g.start_battle();var draft=g.deployment_slots();draft.reverse();assert(g.set_formation_order(draft))
 var patient=g.units.filter(func(unit):return unit.id=="oren")[0];patient.hp=0;g.commit_casualties()
 var survivors=g.deployment_slots();assert("oren" not in survivors)
 for id in ["lyra","sera","ivo"]:assert(survivors.find(id)==draft.find(id),"A casualty does not silently shuffle surviving placements")
 g.new_campaign();assert(g.formation_order.is_empty())
 print("PASS: %d chapter slot swaps, legal positions and exact save round trips; legacy defaults, malformed-data rejection, copied drafts, required-lord placement and stable survivor slots"%checks)
 quit()
