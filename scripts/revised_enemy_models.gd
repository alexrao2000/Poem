extends RefCounted
# Enemy appearance is opt-in and independent of company selection. Known
# commanders retain their individual palettes; unknown bosses and promotions
# keep the original builder instead of silently acquiring an anonymous look.
const Commanders=preload("res://scripts/commanders.gd")
var models=preload("res://scripts/combat_models.gd").new("")
var weapons={}
func _init():
 var studies=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json"))
 var roster=JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign.json")).roster
 models.catalog={"enemy_classes":{}}
 for entry in studies.values():
  if not entry.has("study_enemy_class"):continue
  var source=roster.filter(func(unit):return unit.id==entry.study_character)
  if source.size()!=1 or source[0].job!=entry.study_enemy_class:
   models.report("Incompatible revised enemy class: "+str(entry.study_enemy_class));continue
  var spec=entry.duplicate(true);spec.appearance="Identity"
  weapons[entry.study_enemy_class]=source[0].weapon
  models.catalog.enemy_classes[entry.study_enemy_class]=spec
func build(parent: Node3D,unit: Dictionary,position: Vector3) -> Node3D:
 if unit.get("team","")!="enemy" or not str(unit.get("promotion","")).is_empty():return null
 var commander=Commanders.profile(unit)
 if unit.get("boss",false) and commander.is_empty():return null
 var job=unit.get("job","")
 if not weapons.has(job) or weapons[job]!=unit.get("weapon",""):return null
 return models.build(parent,unit,position)
