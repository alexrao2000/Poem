extends "res://tests/test_caster_framing.gd"
func create_models():return preload("helpers/enemy_study_models.gd").new(study_key,character_id)
func _initialize():
 study_key="enemy_ranger";character_id="ari";unit_team="enemy";equipped_item="longbow";prop_path="Rig/Armature/Skeleton3D/WeaponHand/Bow/Weapon"
 super()
