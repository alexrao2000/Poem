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
 # These are already-private adapter copies. Fit the supplied sword-ready
 # fist around the narrower hilt, then retain it through unarmed fall clips.
 if not player.has_animation("Sword_Idle"):return "Equipped sword needs its source grip pose"
 fit_handle()
 var anchor=get_parent() as BoneAttachment3D
 var rig=anchor.get_parent() as Skeleton3D if anchor!=null else null
 if rig==null:return "Equipped grip needs its source hand skeleton"
 var source=player.get_animation("Sword_Idle");var fingers=grip_rotations.duplicate();var names=finger_names()
 for track in range(source.get_track_count()):
  var path=source.track_get_path(track)
  if source.track_get_type(track)!=Animation.TYPE_ROTATION_3D or path.get_subname_count()!=1:continue
  var name_value=str(path.get_subname(0))
  if name_value in names and not fingers.has(path) and source.track_get_key_count(track)>0:
   var rotation: Quaternion=source.track_get_key_value(track,0)
   var rest=rig.get_bone_rest(rig.find_bone(name_value)).basis.get_rotation_quaternion()
   fingers[path]=rotation.slerp(rest,.1 if name_value.begins_with("thumb") else .2)
 if fingers.size()!=15:return "Equipped sword needs all fifteen right-finger joints"
 grip_rotations=fingers.duplicate()
 for clip in player.get_animation_list():
  var animation=player.get_animation(clip)
  for track in range(animation.get_track_count()-1,-1,-1):
   if animation.track_get_type(track)==Animation.TYPE_ROTATION_3D and fingers.has(animation.track_get_path(track)):animation.remove_track(track)
  for path in fingers:
   var track=animation.add_track(Animation.TYPE_ROTATION_3D);animation.track_set_path(track,path);animation.track_insert_key(track,0.0,fingers[path])
 return ""

static func finger_names() -> Array[String]:
 var result: Array[String]=[]
 for digit in ["thumb","index","middle","ring","pinky"]:
  for part in ["01","02","03"]:result.append(digit+"_"+part+"_r")
 return result
