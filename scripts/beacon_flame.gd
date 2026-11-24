extends Node3D
## The two ridge beacons have independent, repeating flame motion.

var phase=0.0

func _process(delta: float):
 if not is_visible_in_tree():return
 seek_phase(phase+delta*3.6)

func seek_phase(value: float):
 phase=fposmod(value,TAU)
 scale=Vector3(1+.072*sin(phase*2),1+.14*sin(phase)+.07*cos(phase*3),1+.062*cos(phase*2))
