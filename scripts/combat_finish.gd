extends Node
## Presentation-only punctuation after a resolved defeat. Poll skip while the
## actor settles and holds; the caller retains map, camera and result ownership.
var motion: Tween
var stance: Tween

func play(actor: Node3D,cancelled: Callable):
 name="CombatFinish"
 stance=actor.pose("victory",.28)
 motion=create_tween();motion.tween_interval(.60)
 while motion.is_running():
  if cancelled.call():
   motion.kill()
   if stance.is_valid():stance.kill()
   break
  await get_tree().process_frame
