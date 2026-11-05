extends "res://tests/test_caster_framing.gd"
func create_models():return preload("helpers/enemy_study_models.gd").new(study_key,character_id)
func _initialize():
 study_key="enemy_knight";character_id="oren";unit_team="enemy";equipped_item="javelin";prop_path="Rig/Armature/Skeleton3D/WeaponHand/Grip/Weapon"
 extra_paths=["Rig/Armature/Skeleton3D/KnightShield","Rig/Armature/Skeleton3D/KnightCuirass"]
 pose_keys={"windup":"throw_windup","strike":"throw","recover":"throw_recover"}
 super()
