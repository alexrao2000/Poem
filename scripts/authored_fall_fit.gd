extends RefCounted
# Measured full-outfit support is baked into each actor's private fall clip.
# Gameplay never scans meshes; source resources and other poses stay intact.
static var curves=JSON.parse_string(FileAccess.get_file_as_string("res://data/authored_fall_fit.json"))
const ROOT_PATH=NodePath("Armature/Skeleton3D:root")
static func apply(player: AnimationPlayer,key: String) -> String:
 if not curves.has(key):return ""
 if not player.has_animation("Death01"):return "Fitted outfit needs Death01"
 var animation=player.get_animation("Death01");var rows=curves[key]
 if not rows is Array or rows.size()<2:return "Invalid fall support curve: "+key
 var previous=-1.0
 for row in rows:
  if not row is Array or row.size()!=2 or not (row[0] is float or row[0] is int) or not (row[1] is float or row[1] is int):return "Invalid fall support sample: "+key
  if not is_finite(row[0]) or not is_finite(row[1]) or row[0]<=previous or row[0]<0 or row[0]>animation.length+.00001 or row[1]<0:return "Invalid fall support bounds: "+key
  previous=row[0]
 var track=animation.find_track(ROOT_PATH,Animation.TYPE_POSITION_3D)
 if track>=0:animation.remove_track(track)
 track=animation.add_track(Animation.TYPE_POSITION_3D);animation.track_set_path(track,ROOT_PATH)
 for row in rows:animation.track_insert_key(track,float(row[0]),Vector3(0,float(row[1]),0))
 return ""
