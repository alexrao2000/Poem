extends RefCounted
# Briefly open the free casting arm, then return to the source idle pose.
# The folio arm, lower body and original animation resources stay intact.
static func configure(player: AnimationPlayer,rig: Skeleton3D) -> String:
 if not player.has_animation("Idle"):return "Spell finishing needs its idle clip"
 var source=player.get_animation("Idle");var animation=source.duplicate(true)
 # Keep the source duration so its untouched cubic tracks retain their original interpolation.
 # The additional pose selects only the first 240 ms.
 var changes=[["upperarm_l",Vector3.RIGHT,-.22],["hand_l",Vector3.UP,.18]]
 for entry in changes:
  if rig.find_bone(entry[0])<0 or source.find_track(NodePath("Armature/Skeleton3D:"+entry[0]),Animation.TYPE_ROTATION_3D)<0:return "Spell finishing needs its free-arm rotation: "+entry[0]
 var originals=[]
 for bone in range(rig.get_bone_count()):originals.append([rig.get_bone_pose_position(bone),rig.get_bone_pose_rotation(bone),rig.get_bone_pose_scale(bone)])
 for entry in changes:
  var bone=rig.find_bone(entry[0]);var path=NodePath("Armature/Skeleton3D:"+entry[0])
  var track=source.find_track(path,Animation.TYPE_ROTATION_3D)
  animation.remove_track(animation.find_track(path,Animation.TYPE_ROTATION_3D))
  var fresh=animation.add_track(Animation.TYPE_ROTATION_3D);animation.track_set_path(fresh,path)
  for step in range(33):
   var time=.24*step/32.0
   var weight=smoothstep(0,.10,time)*(1-smoothstep(.10,.24,time))
   player.play("Idle",0);player.seek(time,true,true);player.pause();rig.force_update_all_bone_transforms()
   var parent_basis=rig.get_bone_global_pose(rig.get_bone_parent(bone)).basis
   var axis=(parent_basis.inverse()*entry[1]).normalized()
   var rotation=Quaternion(axis,entry[2]*weight)*source.rotation_track_interpolate(track,time)
   animation.rotation_track_insert_key(fresh,time,rotation.normalized())
 player.stop()
 for bone in range(rig.get_bone_count()):
  rig.set_bone_pose_position(bone,originals[bone][0]);rig.set_bone_pose_rotation(bone,originals[bone][1]);rig.set_bone_pose_scale(bone,originals[bone][2])
 rig.force_update_all_bone_transforms()
 var library=player.get_animation_library("")
 if library.has_animation("SpellFinish"):library.remove_animation("SpellFinish")
 library.add_animation("SpellFinish",animation)
 return ""
