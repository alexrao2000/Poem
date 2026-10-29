extends Node
## Freeze only the two actors; camera, particles, input and music keep running.
## Bound pose tweens and inherited AnimationPlayers obey their actor's mode.
var held: Array=[]
var motion: Tween

static func duration_for(event: Dictionary) -> float:
	if not event.hit or event.damage<=0:return 0.0
	return .10 if event.crit else .055

func play(actors: Array,duration: float) -> Tween:
	name="CombatHitStop"
	if motion and motion.is_valid():motion.kill()
	restore()
	for actor in actors:
		if not is_instance_valid(actor):continue
		if held.any(func(entry):return entry.actor==actor):continue
		held.append({"actor":actor,"mode":actor.process_mode})
		actor.process_mode=Node.PROCESS_MODE_DISABLED
	motion=create_tween();motion.tween_interval(maxf(duration,.001))
	motion.tween_callback(restore);motion.tween_callback(queue_free)
	return motion

func restore():
	for entry in held:
		if is_instance_valid(entry.actor):entry.actor.process_mode=entry.mode
	held.clear()

func _exit_tree():restore()
