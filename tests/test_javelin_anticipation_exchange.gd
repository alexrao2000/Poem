extends "res://tests/test_bow_anticipation_exchange.gd"
func _initialize():
 character_ids=["petra", "oren", "rook"];job="Knight";weapon_kind="lance";items=["javelin"]
 promotion_ids=["", "bastion", "sentinel"];preparation_key="critical_throw_windup";strike_key="throw"
 super._initialize()
