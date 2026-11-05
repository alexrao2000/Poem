extends "res://scripts/authored_sword.gd"
var arms: SkeletonModifier3D
var lift=0.0
var thrust=0.0
var holding=true
var fall=0.0
var throwing=false
var recovering=false
var throw_raise=0.0
var throw_push=0.0
func equipment_kind() -> String:return "lance"
func fit_handle():
 super()
 if not has_node("Weapon"):return
 get_node("Weapon").position.z=.25
 get_node("Weapon/WeaponGrip").position.z=.25
 get_node("Weapon/LanceShaft").scale=Vector3(handle_radius/.024,1,handle_radius/.024)
 var anchor=get_parent() as BoneAttachment3D
 if anchor!=null and arms==null:
  arms=load("res://scripts/lance_hold.gd").new();arms.name="LanceArm";anchor.get_parent().add_child(arms);arms.setup(anchor.get_parent(),self)
 if arms!=null:arms.fit_prop(anchor,get_node("Weapon"))
func configure_animations(player: AnimationPlayer) -> String:
 var error=super(player)
 if not error.is_empty():return error
 var library=player.get_animation_library("")
 for setup in [["LanceIdle",0,0,0,0],["LanceWindup",0,1,0,0],["LanceStrike",1,1,0,1],["LanceRecover",1,0,1,0]]:
  var animation=player.get_animation("Idle").duplicate(true)
  if setup[0]!="LanceIdle":animation.length=1
  for pair in [["lift",setup[1],setup[2]],["thrust",setup[3],setup[4]]]:
   var track=animation.add_track(Animation.TYPE_VALUE);animation.track_set_path(track,NodePath("Armature/Skeleton3D/WeaponHand/Grip:"+pair[0]));animation.track_insert_key(track,0,float(pair[1]));animation.track_insert_key(track,1,float(pair[2]))
  if library.has_animation(setup[0]):library.remove_animation(setup[0])
  library.add_animation(setup[0],animation)
 for setup in [["LanceThrowWindup",0,1,0,0],["LanceThrow",1,1,0,1],["LanceThrowRecover",1,0,1,0]]:
  var animation=player.get_animation("Idle").duplicate(true);animation.length=1
  for pair in [["throw_raise",setup[1],setup[2]],["throw_push",setup[3],setup[4]]]:
   var track=animation.add_track(Animation.TYPE_VALUE);animation.track_set_path(track,NodePath("Armature/Skeleton3D/WeaponHand/Grip:"+pair[0]));animation.track_insert_key(track,0,float(pair[1]));animation.track_insert_key(track,1,float(pair[2]))
  if setup[0] in ["LanceThrow","LanceThrowRecover"]:
   var rig=get_parent().get_parent()
   for track in range(animation.get_track_count()-1,-1,-1):
    if animation.track_get_type(track)!=Animation.TYPE_ROTATION_3D:continue
    var path=animation.track_get_path(track)
    if not grip_rotations.has(path):continue
    animation.remove_track(track);var fresh=animation.add_track(Animation.TYPE_ROTATION_3D);animation.track_set_path(fresh,path)
    var rest=rig.get_bone_rest(rig.find_bone(str(path.get_subname(0)))).basis.get_rotation_quaternion()
    animation.track_insert_key(fresh,0,grip_rotations[path] if setup[0]=="LanceThrow" else rest)
    if setup[0]=="LanceThrow":animation.track_insert_key(fresh,.65,grip_rotations[path])
    animation.track_insert_key(fresh,1,rest)
  if library.has_animation(setup[0]):library.remove_animation(setup[0])
  library.add_animation(setup[0],animation)
 var death=player.get_animation("Death01");var path=NodePath("Armature/Skeleton3D/WeaponHand/Grip:fall")
 var track=death.find_track(path,Animation.TYPE_VALUE)
 if track>=0:death.remove_track(track)
 track=death.add_track(Animation.TYPE_VALUE);death.track_set_path(track,path)
 for pair in [[0,0],[.5,0],[1.7,1],[2.4,1]]:death.track_insert_key(track,pair[0],float(pair[1]))
 # The private fall retains source rotations; the measured root lift makes
 # room for the rigid armored outfit. Other clips keep their original root.
 var rig=get_parent().get_parent();var root_path=NodePath("Armature/Skeleton3D:root")
 track=death.find_track(root_path,Animation.TYPE_POSITION_3D)
 if track>=0:death.remove_track(track)
 track=death.add_track(Animation.TYPE_POSITION_3D);death.track_set_path(track,root_path)
 var curves=JSON.parse_string(FileAccess.get_file_as_string("res://data/knight_fall_fit.json"))
 var gender="male" if rig.get_bone_global_rest(rig.find_bone("upperarm_l")).origin.x>.17 else "female"
 for pair in curves[gender]:death.track_insert_key(track,pair[0],Vector3(0,pair[1],0))
 return ""
func combat_pose(key: String):
 fall=0
 recovering=key in ["recover","throw_recover"]
 if key!="recover":throwing=key in ["throw_windup","critical_throw_windup","throw","throw_recover"]
 if key in ["throw_windup","critical_throw_windup"]:throw_raise=0;throw_push=0;get_node("Weapon").show()
 holding=key not in ["down","hit","critical_hit","evade"]
 if key not in ["windup","critical_windup","strike","recover"]:lift=0;thrust=0
 if key in ["idle","advance","windup","critical_windup","victory"]:get_node("Weapon").show()
func aim_at(point: Vector3):
 if arms!=null and point.is_finite():arms.aim_point=point;arms.has_aim=true
func release_projectile():get_node("Weapon").hide()

func clear_aim():
 if arms!=null:arms.has_aim=false

func animation_pose(key: String) -> String:return "throw_recover" if key=="recover" and throwing else key

func pose_finished(key: String):
 if key=="throw":release_projectile()

func projectile_source() -> Node3D:return get_node("Weapon") if equipped=="javelin" else null
