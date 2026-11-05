extends "res://tests/test_rider_gait.gd"
func _initialize():
 pairs=[["enemy","bram"]]
 super()
func create_models(pair):return preload("res://tests/helpers/enemy_study_models.gd").new("enemy_rider",pair[1])
