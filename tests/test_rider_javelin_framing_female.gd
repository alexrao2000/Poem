extends "res://tests/test_caster_framing.gd"
func _initialize():
 study_key="rider_female";character_id="una";equipped_item="javelin";prop_path="Rig/Armature/Skeleton3D/WeaponHand/Grip/Weapon"
 mounted_subject=true;combat_spacing=4.0;ranged=true;extra_paths=["Mount","Rig/Armature/Skeleton3D/KnightCuirass"]
 pose_keys={"windup":"throw_windup","strike":"throw","recover":"throw_recover"}
 super()
