extends RefCounted
# Temporary presentation comparison. Never alter the normal catalog or roster.
var models=preload("res://scripts/combat_models.gd").new("")

func _init():
 var studies=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json"))
 models.catalog={"characters":{}}
 for pair in [["nell","female"],["silas","male"]]:
  var spec=studies[pair[1]].duplicate(true);spec.appearance="Identity"
  models.catalog.characters[pair[0]]=spec

func build(parent: Node3D,unit: Dictionary,position: Vector3) -> Node3D:
 if unit.get("team","")!="player" or unit.get("job","")!="Duelist" or unit.get("weapon","")!="sword" or not str(unit.get("promotion","")).is_empty():return null
 return models.build(parent,unit,position)
