extends RefCounted
# A bounded, volatile diagnostic ledger. It neither saves nor restores rules.
const LIMIT=64
const UNIT_FIELDS=["name","team","job","promotion","item","hp","max_hp","level","xp","pow","defense","resistance","speed","move","reach","x","y","acted","moved","downed","bleed_turns","carried_by","recovering","resolve_until","potions","held_tonics"]
var baseline={}
var entries=[]
var sequence=0

func clear():
 baseline.clear();entries.clear();sequence=0

func capture(game,stage: String) -> Dictionary:
 var units={}
 for unit in game.units:
  var fields={}
  for key in UNIT_FIELDS:
   var value=unit.get(key)
   fields[key]=int(value) if value is float else value
  units[unit.id]=fields
 return {"stage":stage,"chapter":int(game.chapter)+1,"turn":int(game.turn),"phase":game.phase,"rng":str(game.rng.state),"units":units,"permadeath":game.permadeath,"action_saves":game.action_saves,"death_door":game.death_door,"trial_flags":game.trials.flags.duplicate(true),"pressure":int(game.trials.pressure),"credits":int(game.trials.credits),"casualties":game.lost_ids(true),"injuries":game.trials.injuries.duplicate(true),"volunteers":game.trials.volunteers.duplicate(),"purchases":game.trials.purchases.duplicate(),"bonds":game.supports.state.duplicate(true)}

func begin(game,stage: String):
 clear();baseline=capture(game,stage)

func observe(game,stage: String,reason: String,persistence: String):
 var current=capture(game,stage)
 if baseline.is_empty():baseline=current;return
 var changes={};var unit_changes=[]
 for key in current:
  if key not in ["units","rng"] and current[key]!=baseline[key]:changes[key]={"before":baseline[key],"after":current[key]}
 var ids=baseline.units.keys()
 for id in current.units:
  if id not in ids:ids.append(id)
 for id in ids:
  var previous=baseline.units.get(id,{});var next=current.units.get(id,{})
  var fields={}
  for key in UNIT_FIELDS:
   if previous.get(key)!=next.get(key):fields[key]={"before":previous.get(key),"after":next.get(key)}
  if not fields.is_empty():unit_changes.append({"id":id,"changes":fields})
 var saved_later=not entries.is_empty() and entries[-1].persistence in ["failed","not_requested"] and persistence=="written"
 var explicit_boundary=reason in ["import","reset_battle","load_chapter","return_to_camp","revive","test_pressure","train_company","set_seed","restore_experiment_checkpoint"] or reason.begins_with("experiment:") or reason.begins_with("encounter:")
 if changes.is_empty() and unit_changes.is_empty() and baseline.rng==current.rng and persistence!="failed" and not saved_later and not explicit_boundary:return
 sequence+=1
 entries.append({"sequence":sequence,"reason":reason,"chapter":current.chapter,"turn":current.turn,"phase":current.phase,"persistence":persistence,"rng_before":baseline.rng,"rng_after":current.rng,"changes":changes,"units":unit_changes})
 if entries.size()>LIMIT:entries.pop_front()
 baseline=current

func report() -> Dictionary:
 return {"volatile":true,"limit":LIMIT,"discarded":sequence-entries.size(),"entries":entries.duplicate(true)}
