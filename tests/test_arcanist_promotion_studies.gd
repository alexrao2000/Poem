extends "res://tests/test_promotion_studies.gd"
const Charge=preload("res://scripts/combat_charge.gd")
var charges=0
func _initialize():
 character_ids=["tarin"];promotion_ids=["star_sage","spellwarden"];item_ids=["ember","gale","thunder"];ranged_items=item_ids
 super._initialize()
func watch(node):
 if node is Charge:
  await process_frame
  assert(node.caster is Imported and node.caster.has_meta("promotion_look"))
  assert(node.global_position.distance_to(node.caster.socket_position("projectile"))<.001,"Promoted gathering follows the free casting hand")
  charges+=1
 elif node is Projectile:
  await process_frame
  var actors=node.get_parent().get_children().filter(func(child):return child is Imported and child.has_meta("promotion_look") and child.kind=="magic" and child.pose_name=="strike")
  assert(actors.size()==1 and node.kind=="magic")
  assert(node.origin.distance_to(actors[0].socket_position("projectile"))<.001,"Promoted spell launches from its actual casting palm")
  flights+=1;assert(charges==flights,"Every promoted spell has its own gathering before release")
