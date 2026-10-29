extends SceneTree
const Rules=preload("res://scripts/rules.gd")
const Tactics=preload("res://scripts/tactics.gd")
func _initialize():call_deferred("run")
func run():
 var wins=0
 for seed_value in [472019,17,309]:
  wins+=await simulate(seed_value)
 print("PASS: 36 chapter victories across three campaign seeds" if wins==36 else "FAIL: campaign needs balance/pathing work")
 quit(0 if wins==36 else 1)

func simulate(seed_value) -> int:
 var g=Rules.new();g.rng.seed=seed_value
 var ai=Tactics.new();var total_turns=0;var victories=0
 for chapter in range(12):
  g.chapter=chapter
  var available=g.available();available.sort_custom(func(a,b):return a.level>b.level)
  g.deployed=[]
  for unit in available:
   if unit.weapon=="staff":g.deployed.append(unit.id);break
  for unit in available:
   if unit.weapon!="staff" and g.deployed.size()<6:g.deployed.append(unit.id)
  g.start_battle()
  while g.result()=="" and g.turn<=50:
   var players=g.living("player")
   players.sort_custom(func(a,b):return a.weapon!="staff" and b.weapon=="staff")
   for unit in players:
    if unit.hp>0:ai.apply_plan(g,unit,ai.plan(g,unit))
    if g.result()!="":break
   if g.result()!="":break
   g.begin_enemy_phase()
   for unit in g.living("enemy"):
    if unit.hp>0:ai.apply_plan(g,unit,ai.plan(g,unit))
    if g.result()!="":break
   if g.result()=="":g.next_player_turn()
   await process_frame
  var outcome=g.result();total_turns+=g.turn
  print("CHAPTER ",chapter+1,": ",outcome if outcome!="" else "stalemate"," / turns ",g.turn," / survivors ",g.living("player").size()," / enemies ",g.living("enemy").size())
  if outcome=="victory":victories+=1
  g.finish_chapter()
 print("CAMPAIGN seed ",seed_value,": ",victories,"/12 victories in ",total_turns," total turns using legal automated actions")
 return victories
