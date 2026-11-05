extends RefCounted
var models=preload("res://scripts/combat_models.gd").new("")
func _init(study: String,id: String):
 var spec=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json"))[study].duplicate(true);spec.appearance="Identity"
 models.catalog={"characters":{id:spec}}
func build(parent: Node3D,unit: Dictionary,position: Vector3):return models.build(parent,unit,position)
