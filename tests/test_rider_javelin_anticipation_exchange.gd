extends "res://tests/test_bow_anticipation_exchange.gd"
func _initialize():
 character_ids=["una", "bram", "elian"];job="Rider";weapon_kind="lance";items=["javelin"]
 promotion_ids=["", "outrider", "iron_lancer"];preparation_key="critical_throw_windup";strike_key="throw"
 super._initialize()
