extends "res://tests/test_caster_framing.gd"
func create_models():return preload("helpers/enemy_study_models.gd").new(study_key,character_id)
func _initialize():
 study_key="enemy_knight";character_id="oren";unit_team="enemy";equipped_item="riders_bane";prop_path="Rig/Armature/Skeleton3D/WeaponHand/Grip/Weapon"
 combat_spacing=2.1;ranged=false
 extra_paths=["Rig/Armature/Skeleton3D/KnightShield","Rig/Armature/Skeleton3D/KnightCuirass"]
 super()
