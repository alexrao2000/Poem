extends "res://tests/test_sword_reactions.gd"

func _initialize():
 study_ids=["caster","caster_female","warden","warden_female"]
 jobs=["Arcanist","Warden"]
 equipment={"magic":["ember","gale","thunder"],"staff":["field_staff","mend_staff","beacon_staff","vigil_staff"]}
 expected_variants=70
 super()
