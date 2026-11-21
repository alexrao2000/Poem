extends "res://tests/test_promotion_studies.gd"
func _initialize():
 character_ids=["petra"];promotion_ids=["bastion","sentinel"]
 item_ids=["iron_lance","light_lance","pike","riders_bane","javelin"];ranged_items=["javelin"]
 super._initialize()
func watch(node):
 if node is Projectile:
  await process_frame
  var actors=node.get_parent().get_children().filter(func(child):return child is Imported and child.has_meta("promotion_look") and child.kind=="lance" and child.pose_name=="throw")
  assert(actors.size()==1)
  var weapon=actors[0].projectile_source()
  assert(weapon!=null and not weapon.visible and node.body.has_node("HeldSpear"))
  assert(node.origin.distance_to(weapon.get_node("TrailTip").global_position)<.001,"Promoted javelin starts at its actual tip")
  assert(node.body.get_node("HeldSpear/LanceShaft").mesh==weapon.get_node("LanceShaft").mesh)
  flights+=1;return
 if not node is Impact:return
 await process_frame
 var actors=node.get_parent().get_children().filter(func(child):return child is Imported and child.has_meta("promotion_look") and child.kind=="lance" and child.pose_name=="strike")
 if actors.is_empty():return
 assert(actors[0].weapon_trail_points()[1].distance_to(node.global_position)<.015,"Promoted lance meets the guard or mounted body with its actual tip")
 contacts+=1
