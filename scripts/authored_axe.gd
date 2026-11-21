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
 if finish_arm==null:
  finish_arm=preload("res://scripts/axe_finish.gd").new();finish_arm.name="AxeFinish";rig.add_child(finish_arm);finish_arm.setup(rig,self)

func configure_animations(player: AnimationPlayer) -> String:
 if not player.has_animation("Idle"):return "The axe rig needs its idle clip"
 var error=super(player)
 if not error.is_empty():return error
 return preload("res://scripts/sword_anticipation.gd").configure(player,get_parent().get_parent(),"AxeCriticalAttack",-.34,.10)

func additional_poses() -> Dictionary:
 return {"victory_flourish":{"clip":"AxeFinishFlourish","from":0.0,"to":.2},"critical_windup":{"clip":"AxeCriticalAttack","from":0.0,"to":.36},"critical_strike":{"clip":"AxeCriticalAttack","from":.36,"to":.433}}

func animation_pose(key: String) -> String:
 return "critical_strike" if key=="strike" and critical_prepared else key
