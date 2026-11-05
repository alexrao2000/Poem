extends Node3D
# Original Poem weapon fitted to the source rig's palm. Kept separate from the
# licensed mesh; fitted handle width preserves the blade, guard and trail sockets.
@export var handle_radius=.014
var equipped=""
var grip_rotations={}
func _init():configure_equipment("sword","iron_sword")

func configure_equipment(kind: String,item: String) -> String:
 if kind!="sword":return "The duelist rig requires a sword"
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

func configure_animations(player: AnimationPlayer) -> String:
 fit_handle()
 var anchor=get_parent() as BoneAttachment3D
 var rig=anchor.get_parent() as Skeleton3D if anchor!=null else null
 var result=preload("res://scripts/authored_hand_pose.gd").configure(player,rig,.2,.1,grip_rotations)
 if result.error.is_empty():grip_rotations=result.rotations
 return result.error

static func finger_names() -> Array[String]:return preload("res://scripts/authored_hand_pose.gd").names()
