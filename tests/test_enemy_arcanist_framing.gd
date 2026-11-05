extends "res://tests/test_caster_framing.gd"
func create_models():return preload("helpers/enemy_study_models.gd").new(study_key,character_id)
func _initialize():
 study_key="enemy_arcanist";character_id="vela";unit_team="enemy";equipped_item="thunder";prop_path="Rig/Armature/Skeleton3D/BookHand/Folio/Weapon"
 super()
