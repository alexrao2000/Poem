extends RefCounted
## A presentation identity requires the actual enemy commander flag, matching
## chapter name and class. Ordinary foes and old/custom saves retain fallbacks.
static var profiles=JSON.parse_string(FileAccess.get_file_as_string("res://data/commanders.json"))

static func profile(unit: Dictionary) -> Dictionary:
 if unit.get("team","")!="enemy" or not unit.get("boss",false):return {}
 var entry=profiles.get(unit.get("name",""),{})
 return entry if entry.get("job","")==unit.get("job","") else {}
