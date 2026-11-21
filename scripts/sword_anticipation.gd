extends RefCounted
# A restrained extra torso windup distinguishes a critical preparation. It
# unwinds to the exact source contact pose, preserving solved strike targets.
static func configure(player: AnimationPlayer,rig: Skeleton3D) -> String:
 if not player.has_animation("Sword_Attack"):return "Sword anticipation needs its source attack clip"
 var source=player.get_animation("Sword_Attack")
 var path=NodePath("Armature/Skeleton3D:spine_02")
 var track=source.find_track(path,Animation.TYPE_ROTATION_3D)
 var bone=rig.find_bone("spine_02")
 if track<0 or bone<0:return "Sword anticipation needs its source spine track"
 var axis=(rig.get_bone_global_rest(bone).basis.inverse()*Vector3.UP).normalized()
 var animation=source.duplicate(true);animation.remove_track(track)
 var fresh=animation.add_track(Animation.TYPE_ROTATION_3D);animation.track_set_path(fresh,path)
 var times=[]
 for index in range(source.track_get_key_count(track)):times.append(source.track_get_key_time(track,index))
 for index in range(13):times.append(.36*index/12)
 times.append_array([.38,.40,.42,.433]);times.sort()
 var previous=-1.0
 for time in times:
  if is_equal_approx(time,previous):continue
  previous=time
  var amount=smoothstep(0,.36,time)*(1-smoothstep(.36,.433,time))
  var rotation=source.rotation_track_interpolate(track,time)*Quaternion(axis,-.26*amount)
  animation.rotation_track_insert_key(fresh,time,rotation.normalized())
 var library=player.get_animation_library("")
 if library.has_animation("SwordCriticalAttack"):library.remove_animation("SwordCriticalAttack")
 library.add_animation("SwordCriticalAttack",animation)
 return ""
