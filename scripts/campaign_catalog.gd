extends "res://visuals/catalog.gd"
# Recruit and enemy artwork extend the campaign catalog without changing the
# portable class package. Invalid optional art falls back to those class sheets.
const Catalog=preload("res://visuals/catalog.gd")
var recruit_errors: Array[String]=[]
var enemy_errors: Array[String]=[]

func open(path: String) -> bool:
 recruit_errors.clear();enemy_errors.clear()
 if not super.open(path):return false
 var recruit_path="res://campaign_visuals.json"
 if FileAccess.file_exists(recruit_path) and not add_recruits(recruit_path):
  push_warning("Using class sprites: "+"; ".join(recruit_errors))
 var enemy_path="res://enemy_visuals.json"
 if FileAccess.file_exists(enemy_path) and not add_enemies(enemy_path):
  push_warning("Using tinted enemy class sprites: "+"; ".join(enemy_errors))
 return true

func add_recruits(path: String) -> bool:
 return add_supplement(path,"recruit.",recruit_errors)

func add_enemies(path: String) -> bool:
 return add_supplement(path,"enemy.",enemy_errors)

func add_supplement(path: String,prefix: String,issues: Array[String]) -> bool:
 issues.clear()
 var extra=Catalog.new()
 if not extra.open(path):issues.append_array(extra.errors);return false
 for id in extra.assets:
  if not id.begins_with(prefix) or assets.has(id):
   issues.append("Supplement cannot replace an existing visual: "+id);return false
  if prefix=="enemy." and not assets.has("unit."+id.trim_prefix(prefix)):
   issues.append("Unknown enemy class: "+id);return false
  var scale_value=extra.assets[id].get("source_pixel_scale",0)
  if not (scale_value is int or scale_value is float) or not is_finite(float(scale_value)) or scale_value<=0 or scale_value>2:
   issues.append(id+": invalid source pixel scale");return false
  var facing_frames=extra.assets[id].get("right_facing_frames",[])
  if not facing_frames is Array:
   issues.append(id+": invalid right-facing frames");return false
  for frame in facing_frames:
   if not (frame is int or frame is float) or not is_finite(float(frame)) or frame!=int(frame) or frame<0 or frame>=extra.assets[id].frames.size():
    issues.append(id+": invalid right-facing frame");return false
 assets.merge(extra.assets);textures.merge(extra.textures)
 return true
