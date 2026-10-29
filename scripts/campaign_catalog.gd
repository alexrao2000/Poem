extends "res://visuals/catalog.gd"
# Recruit artwork extends the campaign catalog without changing the portable
# class package. Invalid optional art falls back to those validated class sheets.
const Catalog=preload("res://visuals/catalog.gd")
var recruit_errors: Array[String]=[]

func open(path: String) -> bool:
 recruit_errors.clear()
 if not super.open(path):return false
 var recruit_path="res://campaign_visuals.json"
 if FileAccess.file_exists(recruit_path) and not add_recruits(recruit_path):
  push_warning("Using class sprites: "+"; ".join(recruit_errors))
 return true

func add_recruits(path: String) -> bool:
 var extra=Catalog.new()
 if not extra.open(path):recruit_errors=extra.errors.duplicate();return false
 for id in extra.assets:
  if not id.begins_with("recruit.") or assets.has(id):
   recruit_errors.append("Recruit catalog cannot replace an existing visual: "+id);return false
  var scale_value=extra.assets[id].get("source_pixel_scale",0)
  if not (scale_value is int or scale_value is float) or not is_finite(float(scale_value)) or scale_value<=0 or scale_value>2:
   recruit_errors.append(id+": invalid source pixel scale");return false
 assets.merge(extra.assets);textures.merge(extra.textures)
 return true
