extends "res://tests/test_authored_framing.gd"
func create_models():return preload("helpers/enemy_study_models.gd").new("enemy_corsair","dax")
func _initialize():
 character_ids=["dax"];unit_team="enemy";equipped_items=["war_hammer"]
 super()
