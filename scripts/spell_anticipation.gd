extends RefCounted
# Lift the free casting arm during gathering, then settle to the exact source
# release. The book-support arm and the rest of each private clip stay intact.
static func configure(player: AnimationPlayer,rig: Skeleton3D) -> String:
 var path=NodePath("Armature/Skeleton3D:upperarm_l");var bone=rig.find_bone("upperarm_l")
 if bone<0:return "Critical casting needs its free upper arm"
 for source_name in ["Spell_Simple_Enter","Spell_Simple_Shoot"]:
  if not player.has_animation(source_name):return "Critical casting needs its source clip: "+source_name
  if player.get_animation(source_name).find_track(path,Animation.TYPE_ROTATION_3D)<0:return "Critical casting needs its free-arm rotation track"
 var originals=[]
 for index in range(rig.get_bone_count()):originals.append([rig.get_bone_pose_position(index),rig.get_bone_pose_rotation(index),rig.get_bone_pose_scale(index)])
 var parent=rig.get_bone_parent(bone)
 var library=player.get_animation_library("")
 for pair in [["Spell_Simple_Enter","CriticalSpellEnter"],["Spell_Simple_Shoot","CriticalSpellRelease"]]:
  var source=player.get_animation(pair[0]);var gathering=pair[0]=="Spell_Simple_Enter"
  var track=source.find_track(path,Animation.TYPE_ROTATION_3D);var animation=source.duplicate(true);animation.remove_track(track)
  var fresh=animation.add_track(Animation.TYPE_ROTATION_3D);animation.track_set_path(fresh,path)
  var end=source.length if gathering else .2;var times=[]
  for index in range(source.track_get_key_count(track)):times.append(source.track_get_key_time(track,index))
  for index in range(17):times.append(end*index/16)
  times.sort();var previous=-1.0
  for time in times:
   if is_equal_approx(time,previous):continue
   previous=time
   var amount=smoothstep(0,end,time) if gathering else 1-smoothstep(0,end,time)
   player.play(pair[0],0);player.seek(time,true,true);player.pause();rig.force_update_all_bone_transforms()
   var parent_basis=rig.get_bone_global_pose(parent).basis
   var axis=(parent_basis.inverse()*Vector3.RIGHT).normalized()
   var rotation=Quaternion(axis,-.36*amount)*source.rotation_track_interpolate(track,time)
   animation.rotation_track_insert_key(fresh,time,rotation.normalized())
  player.stop() # Stop sampled playback before changing library entries.
  if library.has_animation(pair[1]):library.remove_animation(pair[1])
  library.add_animation(pair[1],animation)
 player.stop()
 for index in range(rig.get_bone_count()):
  rig.set_bone_pose_position(index,originals[index][0]);rig.set_bone_pose_rotation(index,originals[index][1]);rig.set_bone_pose_scale(index,originals[index][2])
 rig.force_update_all_bone_transforms()
 return ""
