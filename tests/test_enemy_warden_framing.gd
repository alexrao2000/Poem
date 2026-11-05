extends "res://tests/test_caster_framing.gd"
func create_models():return preload("helpers/enemy_study_models.gd").new(study_key,character_id)
func _initialize():
 study_key="enemy_warden";character_id="esme";unit_team="enemy";equipped_item="beacon_staff";prop_path="Rig/Armature/Skeleton3D/WeaponHand/Staff/Weapon"
 super()
