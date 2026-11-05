extends "res://tests/test_caster_framing.gd"
func _initialize():
 study_key="knight_male";character_id="oren";equipped_item="javelin";prop_path="Rig/Armature/Skeleton3D/WeaponHand/Grip/Weapon"
 extra_paths=["Rig/Armature/Skeleton3D/KnightShield","Rig/Armature/Skeleton3D/KnightCuirass"]
 pose_keys={"windup":"throw_windup","strike":"throw","recover":"throw_recover"}
 super()
