extends "res://scripts/prop_floor.gd"
# The staff keeps its chest-relative support pose while the floor constrains it.
func target_pose() -> Transform3D:return clear_floor(super())
