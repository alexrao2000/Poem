extends RefCounted
# Experimental campaign consequences are separate from rendering and core combat.
# Section snapshots exclude this ledger: casualties, purchases, injuries and reset
# pressure survive a rewind. Default settings leave the original campaign intact.

const FLAGS={"section_restarts":false,"reset_pressure":false,"hard_campaign":false,"death_legacies":false,"sacrifice_cost":false}
const LEGACY_STOCK=[{"id":"tempered_sword","cost":1,"losses":1},{"id":"war_hammer","cost":2,"losses":2},{"id":"longbow","cost":3,"losses":3}]
const SCENE_TITLES={"relief_4":"Relief at the abbey","relief_8":"Relief at the monastery","retreat_0":"Regrouping at Cinderford","retreat_4":"Return to the abbey","retreat_8":"Return to Starfall","volunteer_faye":"Faye answers the call","volunteer_noor":"Noor leaves the observatory","memorial_0":"Names in the company book","memorial_4":"The abbey record","memorial_8":"The monastery bell"}
var scenes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign_trial_scenes.json"))
var earned_scenes: Array=[]
var read_scenes: Array=[]
var flags=FLAGS.duplicate()
var pressure=0
var losses: Dictionary={}
var injuries: Dictionary={}
var volunteers: Array=[]
var purchases: Array=[]
var credits=0
var events: Array=[]
var checkpoint: Dictionary={}

func reset():
 flags=FLAGS.duplicate();pressure=0;losses.clear();injuries.clear();volunteers.clear();purchases.clear();credits=0;events.clear();checkpoint.clear();earned_scenes.clear();read_scenes.clear()

func queue_scene(id: String):
 if scenes.has(id) and id not in earned_scenes:earned_scenes.append(id)

func next_scene(game) -> Array:
 for id in earned_scenes:
  if id in read_scenes:continue
  read_scenes.append(id)
  if id.begins_with("volunteer_") and id.trim_prefix("volunteer_") in game.lost_ids():continue
  return scenes[id].duplicate(true)
 return []

func section_start(chapter: int) -> int:
 return int(chapter/4)*4

func log_event(message: String):
 events.append(message)
 if events.size()>64:events.pop_front()

func joined(game,unit: Dictionary) -> bool:
 return int(unit.join)<=game.chapter or unit.id in volunteers

func capture_section(game):
 var start=section_start(game.chapter)
 if not checkpoint.is_empty() and int(checkpoint.chapter)==start:return
 var snapshot=game
 if game.chapter!=start:
  snapshot=game.get_script().new();snapshot.chapter=start
  snapshot.deployed=snapshot.available().slice(0,6).map(func(unit):return unit.id)
 checkpoint=snapshot.save_data("camp").duplicate(true)
 checkpoint.erase("trials");checkpoint.version=5;checkpoint.units=[];checkpoint.phase="player";checkpoint.turn=1

func record_losses(game):
 for unit in game.units:
  if unit.team!="player" or unit.hp>0 or game.DeathDoor.downed(unit):continue
  if flags.sacrifice_cost and int(injuries.get(unit.id,-1))<game.chapter+1:
   injuries[unit.id]=game.chapter+1
   for ally in game.living("player"):ally.resolve_until=game.turn+1
   log_event(unit.name+" buys an opening: surviving allies gain +2 attack through the next player turn. The fallen ally needs a chapter to recover fully.")
  if not flags.death_legacies or not game.permadeath or unit.id=="lyra" or losses.has(unit.id):continue
  losses[unit.id]=game.chapter;credits+=1
  queue_scene("memorial_"+str(section_start(game.chapter)))
  log_event(unit.name+" is lost. Their last request brings one legacy supply credit to the company.")
  var volunteer="faye" if losses.size()==1 else "noor" if losses.size()==3 else ""
  if not volunteer.is_empty() and volunteer not in volunteers:
   var recruits=game.roster.filter(func(recruit):return recruit.id==volunteer)
   if not recruits.is_empty() and not recruits[0].get("fallen",false) and recruits[0].join>game.chapter:
    volunteers.append(volunteer);queue_scene("volunteer_"+volunteer)
    log_event(recruits[0].name+" answers the company's loss and arrives ahead of the planned rendezvous.")

func enemy_modifiers(chapter: int,pressure_override: int=-1) -> Dictionary:
 var extra=(pressure if pressure_override<0 else clampi(pressure_override,0,10)) if flags.reset_pressure else 0
 return {"max_hp":extra*2+(6+chapter if flags.hard_campaign else 0),"pow":extra+(2+int(chapter/2) if flags.hard_campaign else 0),"speed":1+int(chapter/4) if flags.hard_campaign else 0,"defense":int(chapter/3) if flags.hard_campaign else 0,"held_tonics":maxi(0,2-extra) if flags.reset_pressure else 0,"raiders_advance":extra>0}

func restart_preview(game) -> Dictionary:
 var chapter=section_start(game.chapter) if flags.section_restarts and game.permadeath else game.chapter
 var next_pressure=mini(10,pressure+1) if flags.reset_pressure else pressure
 return {"chapter":chapter,"pressure":next_pressure,"enemies":enemy_modifiers(chapter,next_pressure)}

func deployment_condition(game,unit: Dictionary) -> Dictionary:
 var recovering=flags.sacrifice_cost and not unit.get("fallen",false) and int(injuries.get(unit.id,-1))>=game.chapter
 return {"recovering":recovering,"hp":maxi(1,int(unit.max_hp)-4) if recovering else int(unit.max_hp),"tonics":1 if recovering else 2}

func prepare_battle(game):
 if not flags.reset_pressure and not flags.hard_campaign and not flags.sacrifice_cost:return
 var extra=pressure if flags.reset_pressure else 0
 var modifiers=enemy_modifiers(game.chapter)
 for unit in game.units:
  if unit.team=="enemy":
   for key in ["max_hp","pow","speed","defense"]:game.raise_stat(unit,key,modifiers[key])
   unit.hp=unit.max_hp
   if flags.reset_pressure:
    unit.held_tonics=modifiers.held_tonics
    if extra>0:unit.reset_supplies_spent=mini(2,extra)
    if not unit.boss and unit.job in ["Corsair","Ranger"]:unit.raider=true
  else:
   var condition=deployment_condition(game,unit)
   if condition.recovering:unit.hp=condition.hp;unit.potions=condition.tonics;unit.recovering=true
 if extra>0:
  var planner=preload("res://scripts/tactics.gd").new()
  var previous=game.phase;game.phase="enemy"
  for unit in game.units:
   if not unit.get("raider",false):continue
   var choice=planner.plan(game,unit)
   if choice.position!=game.pos(unit):game.move_unit(unit,choice.position)
   unit.acted=false;unit.moved=false;unit.erase("move_origin");unit.alerted=true
  game.phase=previous

func restart(game) -> bool:
 if game.units.is_empty() or game.completed:return false
 record_losses(game);game.commit_casualties()
 if flags.reset_pressure:
  pressure=mini(10,pressure+1)
  log_event("The enemy prepares for another attempt: pressure %d/10. Held tonics are spent; raiders advance before deployment."%pressure)
 if flags.section_restarts and game.permadeath:
  capture_section(game)
  var preserved=to_data();var deaths=game.roster.filter(func(unit):return unit.get("fallen",false)).duplicate(true)
  var permanent=game.permadeath;var actions=game.action_saves;var door=game.death_door
  if game.restore_save(checkpoint)!="camp":return false
  game.trials.from_data(preserved)
  game.permadeath=permanent;game.action_saves=actions;game.death_door=door
  for casualty in deaths:
   for recruit in game.roster:
    if recruit.id==casualty.id:recruit.fallen=true;recruit.fallen_chapter=casualty.fallen_chapter;recruit.hp=0
  game.deployed=game.available().slice(0,6).map(func(unit):return unit.id)
  queue_scene("retreat_"+str(game.chapter))
  log_event("The company withdraws to the start of section %d. The fallen remain lost; enemy preparations and legacy supplies remain."%(int(game.chapter/4)+1))
 else:
  if game.permadeath:game.supports.state=game.battle_supports.duplicate(true)
 game.units.clear();game.turn=1;game.phase="player"
 return true

func arrive(game):
 if not flags.section_restarts or not game.permadeath or game.chapter%4!=0 or game.completed:return
 queue_scene("relief_"+str(game.chapter))
 var names=[]
 for unit in game.roster:
  if unit.join>=game.chapter and unit.join<game.chapter+2 and not unit.get("fallen",false):
   if unit.id not in volunteers:volunteers.append(unit.id)
   names.append(unit.name)
 log_event("A new section begins. Relief columns reach the rally point: "+", ".join(names)+". The company carries its losses forward.")

func buy(game,id: String) -> bool:
 if not flags.death_legacies or not game.permadeath or id in purchases:return false
 for stock in LEGACY_STOCK:
  if stock.id==id and losses.size()>=stock.losses and credits>=stock.cost and game.equipment.any(func(item):return item.id==id):
   credits-=stock.cost;purchases.append(id);log_event("Legacy supplies secured: "+game.equipment.filter(func(item):return item.id==id)[0].name);return true
 return false

func to_data() -> Dictionary:
 return {"earned_scenes":earned_scenes.duplicate(),"read_scenes":read_scenes.duplicate(),"flags":flags.duplicate(),"pressure":pressure,"losses":losses.duplicate(),"injuries":injuries.duplicate(),"volunteers":volunteers.duplicate(),"purchases":purchases.duplicate(),"credits":credits,"events":events.duplicate(),"checkpoint":checkpoint.duplicate(true)}

func from_data(data: Dictionary):
 reset()
 if data.is_empty():return
 earned_scenes=data.get("earned_scenes",[]).duplicate();read_scenes=data.get("read_scenes",[]).duplicate()
 flags=data.flags.duplicate();pressure=int(data.pressure);losses=data.losses.duplicate();injuries=data.injuries.duplicate();volunteers=data.volunteers.duplicate();purchases=data.purchases.duplicate();credits=int(data.credits);events=data.events.duplicate();checkpoint=data.checkpoint.duplicate(true)

func valid(game,data) -> bool:
 if not data is Dictionary:return false
 if data.is_empty():return true
 for key in ["flags","pressure","losses","injuries","volunteers","purchases","credits","events","checkpoint"]:
  if not data.has(key):return false
 if not data.flags is Dictionary or data.flags.size()!=FLAGS.size():return false
 for key in FLAGS:
  if not data.flags.get(key) is bool:return false
 for key in ["pressure","credits"]:
  if not integer(data[key],0,10 if key=="pressure" else game.content.roster.size()):return false
 var ids=game.content.roster.map(func(unit):return unit.id)
 for key in ["losses","injuries"]:
  if not data[key] is Dictionary or data[key].size()>ids.size():return false
  for id in data[key]:
   var last_chapter=game.content.chapters.size()-(1 if key=="losses" else 0)
   if id not in ids or not integer(data[key][id],0,last_chapter):return false
 if data.losses.has("lyra"):return false
 for key in ["volunteers","purchases"]:
  if not data[key] is Array or data[key].size()>ids.size():return false
  var seen=[]
  for id in data[key]:
   if not id is String or id in seen:return false
   if id not in (ids if key=="volunteers" else LEGACY_STOCK.map(func(stock):return stock.id)):return false
   seen.append(id)
 var spent=0
 for id in data.purchases:
  var stock=LEGACY_STOCK.filter(func(item):return item.id==id)[0]
  if data.losses.size()<stock.losses:return false
  spent+=stock.cost
 if data.credits+spent!=data.losses.size():return false
 if not data.events is Array or data.events.size()>64:return false
 for event in data.events:
  if not event is String or event.length()>500:return false
 for key in ["earned_scenes","read_scenes"]:
  var entries=data.get(key,[])
  if not entries is Array or entries.size()>scenes.size():return false
  var seen=[]
  for id in entries:
   if not id is String or not scenes.has(id) or id in seen:return false
   if key=="read_scenes" and id not in data.get("earned_scenes",[]):return false
   seen.append(id)
 if not data.checkpoint is Dictionary:return false
 if not data.checkpoint.is_empty():
  if data.checkpoint.has("trials") or not game.valid_save(data.checkpoint):return false
  if data.checkpoint.stage!="camp" or not data.checkpoint.units.is_empty() or int(data.checkpoint.chapter)%4!=0:return false
 return true

func integer(value,minimum: int,maximum: int) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and value==int(value) and value>=minimum and value<=maximum
