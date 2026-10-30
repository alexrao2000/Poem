extends Node
## Presentation-only punctuation after a resolved defeat. Poll skip while the
## actor settles and holds; the caller retains map, camera and result ownership.
var motion: Tween
var stance: Tween

static func quote_for(unit: Dictionary,profiles: Dictionary) -> String:
 if unit.get("team","")!="player":return ""
 return str(profiles.get(unit.get("id",""),{}).get("finish_quote",""))

func play(actor: Node3D,cancelled: Callable,hold=.60):
 name="CombatFinish"
 stance=actor.pose("victory",.28)
 motion=create_tween();motion.tween_interval(hold)
 while motion.is_running():
  if cancelled.call():
   motion.kill()
   if stance.is_valid():stance.kill()
   break
  await get_tree().process_frame
