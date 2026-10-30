extends Node
# Presentation-only punctuation after a resolved defeat. A short weapon-specific
# flourish settles into a quiet held pose. Skip cancels either phase; the caller
# retains map, camera and result ownership. Authored models may omit the flourish.

var motion: Tween
var stance: Tween

static func quote_for(unit: Dictionary,profiles: Dictionary) -> String:
 if unit.get("team","")!="player":return ""
 return str(profiles.get(unit.get("id",""),{}).get("finish_quote",""))

func play(actor: Node3D,cancelled: Callable,hold=.60):
 name="CombatFinish"
 stance=actor.finish_flourish(.22)
 if stance!=null:
  if not await wait_motion(stance,cancelled):return
 stance=actor.pose("victory",.28)
 motion=create_tween();motion.tween_interval(hold)
 if not await wait_motion(motion,cancelled):
  if stance.is_valid():stance.kill()

func wait_motion(active: Tween,cancelled: Callable) -> bool:
 while active.is_running():
  if cancelled.call():
   active.kill();return false
  await get_tree().process_frame
 return true
