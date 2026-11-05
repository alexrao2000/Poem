extends "res://tests/test_authored_framing.gd"
class EnemyModels:
 var models=preload("res://scripts/combat_models.gd").new("")
 func _init():
  var spec=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json")).enemy_duelist;spec.appearance="Identity"
  models.catalog={"characters":{"silas":spec}}
 func build(parent: Node3D,unit: Dictionary,position: Vector3):return models.build(parent,unit,position)
func create_models():return EnemyModels.new()
func _initialize():
 character_ids=["silas"];unit_team="enemy";equipped_items=["tempered_sword"]
 super()
