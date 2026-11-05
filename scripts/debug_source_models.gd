extends RefCounted
# Opt-in model comparisons share fitted rigs across named recruits of the same
# original class, while each actor configures its own identity and equipment.
# Promotion costumes, enemies and unsupported weapons retain the normal builder.
var models=preload("res://scripts/combat_models.gd").new("")
var identities: Dictionary={}

func _init(study_ids: Array):
 var studies=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json"))
 var roster=JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign.json")).roster
 models.catalog={"characters":{}}
 for key in study_ids:
  var spec=studies[key].duplicate(true);spec.appearance="Identity"
  var source=roster.filter(func(unit):return unit.id==spec.study_character)[0]
  for id in spec.get("campaign_characters",[spec.study_character]):
   var recruits=roster.filter(func(unit):return unit.id==id)
   if recruits.is_empty() or recruits[0].job!=source.job or recruits[0].weapon!=source.weapon:
    models.report("Incompatible revised character: "+str(id));continue
   identities[id]={"job":source.job,"weapon":source.weapon}
   models.catalog.characters[id]=spec.duplicate(true)

func build(parent: Node3D,unit: Dictionary,position: Vector3) -> Node3D:
 var identity=identities.get(unit.get("id",""),{})
 if identity.is_empty() or unit.get("team","")!="player" or not str(unit.get("promotion","")).is_empty():return null
 if unit.get("job","")!=identity.job or unit.get("weapon","")!=identity.weapon:return null
 return models.build(parent,unit,position)
