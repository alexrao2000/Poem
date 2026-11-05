extends SceneTree
# Deterministic balance probe: six legal automated campaigns with the hard and
# sacrifice trials enabled. Prints outcomes; it does not certify human difficulty.
# Run with Godot --headless --path . --script scripts/benchmark_trials.gd.
const Rules=preload("res://scripts/rules.gd")
const Tactics=preload("res://scripts/tactics.gd")
func _initialize():call_deferred("run")
func run():
 var rescue_enabled="--death-door" in OS.get_cmdline_user_args()
 for seed_value in [472019,17,309]:
  await simulate(seed_value,0,false,rescue_enabled)
  await simulate(seed_value,0,true,rescue_enabled)
 quit()

func simulate(seed_value,branch=-1,permanent=false,rescue_enabled=false) -> int:
 var g=Rules.new();g.new_campaign(permanent);g.death_door=rescue_enabled;g.trials.flags.hard_campaign=true;g.trials.flags.sacrifice_cost=true;g.action_saves=true;g.rng.seed=seed_value
 var ai=Tactics.new();var total_turns=0;var victories=0;var revivals=0;var terminal_losses=0
 for chapter in range(12):
  g.chapter=chapter
  if branch>=0:
   for unit in g.available():
    var path=g.promotion_options(unit)[branch]
    if g.can_promote(unit,path.id):assert(g.promote(unit,path.id))
   for entry in g.supports.entries:
    while g.supports.can_read(entry.id,chapter):assert(g.supports.complete_scene(entry.id,chapter))
  var available=g.available();available.sort_custom(func(a,b):return a.level>b.level)
  g.deployed=[]
  for unit in available:
   if unit.weapon=="staff":g.deployed.append(unit.id);break
  for unit in available:
   if unit.weapon!="staff" and g.deployed.size()<6:g.deployed.append(unit.id)
  g.start_battle()
  assert(g.units.all(func(unit):return unit.team!="player" or unit.id not in g.lost_ids()),"No earlier casualty enters a later deployment")
  while g.result()=="" and g.turn<=50:
   var players=g.living("player")
   players.sort_custom(func(a,b):return a.weapon!="staff" and b.weapon=="staff")
   for unit in players:
    if unit.hp>0:
     var downed_ids=g.units.filter(func(patient):return g.DeathDoor.downed(patient)).map(func(patient):return patient.id)
     ai.apply_plan(g,unit,ai.plan(g,unit))
     revivals+=g.units.filter(func(patient):return patient.id in downed_ids and patient.hp>0).size()
    if g.result()!="":break
   if g.result()!="":break
   g.begin_enemy_phase()
   if g.result()!="":break
   for unit in g.living("enemy"):
    if unit.hp>0:ai.apply_plan(g,unit,ai.plan(g,unit))
    if g.result()!="":break
   if g.result()=="":g.next_player_turn()
   await process_frame
  var outcome=g.result();total_turns+=g.turn
  print("CHAPTER ",chapter+1,": ",outcome if outcome!="" else "stalemate"," / turns ",g.turn," / survivors ",g.living("player").size()," / enemies ",g.living("enemy").size())
  terminal_losses+=g.units.filter(func(unit):return unit.team=="player" and unit.hp<=0 and not g.DeathDoor.downed(unit)).size()
  if outcome=="victory":victories+=1
  if outcome!="victory":break
  var losses=g.lost_ids(true);g.finish_chapter()
  if permanent:
   assert(g.lost_ids()==losses,"Every permanent casualty survives chapter advancement")
   var copy=Rules.new();assert(copy.import_code(g.export_code("ending" if g.completed else "camp"))!="" and copy.lost_ids()==losses,"Every permadeath chapter transfers its complete casualty record")
 print("CAMPAIGN seed ",seed_value," / permadeath ",permanent," / death-door ",rescue_enabled,": ",victories,"/12 victories in ",total_turns," total turns / revivals ",revivals," / terminal losses ",terminal_losses," using legal automated actions")
 return victories
