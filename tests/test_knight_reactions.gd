extends "res://tests/test_sword_reactions.gd"

func _initialize():
 study_ids=["knight_female","knight_male"]
 jobs=["Knight"]
 equipment={"lance":["iron_lance","light_lance","pike","riders_bane","javelin","rally_lance"]}
 expected_variants=60
 super()
