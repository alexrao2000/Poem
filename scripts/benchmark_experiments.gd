extends SceneTree
const Rules=preload("res://scripts/rules.gd")
const Tactics=preload("res://scripts/tactics.gd")
const PROFILES=[
 {"id":"ordinary","name":"Ordinary · recoverable","permadeath":false,"door":false,"flags":[]},
 {"id":"hard_recoverable","name":"Hard · recoverable","permadeath":false,"door":false,"flags":["hard_campaign"]},
 {"id":"hard_permanent","name":"Hard · permanent","permadeath":true,"door":false,"flags":["hard_campaign"]},
 {"id":"hard_death_door","name":"Hard · permanent + death’s door","permadeath":true,"door":true,"flags":["hard_campaign"]},
 {"id":"hard_sacrifice","name":"Hard · recoverable + sacrifice","permadeath":false,"door":false,"flags":["hard_campaign","sacrifice_cost"]},
 {"id":"hard_legacy","name":"Hard · permanent + legacies","permadeath":true,"door":false,"flags":["hard_campaign","death_legacies"]},
 {"id":"hard_sections","name":"Hard · permanent + sections","permadeath":true,"door":false,"flags":["hard_campaign","section_restarts"]},
 {"id":"hard_pressure","name":"Hard · permanent + reset pressure","permadeath":true,"door":false,"flags":["hard_campaign","reset_pressure"]},
 {"id":"hard_committed","name":"Hard · permanent + sections/pressure/legacies","permadeath":true,"door":false,"flags":["hard_campaign","section_restarts","reset_pressure","death_legacies"]}
]
var output_path=""
var report={"source":"unrecorded","source_dirty":true,"complete":false,"profiles":PROFILES,"seeds":[472019,17,309,2026,8675309],"method":"Rules-layer matched-seed comparison, not an app UI run. Same existing legal Tactics planner on both teams; action saves flag on, but no disk persistence exercised. Highest-level deployment with one healer, mandatory Lyra first when the selected rules require it. Ordinary earned first-branch promotions and available support conversations. Default equipment retained; eligible legacy purchases are recorded but not equipped by this heuristic. No carrying strategy. At most two retries, 18 battles and 50 player turns per battle. No altered stats, forced outcomes or balance edits. Five seeds do not establish human difficulty or statistical certainty.","runs":[]}
# Use scripts/benchmark_experiments.py to capture revision, failures and deadlines.
func _initialize():
 var args=OS.get_cmdline_user_args()
 if args.size() not in [3,4]:
  push_error("Expected output path, source revision, clean/dirty marker and optional configuration JSON");quit(2);return
 output_path=args[0];report.source=args[1];report.source_dirty=args[2]!="clean"
 report.requested_equipment=[]
 if args.size()==4:
  var configuration=JSON.parse_string(args[3]);assert(configuration is Dictionary)
  report.profiles=[]
  for id in configuration.profiles:
   var matching=PROFILES.filter(func(profile):return profile.id==id);assert(matching.size()==1);report.profiles.append(matching[0])
  report.seeds=[]
  for seed_value in configuration.seeds:report.seeds.append(str(seed_value).to_int())
  report.requested_equipment=configuration.equipment
 if not report.requested_equipment.is_empty():
  report.method=report.method.replace("Default equipment retained; eligible legacy purchases are recorded but not equipped by this heuristic.","Requested items replace compatible recruits' equipment during preparation only when ordinary equip rules allow them; unavailable items leave the current loadout in place. Eligible legacy purchases follow the existing fixed stock order. Loadout changes and every deployment's actual items are recorded. This is an explicit loadout experiment, not an optimal-equipment policy.")
 report.method=report.method.replace("Five seeds do not establish human difficulty or statistical certainty.","This bounded seed sample does not establish human difficulty or statistical certainty.")
 call_deferred("run")
func checkpoint():
 var file=FileAccess.open(output_path,FileAccess.WRITE);assert(file!=null,"Comparison output must be writable");file.store_string(JSON.stringify(report,"  "));file.close()
func prepare(game,record):
 for recruit in game.available():
  var path=game.promotion_options(recruit)[0]
  if game.can_promote(recruit,path.id):assert(game.promote(recruit,path.id));record.promotions+=1
 for entry in game.supports.entries:
  while game.bond_available(entry) and game.supports.can_read(entry.id,game.chapter):assert(game.supports.complete_scene(entry.id,game.chapter));record.support_reads+=1
 for stock in game.trials.LEGACY_STOCK:game.trials.buy(game,stock.id)
 for item_id in report.requested_equipment:
  for recruit in game.available():
   var previous=recruit.item
   if previous!=item_id and game.equip(recruit,item_id):record.loadout_changes.append({"chapter":game.chapter+1,"unit":recruit.id,"from":previous,"to":item_id,"legacy_purchase":item_id in game.trials.purchases})
 var available=game.available();available.sort_custom(func(a,b):return a.level>b.level)
 game.deployed=[]
 if game.trials.flags.reset_pressure or (game.permadeath and game.trials.flags.section_restarts):game.deployed.append("lyra")
 for recruit in available:
  if recruit.weapon=="staff":game.deployed.append(recruit.id);break
 for recruit in available:
  if recruit.weapon!="staff" and recruit.id not in game.deployed and game.deployed.size()<6:game.deployed.append(recruit.id)
func action(game,unit,planner,battle):
 var choice=planner.plan(game,unit)
 var patient=game.units.filter(func(other):return other.id==choice.target)
 var reviving=choice.action=="heal" and not patient.is_empty() and game.DeathDoor.downed(patient[0])
 var before=game.living("player").map(func(ally):return ally.id)
 planner.apply_plan(game,unit,choice)
 assert(unit.acted,"Every chosen action resolves legally")
 for ally in game.units:
  if ally.id in before and ally.hp<=0:battle.incapacitations+=1
 if choice.action=="heal":
  if unit.team=="enemy":battle.enemy_heals+=1
  else:battle.player_heals+=1
  if reviving and patient[0].hp>0:battle.revivals+=1
 battle.actions+=1
func run():
 var started=Time.get_ticks_msec()
 report.source_files={}
 for file in ["res://scripts/rules.gd","res://scripts/tactics.gd","res://scripts/campaign_trials.gd","res://scripts/death_door.gd","res://data/campaign.json","res://data/equipment.json","res://data/promotions.json","res://scripts/benchmark_experiments.gd","res://scripts/benchmark_experiments.py"]:report.source_files[file]=FileAccess.get_file_as_string(file).sha256_text()
 for profile in report.profiles:
  for seed_value in report.seeds:
   var game=Rules.new();game.new_campaign(profile.permadeath);game.action_saves=true;game.death_door=profile.door
   for flag in profile.flags:game.trials.flags[flag]=true
   game.rng.seed=seed_value;var planner=Tactics.new()
   var record={"profile":profile.id,"seed":seed_value,"completed":false,"stop":"","retries":0,"promotions":0,"support_reads":0,"loadout_changes":[],"battles":[],"permanent_losses":[],"volunteers":[],"purchases":[],"credits":0}
   report.runs.append(record)
   while not game.completed and record.battles.size()<18:
    prepare(game,record);game.start_battle()
    var battle={"chapter":game.chapter+1,"pressure":game.trials.pressure,"deployment":game.deployed.duplicate(),"turns":0,"outcome":"","actions":0,"incapacitations":0,"player_heals":0,"enemy_heals":0,"revivals":0,"recovering":game.living("player").filter(func(unit):return unit.get("recovering",false)).map(func(unit):return unit.id),"terminal_falls":[],"downed_at_result":[]}
    battle.equipment={}
    for ally in game.living("player"):battle.equipment[ally.id]=ally.item
    record.battles.append(battle)
    while game.result()=="" and game.turn<=50:
     var players=game.living("player");players.sort_custom(func(a,b):return a.weapon!="staff" and b.weapon=="staff")
     for unit in players:
      if unit.hp>0 and not unit.acted:action(game,unit,planner,battle)
      if game.result()!="":break
     if game.result()!="":break
     game.begin_enemy_phase()
     if game.result()!="":break
     for enemy in game.living("enemy"):
      if enemy.hp>0 and not enemy.acted:action(game,enemy,planner,battle)
      if game.result()!="":break
     if game.result()=="":game.next_player_turn()
     await process_frame
    battle.outcome=game.result() if game.result()!="" else "turn_limit";battle.turns=game.turn
    battle.terminal_falls=game.units.filter(func(unit):return unit.team=="player" and unit.hp<=0 and not game.DeathDoor.downed(unit)).map(func(unit):return unit.id)
    battle.downed_at_result=game.units.filter(func(unit):return game.DeathDoor.downed(unit)).map(func(unit):return unit.id)
    if battle.outcome=="victory":game.finish_chapter()
    elif battle.outcome=="defeat" and record.retries<2:assert(game.retry_battle());record.retries+=1
    else:record.stop="retry_limit" if battle.outcome=="defeat" else "turn_limit";break
   record.completed=game.completed;record.permanent_losses=game.lost_ids();record.volunteers=game.trials.volunteers.duplicate();record.purchases=game.trials.purchases.duplicate();record.credits=game.trials.credits
   if game.completed:record.stop="campaign_complete"
   elif record.stop.is_empty():record.stop="battle_limit"
   print(profile.id," seed ",seed_value,": ",record.stop," / battles ",record.battles.size()," / permanent losses ",record.permanent_losses.size());checkpoint()
 report.complete=true;report.elapsed_seconds=(Time.get_ticks_msec()-started)/1000.0;checkpoint()
 print("PASS: ",report.runs.size()," bounded matched-seed Rules campaigns recorded, including failures; no app, disk, rendering or human-balance claim");quit()
