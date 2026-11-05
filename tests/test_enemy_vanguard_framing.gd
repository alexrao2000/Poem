extends "res://tests/test_authored_framing.gd"
func create_models():return preload("helpers/enemy_study_models.gd").new("enemy_vanguard","cassian")
func _initialize():
 character_ids=["cassian"];unit_team="enemy";equipped_items=["tempered_sword"]
 super()
