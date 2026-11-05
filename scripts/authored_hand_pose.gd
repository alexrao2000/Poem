extends RefCounted
# Equipment owns these already-private animation copies. A rest-relative hand
# pose supports props without replacing wrist, arm or body motion.
static func names() -> Array[String]:
 var result: Array[String]=[]
 for digit in ["thumb","index","middle","ring","pinky"]:
  for part in ["01","02","03"]:result.append(digit+"_"+part+"_r")
 return result

static func configure(player: AnimationPlayer,rig: Skeleton3D,open_fingers: float,open_thumb: float,previous: Dictionary) -> Dictionary:
 if not player.has_animation("Sword_Idle"):return {"error":"Equipped hand needs its source grip pose"}
 if rig==null:return {"error":"Equipped grip needs its source hand skeleton"}
 var source=player.get_animation("Sword_Idle");var fingers=previous.duplicate();var required=names()
 for track in range(source.get_track_count()):
  var path=source.track_get_path(track)
  if source.track_get_type(track)!=Animation.TYPE_ROTATION_3D or path.get_subname_count()!=1:continue
  var name_value=str(path.get_subname(0))
  if name_value in required and not fingers.has(path) and source.track_get_key_count(track)>0:
   var bone=rig.find_bone(name_value)
   if bone<0:return {"error":"Equipped hand bone is missing: "+name_value}
   var rotation: Quaternion=source.track_get_key_value(track,0)
   var rest=rig.get_bone_rest(bone).basis.get_rotation_quaternion()
   fingers[path]=rotation.slerp(rest,open_thumb if name_value.begins_with("thumb") else open_fingers)
 if fingers.size()!=15:return {"error":"Equipped hand needs all fifteen right-finger joints"}
 for clip in player.get_animation_list():
  var animation=player.get_animation(clip)
  for track in range(animation.get_track_count()-1,-1,-1):
   if animation.track_get_type(track)==Animation.TYPE_ROTATION_3D and fingers.has(animation.track_get_path(track)):animation.remove_track(track)
  for path in fingers:
   var track=animation.add_track(Animation.TYPE_ROTATION_3D);animation.track_set_path(track,path);animation.track_insert_key(track,0.0,fingers[path])
 return {"error":"","rotations":fingers}
