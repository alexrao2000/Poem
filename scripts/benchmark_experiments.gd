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
 {"id":"hard_committed","name":"Hard · permanent + sections/pressure/legacies","permadeath":true,"door":false,"flags":["hard_campaign","section_restarts","reset_pressure","death_legacies"]},
 {"id":"hard_permanent_all","name":"Hard · permanent losses, sections and pressure","permadeath":true,"door":true,"flags":["hard_campaign","death_legacies","section_restarts","reset_pressure"]},
 {"id":"hard_recoverable_all","name":"Hard · recovery, sacrifice and pressure","permadeath":false,"door":true,"flags":["hard_campaign","sacrifice_cost","reset_pressure"]},
]
var output_path=""
var report={"source":"unrecorded","source_dirty":true,"complete":false,"profiles":PROFILES,"seeds":[472019,17,309,2026,8675309],"method":"Rules-layer matched-seed comparison, not an app UI run. Same existing legal Tactics planner on both teams; action saves flag on, but no disk persistence exercised. Highest-level deployment with one healer, mandatory Lyra first when the selected rules require it. Ordinary earned first-branch promotions and available support conversations. Default equipment retained; eligible legacy purchases are recorded but not equipped by this heuristic. No carrying strategy. At most two retries, 18 battles and 50 player turns per battle. No altered stats, forced outcomes or balance edits. Five seeds do not establish human difficulty or statistical certainty.","runs":[]}
# Use scripts/benchmark_experiments.py to capture revision, failures and deadlines.
func _initialize():
 var args=OS.get_cmdline_user_args()
 if args.size() not in [3,4]:
  push_error("Expected output path, source revision, clean/dirty marker and optional configuration JSON");quit(2);return
 output_path=args[0];report.source=args[1];report.source_dirty=args[2]!="clean"
 report.requested_equipment=[];report.carry_patients=false
 report.retreat_chapters=[]
 report.profiles=PROFILES.slice(0,9)
 if args.size()==4:
  var configuration=JSON.parse_string(args[3]);assert(configuration is Dictionary)
  report.profiles=[]
  for id in configuration.profiles:
   var matching=PROFILES.filter(func(profile):return profile.id==id);assert(matching.size()==1);report.profiles.append(matching[0])
  report.seeds=[]
  for seed_value in configuration.seeds:report.seeds.append(str(seed_value).to_int())
  report.requested_equipment=configuration.equipment
  report.carry_patients=configuration.get("carry_patients",false)
  report.retreat_chapters=configuration.get("retreat_chapters",[]).map(func(chapter):return int(chapter))
 if not report.requested_equipment.is_empty():
  report.method=report.method.replace("Default equipment retained; eligible legacy purchases are recorded but not equipped by this heuristic.","Requested items replace compatible recruits' equipment during preparation only when ordinary equip rules allow them; unavailable items leave the current loadout in place. Eligible legacy purchases follow the existing fixed stock order. Loadout changes and every deployment's actual items are recorded. This is an explicit loadout experiment, not an optimal-equipment policy.")
 if report.carry_patients:
  report.method=report.method.replace("No carrying strategy.","In death’s door profiles, standing allies can rescue patients on their last phase when no ready healer can reach them. Carriers seek healing range while accounting for enemy reach. The report counts rescues, carried revivals, paused phase endings and bleed-outs.")
 if not report.retreat_chapters.is_empty():
  report.method+=" Each requested chapter triggers one deliberate retreat before its first action if reached. The next deployment is compared with a pressure-free copy of the same camp."
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
func free_moves(game,unit: Dictionary) -> Dictionary:
 var here=game.pos(unit)
 var moves={here:0} if unit.get("moved",false) else game.reachable(unit)
 for tile in moves.keys():
  if tile!=here and game.at(tile)!=null:moves.erase(tile)
 return moves

func can_reach_patient(game,patient: Dictionary,healers: Array) -> bool:
 for healer in healers:
  if not game.can_act(healer):continue
  var probe=healer.duplicate()
  for tile in free_moves(game,healer):
   probe.x=tile.x;probe.y=tile.y
   if game.can_heal(probe,patient):return true
 return false

func rescue_choice(game,unit: Dictionary,planner,ordinary: Dictionary) -> Dictionary:
 var passenger=game.DeathDoor.passenger(game,unit)
 if unit.weapon=="staff" or (game.info().objective=="seize" and ordinary.position==game.objective_position()):return ordinary
 var healers=game.living("player").filter(func(ally):return ally.weapon=="staff")
 if healers.is_empty():return ordinary
 var patients=[]
 if passenger!=null:
  if not game.DeathDoor.downed(passenger):return ordinary
  if can_reach_patient(game,passenger,healers):
   return ordinary if ordinary.position==game.pos(unit) else {"position":game.pos(unit),"action":"wait","target":""}
 else:
  for patient in game.units:
   if game.DeathDoor.downed(patient) and patient.bleed_turns==1 and patient.get("carried_by","").is_empty() and not can_reach_patient(game,patient,healers):patients.append(patient)
  if patients.is_empty():return ordinary
 var danger={}
 for enemy in game.living("enemy"):
  for tile in planner.threatened_tiles(game,enemy):danger[tile]=danger.get(tile,0)+1
 var moves=free_moves(game,unit)
 var choice=ordinary;var best=INF;var probe=unit.duplicate()
 for tile in moves:
  var nearest=INF
  for healer in healers:nearest=minf(nearest,absi(tile.x-healer.x)+absi(tile.y-healer.y))
  var score=nearest+danger.get(tile,0)*2+float(moves[tile])*.05
  if score>=best:continue
  if passenger!=null:
   best=score;choice={"position":tile,"action":"wait","target":""}
   continue
  probe.x=tile.x;probe.y=tile.y
  for patient in patients:
   if game.DeathDoor.can_rescue(game,probe,patient):
    best=score;choice={"position":tile,"action":"rescue","target":patient.id};break
 return choice

func action(game,unit,planner,battle):
 var choice=planner.plan(game,unit)
 if report.carry_patients and game.death_door and unit.team=="player":choice=rescue_choice(game,unit,planner,choice)
 var patient=game.units.filter(func(other):return other.id==choice.target)
 var reviving=choice.action=="heal" and not patient.is_empty() and game.DeathDoor.downed(patient[0])
 var carrier=patient[0].get("carried_by","") if reviving else ""
 var before=game.living("player").map(func(ally):return ally.id)
 if choice.action=="rescue":
  var positioned=choice.position==game.pos(unit) or game.move_unit(unit,choice.position)
  assert(positioned and patient.size()==1)
  var rescued=game.DeathDoor.rescue(game,unit,patient[0])
  assert(rescued)
  battle.rescues+=1
  battle.patient_events.append({"event":"rescue","turn":game.turn,"patient":patient[0].id,"carrier":unit.id})
 else:planner.apply_plan(game,unit,choice)
 assert(unit.acted,"Every chosen action resolves legally")
 for ally in game.units:
  if ally.id in before and ally.hp<=0:battle.incapacitations+=1
 if choice.action=="heal":
  if unit.team=="enemy":battle.enemy_heals+=1
  else:battle.player_heals+=1
  if reviving and patient[0].hp>0:
   battle.revivals+=1
   if not carrier.is_empty():battle.carried_revivals+=1
   battle.patient_events.append({"event":"revive","turn":game.turn,"patient":patient[0].id,"healer":unit.id,"carrier":carrier,"hp":patient[0].hp})
 battle.actions+=1

func begin_enemy_phase(game,battle):
 var carried={};var expiring=[]
 for unit in game.units:
  if not game.DeathDoor.downed(unit):continue
  if not unit.get("carried_by","").is_empty():carried[unit.id]=unit.bleed_turns
  elif unit.bleed_turns==1:expiring.append(unit.id)
 game.begin_enemy_phase()
 for unit in game.units:
  if carried.has(unit.id):
   assert(game.DeathDoor.downed(unit) and unit.bleed_turns==carried[unit.id])
   battle.carried_phase_endings+=1
   battle.patient_events.append({"event":"paused_countdown","turn":game.turn,"patient":unit.id,"carrier":unit.carried_by,"phases_left":unit.bleed_turns})
  elif unit.id in expiring:
   assert(not game.DeathDoor.downed(unit) and unit.hp==0)
   battle.bleed_outs+=1
   battle.patient_events.append({"event":"bleed_out","turn":game.turn,"patient":unit.id})
func compare_preparation(game,unprepared,modifiers: Dictionary) -> Dictionary:
 var shifts=[];var pressure=game.trials.pressure if game.trials.flags.reset_pressure else 0
 var baselines={}
 for enemy in unprepared.living("enemy"):baselines[enemy.id]=enemy
 var enemies=game.living("enemy")
 assert(enemies.size()==baselines.size())
 for enemy in enemies:
  var prior=baselines[enemy.id]
  assert(enemy.max_hp==mini(game.STAT_CAPS.max_hp,prior.max_hp+2*pressure))
  assert(enemy.pow==mini(game.STAT_CAPS.pow,prior.pow+pressure) and enemy.hp==enemy.max_hp)
  assert(enemy.get("held_tonics",0)==modifiers.held_tonics)
  assert(enemy.get("reset_supplies_spent",0)==mini(2,pressure))
  if game.pos(enemy)!=unprepared.pos(prior):
   assert(enemy.get("raider",false))
   shifts.append({"id":enemy.id,"from":[prior.x,prior.y],"to":[enemy.x,enemy.y]})
 return {"enemies":enemies.size(),"raider_shifts":shifts,"tonics":modifiers.held_tonics}

func deploy_for_experiment(game,record) -> bool:
 prepare(game,record)
 var pending=record.planned_retreats.back() if not record.planned_retreats.is_empty() else {}
 var unprepared=null
 if not pending.is_empty() and not pending.has("prepared"):
  unprepared=Rules.new()
  var stage=unprepared.restore_save(game.save_data("camp"))
  assert(stage=="camp")
  unprepared.trials.flags.reset_pressure=false
  unprepared.start_battle()
 game.start_battle()
 if unprepared!=null:
  assert(game.chapter+1==pending.to and game.trials.pressure==pending.pressure)
  pending.prepared=compare_preparation(game,unprepared,pending.modifiers)
 var chapter=game.chapter+1
 if chapter not in report.retreat_chapters or record.planned_retreats.any(func(event):return event.from==chapter):return true
 var preview=game.trials.restart_preview(game)
 var prior_losses=game.lost_ids()
 var purchases=game.trials.purchases.duplicate()
 var restarted=game.trials.restart(game)
 assert(restarted and game.chapter==preview.chapter and game.trials.pressure==preview.pressure and game.units.is_empty())
 assert(prior_losses.all(func(id):return id in game.lost_ids()) and purchases==game.trials.purchases)
 record.planned_retreats.append({"from":chapter,"to":game.chapter+1,"pressure":game.trials.pressure,
  "preserved_losses":prior_losses,"preserved_purchases":purchases,"modifiers":preview.enemies})
 return false

func run():
 var started=Time.get_ticks_msec()
 report.source_files={}
 for file in ["res://scripts/rules.gd","res://scripts/tactics.gd","res://scripts/campaign_trials.gd","res://scripts/death_door.gd","res://data/campaign.json","res://data/equipment.json","res://data/promotions.json","res://scripts/benchmark_experiments.gd","res://scripts/benchmark_experiments.py"]:report.source_files[file]=FileAccess.get_file_as_string(file).sha256_text()
 for profile in report.profiles:
  for seed_value in report.seeds:
   var game=Rules.new();game.new_campaign(profile.permadeath);game.action_saves=true;game.death_door=profile.door
   for flag in profile.flags:game.trials.flags[flag]=true
   game.rng.seed=seed_value;var planner=Tactics.new()
   var record={"profile":profile.id,"seed":seed_value,"completed":false,"stop":"","retries":0,"promotions":0,"support_reads":0,"loadout_changes":[],"battles":[],"permanent_losses":[],"volunteers":[],"purchases":[],"credits":0,"planned_retreats":[]}
   report.runs.append(record)
   while not game.completed and record.battles.size()<18:
    if not deploy_for_experiment(game,record):continue
    var recovering=game.living("player").filter(func(unit):return unit.get("recovering",false)).map(func(unit):return unit.id)
    var battle={
     "chapter":game.chapter+1,"pressure":game.trials.pressure,"deployment":game.deployed.duplicate(),
     "turns":0,"outcome":"","actions":0,"incapacitations":0,"player_heals":0,"enemy_heals":0,"revivals":0,
     "rescues":0,"carried_revivals":0,"carried_phase_endings":0,"bleed_outs":0,
     "recovering":recovering,"terminal_falls":[],"downed_at_result":[],"patient_events":[],
    }
    battle.equipment={}
    for ally in game.living("player"):battle.equipment[ally.id]=ally.item
    record.battles.append(battle)
    while game.result()=="" and game.turn<=50:
     var players=game.living("player");players.sort_custom(func(a,b):return a.weapon!="staff" and b.weapon=="staff")
     for unit in players:
      if unit.hp>0 and not unit.acted:action(game,unit,planner,battle)
      if game.result()!="":break
     if game.result()!="":break
     begin_enemy_phase(game,battle)
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
