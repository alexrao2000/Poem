extends RefCounted
## A presentation identity requires the actual enemy commander flag, matching
## chapter name and class. Ordinary foes and old/custom saves retain fallbacks.
static var profiles=JSON.parse_string(FileAccess.get_file_as_string("res://data/commanders.json"))

static func profile(unit: Dictionary) -> Dictionary:
 if unit.get("team","")!="enemy" or not unit.get("boss",false):return {}
 var entry=profiles.get(unit.get("name",""),{})
 return entry if entry.get("job","")==unit.get("job","") else {}

static func take_challenge(attacker: Dictionary,defender: Dictionary,chapter_boss: String,seen: Array) -> Dictionary:
 var commander=attacker if attacker.get("team","")=="enemy" else defender
 var opponent=defender if commander==attacker else attacker
 if commander.get("name","")!=chapter_boss or opponent.get("team","")!="player":return {}
 var entry=profile(commander)
 if not entry.has("challenge"):return {}
 var key="challenge_"+entry.id
 if key in seen:return {}
 var lines=entry.challenge
 seen.append(key)
 return {"unit":commander,"line":lines.opponents.get(opponent.get("id",""),lines.default)}
