extends RefCounted
# Opt-in model comparisons share fitted rigs across named recruits of the same
# original class, while each actor configures its own identity and equipment.
# Only explicitly fitted promotion costumes are eligible; other outfits,
# enemies and unsupported weapons retain the normal builder.
var models=preload("res://scripts/combat_models.gd").new("")
var identities: Dictionary={}

func _init(study_ids: Array):
 var studies=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json"))
 var campaign=JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign.json"))
 var roster=campaign.roster+campaign.legacy_recruits.map(func(legacy):return legacy.unit)
 models.catalog={"characters":{}}
 for key in study_ids:
  var spec=studies[key].duplicate(true);spec.appearance="Identity"
  if spec.has("study_enemy_class"):
   models.report("Enemy studies cannot replace company recruits: "+str(key));continue
  var source=roster.filter(func(unit):return unit.id==spec.study_character)[0]
  for id in spec.get("campaign_characters",[spec.study_character]):
   var recruits=roster.filter(func(unit):return unit.id==id)
   if recruits.is_empty() or recruits[0].job!=source.job or recruits[0].weapon!=source.weapon:
    models.report("Incompatible revised character: "+str(id));continue
   identities[id]={"job":source.job,"weapon":source.weapon}
   models.catalog.characters[id]=spec.duplicate(true)

func accepts(unit: Dictionary) -> bool:
 var identity=identities.get(unit.get("id",""),{})
 if identity.is_empty() or unit.get("team","")!="player":return false
 var promotion=str(unit.get("promotion",""))
 if not promotion.is_empty() and promotion not in models.catalog.characters[unit.id].get("supported_promotions",[]):return false
 return unit.get("job","")==identity.job and unit.get("weapon","")==identity.weapon

func prefetch(unit: Dictionary):
 if accepts(unit):models.prefetch(unit)

func build(parent: Node3D,unit: Dictionary,position: Vector3) -> Node3D:
 if not accepts(unit):return null
 return models.build(parent,unit,position)
