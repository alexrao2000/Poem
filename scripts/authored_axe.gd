extends "res://scripts/authored_sword.gd"
# Original axes share the source palm fit and finger pose with the sword rig.
var floor_fit: SkeletonModifier3D
func equipment_kind() -> String:return "axe"

func fit_handle():
 super()
 if not has_node("Weapon/AxeShaft"):return
 get_node("Weapon/AxeShaft").scale=Vector3(handle_radius/.029,1,handle_radius/.029)
 var anchor=get_parent() as BoneAttachment3D
 if anchor==null:return
 var rig=anchor.get_parent() as Skeleton3D
 if floor_fit==null:
  floor_fit=preload("res://scripts/weapon_floor.gd").new();floor_fit.name="WeaponFloor";rig.add_child(floor_fit);floor_fit.configure(rig,Transform3D.IDENTITY)
 floor_fit.fit_prop(anchor,get_node("Weapon"))
