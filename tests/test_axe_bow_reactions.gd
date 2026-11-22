extends "res://tests/test_sword_reactions.gd"

func _initialize():
 study_ids=["corsair_female","corsair_male","ranger_female","ranger_male"]
 jobs=["Corsair","Ranger"]
 equipment={"axe":["iron_axe","hatchet","great_axe","war_hammer"],"bow":["scout_bow","recurve","longbow"]}
 expected_variants=70
 super()
