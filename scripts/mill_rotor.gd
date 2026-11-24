extends Node3D
## The mill advances while its tactical map or arena is visible.

const RADIANS_PER_SECOND=.28

func _process(delta: float):
 if not is_visible_in_tree():return
 rotation.z=fposmod(rotation.z+delta*RADIANS_PER_SECOND,TAU)
