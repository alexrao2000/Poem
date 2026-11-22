extends "res://tests/test_sword_reactions.gd"

func _initialize():
 study_ids=["rider_female","rider_male"]
 jobs=["Rider"]
 equipment={"lance":["iron_lance","light_lance","pike","riders_bane","javelin","rally_lance"]}
 expected_variants=60
 super()
