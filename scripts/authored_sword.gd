extends Node3D
# Original Poem weapon fitted to the source rig's palm. Kept separate from the
# licensed mesh; fitted handle width preserves the blade, guard and trail sockets.
@export var handle_radius=.014
var equipped=""
var grip_rotations={}
var thrust_arm: SkeletonModifier3D
var finish_arm: SkeletonModifier3D
var critical_prepared=false
func equipment_kind() -> String:return "sword"
func _init():configure_equipment(equipment_kind(),"")

func configure_equipment(kind: String,item: String) -> String:
 if kind!=equipment_kind():return "The rig requires a "+equipment_kind()
 var painter=preload("res://scripts/fighters.gd").new()
 item=painter.EquipmentVisuals.resolve(kind,item)
 if equipped==item:fit_handle();return ""
 for child in get_children():remove_child(child);child.free()
 var weapon=painter.EquipmentVisuals.build(painter,self,kind,item)
 weapon.position=Vector3(0,0,-.08);weapon.rotation.y=PI
 var edge=painter.EquipmentVisuals.trail_edge(kind,item)
 for index in range(2):
  var marker=Marker3D.new();marker.name="TrailInner" if index==0 else "TrailTip"
  weapon.add_child(marker);marker.position=edge[index]
 equipped=item;fit_handle()
 return ""


func fit_handle():
 if not has_node("Weapon/WeaponGrip"):return
 get_node("Weapon/WeaponGrip").scale=Vector3(handle_radius/.027,1,handle_radius/.027)
 if equipped=="estoc" and get_parent() is BoneAttachment3D and thrust_arm==null:
  thrust_arm=preload("res://scripts/estoc_hold.gd").new();thrust_arm.name="EstocArm";get_parent().get_parent().add_child(thrust_arm);thrust_arm.setup(get_parent().get_parent(),self)
 if equipment_kind()=="sword" and get_parent() is BoneAttachment3D and finish_arm==null:
  finish_arm=preload("res://scripts/sword_finish.gd").new();finish_arm.name="SwordFinish";get_parent().get_parent().add_child(finish_arm);finish_arm.setup(get_parent().get_parent(),self)

func configure_animations(player: AnimationPlayer) -> String:
 fit_handle()
 var anchor=get_parent() as BoneAttachment3D
 var rig=anchor.get_parent() as Skeleton3D if anchor!=null else null
 if equipment_kind()=="sword" and (not player.has_animation("Idle") or not player.has_animation("Sword_Attack")):return "The sword rig needs its idle and attack clips"
 var result=preload("res://scripts/authored_hand_pose.gd").configure(player,rig,.2,.1,grip_rotations)
 if result.error.is_empty():grip_rotations=result.rotations
 if result.error.is_empty() and thrust_arm!=null:thrust_arm.configure_animations(player)
 if result.error.is_empty() and finish_arm!=null:finish_arm.configure_animations(player)
 if result.error.is_empty() and equipment_kind()=="sword":result.error=preload("res://scripts/sword_anticipation.gd").configure(player,rig)
 return result.error

func additional_poses() -> Dictionary:
 return {"victory_flourish":{"clip":"SwordFinishFlourish","from":0.0,"to":.2},"critical_windup":{"clip":"SwordCriticalAttack","from":0.0,"to":.36},"critical_strike":{"clip":"SwordCriticalAttack","from":.36,"to":.433}} if finish_arm!=null else {}

func combat_pose(key: String):
 if key=="critical_windup":critical_prepared=true
 elif key not in ["strike","recover"]:critical_prepared=false

func animation_pose(key: String) -> String:
 return "critical_strike" if equipment_kind()=="sword" and key=="strike" and critical_prepared else key

func handles_contact() -> bool:return thrust_arm!=null

func point_trail_width() -> float:return .032 if equipped=="estoc" else 0.0

static func finger_names() -> Array[String]:return preload("res://scripts/authored_hand_pose.gd").names()
