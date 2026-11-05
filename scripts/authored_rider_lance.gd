extends "res://scripts/authored_lance.gd"
var rein_pad=Vector3.ZERO
var slump=0.0
var rider_pose="idle"
func arm_driver() -> Script:return preload("res://scripts/rider_hold.gd")
func configure_animations(player: AnimationPlayer) -> String:
 var error=super(player)
 if not error.is_empty():return error
 var rig=get_parent().get_parent();var original=[]
 for bone in range(rig.get_bone_count()):original.append([rig.get_bone_pose_position(bone),rig.get_bone_pose_rotation(bone),rig.get_bone_pose_scale(bone)])
 player.play("Sword_Idle");player.seek(0,true,true);player.pause();rig.force_update_all_bone_transforms()
 var mirror=Basis.from_scale(Vector3(-1,1,1));var hand=rig.get_bone_global_pose(rig.find_bone("hand_r"));var left_rotations={}
 for digit in ["thumb","index","middle","ring","pinky"]:
  var parent_basis=Basis.IDENTITY
  for part in ["01","02","03"]:
   var bone=rig.find_bone(digit+"_"+part+"_r");var left_bone=rig.find_bone(digit+"_"+part+"_l")
   var desired=mirror*(hand.affine_inverse()*rig.get_bone_global_pose(bone)).basis*mirror
   var local=(parent_basis.inverse()*desired).get_rotation_quaternion().normalized();parent_basis=desired
   left_rotations[digit+"_"+part+"_l"]=local;rig.set_bone_pose_rotation(left_bone,local)
 rig.force_update_all_bone_transforms();var left_hand=rig.get_bone_global_pose(rig.find_bone("hand_l"));rein_pad=Vector3.ZERO
 for name_value in ["index_04_leaf_l","middle_04_leaf_l"]:rein_pad+=left_hand.affine_inverse()*rig.get_bone_global_pose(rig.find_bone(name_value)).origin*.5
 for bone in range(rig.get_bone_count()):rig.set_bone_pose_position(bone,original[bone][0]);rig.set_bone_pose_rotation(bone,original[bone][1]);rig.set_bone_pose_scale(bone,original[bone][2])
 player.stop()
 for name_value in player.get_animation_list():
  var animation=player.get_animation(name_value)
  for track in range(animation.get_track_count()-1,-1,-1):
   var path=animation.track_get_path(track)
   if animation.track_get_type(track)==Animation.TYPE_ROTATION_3D and path.get_subname_count()==1 and left_rotations.has(str(path.get_subname(0))):animation.remove_track(track)
  for bone in left_rotations:
   var track=animation.add_track(Animation.TYPE_ROTATION_3D);animation.track_set_path(track,NodePath("Armature/Skeleton3D:"+bone));animation.track_insert_key(track,0,left_rotations[bone])
 var library=player.get_animation_library("");var down=player.get_animation("Idle").duplicate(true);down.length=1
 var fall_track=down.add_track(Animation.TYPE_VALUE);down.track_set_path(fall_track,NodePath("Armature/Skeleton3D/WeaponHand/Grip:slump"));down.track_insert_key(fall_track,0,0.0);down.track_insert_key(fall_track,1,1.0)
 if library.has_animation("RiderDown"):library.remove_animation("RiderDown")
 library.add_animation("RiderDown",down)
 # Keep the seat in one place; the selected source clips contribute upper-body
 # motion while the mounted support owns both legs.
 var pelvis=rig.find_bone("pelvis");var root_pose=rig.get_bone_global_rest(rig.get_bone_parent(pelvis));var seat=root_pose.affine_inverse()*Vector3(0,1.61-owner.get_node("Mount").base_lift,-.06)
 for clip in player.get_animation_list():
  var animation=player.get_animation(clip);var path=NodePath("Armature/Skeleton3D:pelvis");var track=animation.find_track(path,Animation.TYPE_POSITION_3D)
  if track>=0:animation.remove_track(track)
  track=animation.add_track(Animation.TYPE_POSITION_3D);animation.track_set_path(track,path);animation.track_insert_key(track,0,seat)
 return ""
func combat_pose(key: String):
 super(key);slump=0.0;rider_pose=key
