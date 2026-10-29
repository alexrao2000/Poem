## Deterministic visual clock. Cues never change gameplay state.

extends RefCounted
signal cue(name: String)
signal finished
var asset: Dictionary = {}
var state = "idle"
var facing = "south"
var index = 0
var elapsed_ms = 0.0
var complete = false
var speed = 1.0

func configure(value: Dictionary):
	asset = value
	play("idle", "south", true)

func play(next_state: String, next_facing = "", restart = false):
	if asset.is_empty(): return
	if next_facing.is_empty(): next_facing = facing
	if not asset.clips.has(next_state) or not asset.clips[next_state].has(next_facing): return
	if state == next_state and facing == next_facing and not restart: return
	state = next_state; facing = next_facing; index = 0; elapsed_ms = 0.0; complete = false
	emit_cues()

func clip() -> Dictionary:
	return asset.clips[state][facing] if not asset.is_empty() else {}

func frame_index() -> int:
	return int(clip().frames[index]) if not asset.is_empty() else 0

func emit_cues():
	for event in clip().get("cues", []):
		if int(event.frame_index) == index: cue.emit(str(event.name))

func advance(seconds: float):
	if asset.is_empty() or complete or seconds <= 0 or not is_finite(seconds): return
	var active = clip()
	elapsed_ms += seconds * 1000.0 * maxf(speed, 0.0)
	if active.loop:
		var cycle_ms = 0.0
		for duration in active.duration_ms: cycle_ms += duration
		if elapsed_ms > cycle_ms * 2.0: elapsed_ms = fmod(elapsed_ms, cycle_ms) + cycle_ms
	while elapsed_ms >= float(active.duration_ms[index]) and not complete:
		elapsed_ms -= float(active.duration_ms[index])
		if index + 1 < active.frames.size(): index += 1; emit_cues()
		elif active.loop: index = 0; emit_cues()
		else: complete = true; elapsed_ms = 0; finished.emit()

func skip():
	if asset.is_empty() or complete or clip().loop: return
	index = clip().frames.size() - 1; elapsed_ms = 0; complete = true; finished.emit()

static func facing_for_step(step: Vector2i) -> String:
	if absi(step.x) >= absi(step.y) and step.x != 0: return "east" if step.x > 0 else "west"
	return "south" if step.y >= 0 else "north"
