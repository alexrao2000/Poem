extends RefCounted
# Debug experiments use a separate save slot. Leaving restores the exact live
# campaign snapshot, including unsaved progress, rule toggles and RNG state.
const Rules=preload("res://scripts/rules.gd")
const MODEL_FLAGS=["revised_vanguard","revised_duelists","revised_caster","revised_warden","revised_corsair","revised_ranger","revised_knight","revised_rider","revised_enemies"]

var combat_seed=Rules.DEFAULT_COMBAT_SEED
var active=false
var revised_duelists=false
var revised_caster=false
var revised_vanguard=false
var revised_warden=false
var revised_corsair=false
var revised_ranger=false
var revised_knight=false
var revised_rider=false
var revised_enemies=false
var checkpoint: Dictionary={}
var experiment_checkpoint: Dictionary={}
var return_screen="title"
var trace=preload("res://scripts/debug_trace.gd").new()

func begin(game,screen: String,revised_models=false):
 if active:return
 return_screen=screen;combat_seed=Rules.DEFAULT_COMBAT_SEED
 for field in MODEL_FLAGS:set(field,revised_models)
 checkpoint=game.save_data("battle" if screen=="battle" else "camp").duplicate(true)
 active=true
 trace.begin(game,"battle" if screen=="battle" else "camp")

func end(game) -> String:
 if not active:return return_screen
 if _restore_checkpoint(game,checkpoint).is_empty():return return_screen
 active=false;checkpoint.clear();experiment_checkpoint.clear()
 for field in MODEL_FLAGS:set(field,false)
 trace.clear()
 return return_screen

func capture_experiment(game,stage: String) -> bool:
 if not active or stage not in ["battle","camp"]:return false
 var snapshot=game.save_data(stage).duplicate(true)
 if not game.valid_save(snapshot):return false
 experiment_checkpoint={"snapshot":snapshot,"seed":combat_seed}
 return true

func restore_experiment(game) -> String:
 if not active or experiment_checkpoint.is_empty():return ""
 var stage=_restore_checkpoint(game,experiment_checkpoint.snapshot)
 if not stage.is_empty():combat_seed=experiment_checkpoint.seed
 return stage

func _restore_checkpoint(game,snapshot: Dictionary) -> String:
 var stage=game.restore_save(snapshot)
 if not stage.is_empty() and stage==snapshot.stage:
  game.roster=snapshot.roster.duplicate(true);game.units=snapshot.units.duplicate(true)
 return stage

func observe(game,stage: String,reason: String,persistence: String):
 if active:trace.observe(game,stage,reason,persistence)

func model_choice() -> String:
 var enabled=MODEL_FLAGS.filter(func(field):return get(field)).size()
 return "current" if enabled==0 else "revised" if enabled==MODEL_FLAGS.size() else "mixed"

func set_revised_models(enabled: bool) -> bool:
 if not active:return false
 for field in MODEL_FLAGS:set(field,enabled)
 return true

func set_revised_duelists(enabled: bool) -> bool:
 if not active:return false
 revised_duelists=enabled;return true

func set_revised_caster(enabled: bool) -> bool:
 if not active:return false
 revised_caster=enabled;return true

func set_revised_vanguard(enabled: bool) -> bool:
 if not active:return false
 revised_vanguard=enabled;return true

func set_revised_warden(enabled: bool) -> bool:
 if not active:return false
 revised_warden=enabled;return true

func set_revised_corsair(enabled: bool) -> bool:
 if not active:return false
 revised_corsair=enabled;return true

func set_revised_ranger(enabled: bool) -> bool:
 if not active:return false
 revised_ranger=enabled;return true

func set_revised_knight(enabled: bool) -> bool:
 if not active:return false
 revised_knight=enabled;return true

func set_revised_enemies(enabled: bool) -> bool:
 if not active:return false
 revised_enemies=enabled;return true

func set_revised_rider(enabled: bool) -> bool:
 if not active:return false
 revised_rider=enabled;return true

func load_chapter(game,index: int):
 if not active or index<0 or index>=game.content.chapters.size():return
 var door=game.death_door;var actions=game.action_saves;var flags=game.trials.flags.duplicate()
 game.new_campaign(game.permadeath);game.death_door=door;game.action_saves=actions;game.trials.flags=flags;game.chapter=index
 game.story_seen=["opening_"+str(index)]
 game.deployed=game.available().slice(0,6).map(func(unit):return unit.id)
 reset_battle(game)

func heal(game):
 if not active:return
 for unit in game.living("player"):unit.hp=unit.max_hp

func revive(game):
 if not active:return
 for unit in game.roster:unit.fallen=false;unit.fallen_chapter=-1;unit.hp=unit.max_hp
 for unit in game.available():
  if game.deployed.size()<6 and unit.id not in game.deployed:game.deployed.append(unit.id)
 reset_battle(game)

func set_combat_seed(game,value) -> bool:
 if not active or not game.trials.integer(value,0,2147483647):return false
 combat_seed=int(value);game.rng.seed=combat_seed
 return true

func reset_battle(game):
 if not active:return
 game.rng.seed=combat_seed;game.start_battle()

func start_experiment(game,id: String) -> bool:
 if not active:return false
 return preload("res://scripts/debug_experiments.gd").start(game,id,combat_seed)

func start_encounter(game,id: String) -> Dictionary:
 if not active:return {}
 return preload("res://scripts/debug_encounters.gd").start(game,id,combat_seed)

func start_recruit_encounter(game,recruit_id: String,promotion_id="",item_id="",chapter=-1,commander=false) -> Dictionary:
 if not active:return {}
 return preload("res://scripts/debug_encounters.gd").start_recruit(game,recruit_id,promotion_id,combat_seed,item_id,chapter,commander)

func test_pressure(game,value) -> bool:
 if not active or not game.trials.integer(value,0,10):return false
 game.trials.flags.reset_pressure=true;game.trials.pressure=int(value)
 reset_battle(game)
 return true

func train_company(game,value) -> bool:
 if not active or not game.trials.integer(value,1,game.MAX_LEVEL):return false
 for unit in game.available():
  if unit.level<value:game.award_xp(unit,(int(value)-int(unit.level))*100-int(unit.xp))
 reset_battle(game)
 return true

func fall_unit(game,id: String) -> bool:
 if not active:return false
 var candidates=game.living("player").filter(func(unit):return unit.id==id)
 if candidates.is_empty():return false
 var unit=candidates[0];unit.hp=0;game.DeathDoor.fall(game,unit);game.commit_casualties()
 return true

func set_bleed_turns(game,id: String,value) -> bool:
 if not active or not game.trials.integer(value,1,2):return false
 var candidates=game.units.filter(func(unit):return unit.id==id and game.DeathDoor.downed(unit) and unit.get("carried_by","").is_empty())
 if candidates.is_empty():return false
 candidates[0].bleed_turns=int(value)
 return true

func report(game,stage="battle") -> Dictionary:
 if not active:return {}
 var settings=game.trials.flags.duplicate()
 settings.permadeath=game.permadeath;settings.action_saves=game.action_saves;settings.death_door=game.death_door
 var combatants=[]
 for unit in game.units:
  combatants.append({"id":unit.id,"name":unit.name,"team":unit.team,"class":game.class_name_for(unit),"position":[unit.x,unit.y],"hp":unit.hp,"max_hp":unit.max_hp,"attack":game.attack_power(unit),"defense":unit.defense,"resistance":game.resistance_for(unit),"speed":game.attack_speed(unit),"equipment":unit.item,"level":unit.level,"xp":unit.xp,"acted":unit.acted,"downed":unit.get("downed",false),"bleed_turns":unit.get("bleed_turns",0),"carried_by":unit.get("carried_by",""),"tonics":unit.get("potions",unit.get("held_tonics",0))})
 var result={"report_version":2,"recent_actions":trace.report(),"debug":true,"chapter":game.chapter+1,"title":game.info().title,"section":game.trials.section_index(game.chapter)+1,"turn":game.turn,"phase":game.phase,"outcome":game.result() if stage=="battle" and not game.units.is_empty() else "preparation","settings":settings,"seed_for_new_attempts":combat_seed,"rng_state":str(game.rng.state),"pressure":game.trials.pressure,"next_deployment_enemy_bonuses":game.trials.enemy_modifiers(game.chapter),"casualties":game.lost_ids(true),"legacy_credits":game.trials.credits,"dispatches":game.trials.events.duplicate(),"combatants":combatants,"save_code":game.export_code(stage)}
 if stage=="battle" and settings.reset_pressure:
  var preview=retry_deployment(game.save_data("battle"),false,game.content)
  if not preview.is_empty():result.retry_deployment=preview
 return result

func retry_deployment(snapshot: Dictionary,compare_current=false,content={}) -> Dictionary:
 var retry=Rules.new(content)
 if retry.restore_save(snapshot)!="battle":return {}
 var reference_pressure=retry.trials.pressure if compare_current else 0
 if not retry.trials.restart(retry):return {}
 var reference=Rules.new(content)
 if reference.restore_save(retry.save_data("camp"))!="camp":return {}
 reference.trials.pressure=reference_pressure
 reference.start_battle()
 retry.start_battle()
 return compare_deployments(reference,retry)

static func compare_deployments(reference,prepared) -> Dictionary:
 var baseline={}
 for enemy in reference.living("enemy"):baseline[enemy.id]=enemy_deployment(reference,enemy)
 var enemies=[]
 for enemy in prepared.living("enemy"):
  enemies.append({"id":enemy.id,"name":enemy.name,"raider":enemy.get("raider",false),
   "before":baseline[enemy.id],"after":enemy_deployment(prepared,enemy)})
 var result={"chapter":prepared.chapter+1,"pressure":prepared.trials.pressure,"reference_pressure":reference.trials.pressure,"enemies":enemies}
 if prepared.enemy_waves.is_empty():return result
 var waiting={}
 for wave in reference.enemy_waves:waiting[wave.unit.id]=enemy_deployment(reference,wave.unit)
 var reserves=[]
 for wave in prepared.enemy_waves:
  var unit=wave.unit
  reserves.append({"id":unit.id,"name":unit.name,"raider":false,
   "arrival":{"turn":wave.turn,"phase":wave.phase,"arrive_on_defense":wave.get("arrive_on_defense",false)},
   "before":waiting[unit.id],"after":enemy_deployment(prepared,unit)})
 result.reserves=reserves
 return result

static func enemy_deployment(game,enemy: Dictionary) -> Dictionary:
 return {"position":[enemy.x,enemy.y],"hp":enemy.hp,"attack":game.attack_power(enemy),
  "speed":game.attack_speed(enemy),"defense":enemy.defense,"held_tonics":enemy.get("held_tonics",0)}
