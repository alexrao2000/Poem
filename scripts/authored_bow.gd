extends Node3D
# Original bow geometry and private source-hand poses. Source breathing/gait
# remain; four private clips drive the fitted draw, release and recovery.
@export var handle_radius=.014
var equipped=""
var finger_pad=Vector3(.015,.075,0)
var hand_draw=0.0
var lift=0.0
var draw=0.0:
 set(value):draw=value;update_string()
var holding=true
var projectile_spent=false
var arms: SkeletonModifier3D
var grip_rotations={}
func _init():configure_equipment("bow","scout_bow")
func configure_equipment(kind: String,item: String) -> String:
 if kind!="bow":return "The Ranger study requires a bow"
 var painter=preload("res://scripts/fighters.gd").new();item=painter.EquipmentVisuals.resolve(kind,item)
 if equipped!=item:
  for child in get_children():remove_child(child);child.free()
  var weapon=painter.EquipmentVisuals.build(painter,self,kind,item);weapon.position=Vector3.ZERO;weapon.rotation=Vector3(PI/2,0,0)
  equipped=item
 var look=painter.EquipmentVisuals.profiles[item]
 get_node("Weapon/BowGrip").scale=Vector3(handle_radius/(look.thickness*1.4),1,handle_radius/(look.thickness*1.4))
 for index in [5,6]:get_node("Weapon/BowLimb"+str(index)).scale=Vector3(handle_radius/look.thickness,1,handle_radius/look.thickness)
 var anchor=get_parent() as BoneAttachment3D
 if anchor!=null and arms==null:
  arms=preload("res://scripts/bow_hold.gd").new();arms.name="BowArms";anchor.get_parent().add_child(arms);arms.setup(anchor.get_parent(),self)
 if arms!=null:arms.fit_prop(anchor,get_node("Weapon"))
 update_string()
 return ""
func update_string():
 if not has_node("Weapon/NockedArrow"):return
 var weapon=get_node("Weapon");var nock=Vector3(0,0,.22+.30*draw)
 weapon.get_node("NockedArrow").position=nock-Vector3(0,0,preload("res://scripts/combat_projectile.gd").ARROW_LENGTH*.5)
 for i in range(2):
  var segment=weapon.get_node("BowStringTop" if i==0 else "BowStringBottom");var height=weapon.get_meta("bow_height",.45);var tip=Vector3(0,height if i==0 else -height,.22)
  segment.position=(nock+tip)*.5;segment.quaternion=Quaternion(Vector3.UP,(tip-nock).normalized());segment.scale=Vector3(1,tip.distance_to(nock),1)
func configure_animations(player: AnimationPlayer) -> String:
 var result=preload("res://scripts/authored_hand_pose.gd").configure(player,get_parent().get_parent(),.2,.1,grip_rotations)
 if not result.error.is_empty():return result.error
 grip_rotations=result.rotations
 var rig=get_parent().get_parent();var original=[]
 for bone in range(rig.get_bone_count()):original.append([rig.get_bone_pose_position(bone),rig.get_bone_pose_rotation(bone),rig.get_bone_pose_scale(bone)])
 player.play("Sword_Idle");player.seek(0,true,true);player.pause();rig.force_update_all_bone_transforms()
 var mirror=Basis.from_scale(Vector3(-1,1,1));var hand=rig.get_bone_global_pose(rig.find_bone("hand_r"));var left_rotations={}
 for digit in ["thumb","index","middle","ring","pinky"]:
  var parent_basis=Basis.IDENTITY
  for part in ["01","02","03"]:
   var bone=rig.find_bone(digit+"_"+part+"_r");var left_bone=rig.find_bone(digit+"_"+part+"_l")
   var relative=(hand.affine_inverse()*rig.get_bone_global_pose(bone)).basis
   var desired=mirror*relative*mirror
   var local=(parent_basis.inverse()*desired).get_rotation_quaternion().normalized();parent_basis=desired
   left_rotations[digit+"_"+part+"_l"]=local
   rig.set_bone_pose_rotation(left_bone,local)
 rig.force_update_all_bone_transforms()
 var left_hand=rig.get_bone_global_pose(rig.find_bone("hand_l"))
 finger_pad=Vector3.ZERO
 for name_value in ["index_04_leaf_l","middle_04_leaf_l"]:finger_pad+=left_hand.affine_inverse()*rig.get_bone_global_pose(rig.find_bone(name_value)).origin*.5
 for bone in range(rig.get_bone_count()):rig.set_bone_pose_position(bone,original[bone][0]);rig.set_bone_pose_rotation(bone,original[bone][1]);rig.set_bone_pose_scale(bone,original[bone][2])
 player.stop()
 var library=player.get_animation_library("")
 for setup in [["BowIdle",0,0,0,0],["BowDraw",0,1,0,1],["BowRelease",1,1,1,0],["BowRecover",1,0,0,0]]:
  var animation=player.get_animation("Idle").duplicate(true)
  if setup[0]!="BowIdle":animation.length=1
  for pair in [["lift",setup[1],setup[2]],["draw",setup[3],setup[4]],["hand_draw",1 if setup[0]=="BowRecover" else setup[3],1 if setup[0]=="BowRelease" else setup[4]]]:
   var track=animation.add_track(Animation.TYPE_VALUE);animation.track_set_path(track,NodePath("Armature/Skeleton3D/WeaponHand/Bow:"+pair[0]));animation.track_insert_key(track,0,float(pair[1]));animation.track_insert_key(track,1,float(pair[2]))
  for track in range(animation.get_track_count()-1,-1,-1):
   var path=animation.track_get_path(track)
   if animation.track_get_type(track)==Animation.TYPE_ROTATION_3D and path.get_subname_count()==1 and left_rotations.has(str(path.get_subname(0))):animation.remove_track(track)
  for name_value in left_rotations:
   var track=animation.add_track(Animation.TYPE_ROTATION_3D);animation.track_set_path(track,NodePath("Armature/Skeleton3D:"+name_value));var rest=rig.get_bone_rest(rig.find_bone(name_value)).basis.get_rotation_quaternion()
   animation.track_insert_key(track,0,left_rotations[name_value] if setup[0]=="BowRelease" else rest)
   animation.track_insert_key(track,1,left_rotations[name_value] if setup[0]=="BowDraw" else rest)
  if library.has_animation(setup[0]):library.remove_animation(setup[0])
  library.add_animation(setup[0],animation)
 return ""
func combat_pose(key: String):
 holding=key not in ["down","hit","critical_hit","evade"]
 if key not in ["windup","critical_windup","strike","recover"]:draw=0;lift=0;hand_draw=0
 if key in ["idle","advance","windup","critical_windup","victory"]:projectile_spent=false
 get_node("Weapon/NockedArrow").visible=holding and not projectile_spent

func aim_at(point: Vector3):
 if arms!=null and point.is_finite():arms.aim_point=point;arms.has_aim=true

func release_projectile():
 projectile_spent=true;get_node("Weapon/NockedArrow").hide()

func pose_finished(key: String):
 if key=="strike":release_projectile()
