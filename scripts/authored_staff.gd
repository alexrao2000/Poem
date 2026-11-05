extends Node3D
# Original staff, held in the right palm while the source's left hand gestures.
@export var handle_radius=.014
var equipped=""
var hold: SkeletonModifier3D
var grip_rotations={}

func _init():configure_equipment("staff","field_staff")

func configure_equipment(kind: String,item: String) -> String:
 if kind!="staff":return "The Warden study requires a staff"
 var painter=preload("res://scripts/fighters.gd").new();item=painter.EquipmentVisuals.resolve(kind,item)
 if equipped!=item:
  for child in get_children():remove_child(child);child.free()
  var weapon=painter.EquipmentVisuals.build(painter,self,kind,item)
  weapon.position=Vector3.ZERO;weapon.rotation.x=PI/2
  var crown=Marker3D.new();crown.name="Crown";weapon.add_child(crown);crown.position=Vector3(0,.78,0)
  equipped=item
 get_node("Weapon/StaffShaft").scale=Vector3(handle_radius/.022,1,handle_radius/.022)
 var anchor=get_parent() as BoneAttachment3D
 if anchor!=null:
  var rig=anchor.get_parent() as Skeleton3D
  if rig==null:return "Staff needs its hand skeleton"
  if hold==null:
   var chest=rig.get_bone_global_rest(rig.find_bone("spine_03"));var shoulder=rig.get_bone_global_rest(rig.find_bone("upperarm_r")).origin;var pelvis=rig.get_bone_global_rest(rig.find_bone("pelvis")).origin
   var goal=Transform3D(Basis(Vector3.RIGHT,Vector3.FORWARD,Vector3.UP),Vector3(shoulder.x-.09,pelvis.y+.18,.15))
   hold=preload("res://scripts/staff_hold.gd").new();hold.name="StaffSupport";rig.add_child(hold);hold.configure(rig,chest.affine_inverse()*goal)
  hold.fit_prop(anchor,get_node("Weapon"))
 return ""

func configure_animations(player: AnimationPlayer) -> String:
 var result=preload("res://scripts/authored_hand_pose.gd").configure(player,get_parent().get_parent(),.2,.1,grip_rotations)
 if result.error.is_empty():grip_rotations=result.rotations
 return result.error
