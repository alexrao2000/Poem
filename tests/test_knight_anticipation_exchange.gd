extends "res://tests/test_axe_anticipation_exchange.gd"
func _initialize():
 character_ids=["petra", "oren", "rook"];promotion_ids=["", "bastion", "sentinel"]
 enemy_class="Rider";weapon_kind="lance";items=["iron_lance","light_lance","pike","riders_bane"]
 normal_clip="LanceStrike";critical_clip="LanceStrike"
 super._initialize()
