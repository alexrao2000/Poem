extends "res://tests/test_axe_anticipation_exchange.gd"
func _initialize():
 character_ids=["una", "bram", "elian"];promotion_ids=["", "outrider", "iron_lancer"]
 enemy_class="Knight";weapon_kind="lance";items=["iron_lance","light_lance","pike","riders_bane"]
 normal_clip="LanceStrike";critical_clip="LanceStrike"
 super._initialize()
