extends SceneTree
const Imported=preload("res://scripts/imported_fighter.gd")
const Impact=preload("res://scripts/combat_impact.gd")
const Defeat=preload("res://scripts/combat_defeat.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var guards=0
var departures=0
func _initialize():call_deferred("run")
func watch(node):
 if node is Impact:
  await process_frame
  var defenders=node.get_parent().get_children().filter(func(actor):return actor is Imported and actor.has_meta("promotion_look") and actor.pose_name=="guard")
  if defenders.is_empty():return
  assert(defenders.size()==1)
  var actor=defenders[0]
  assert(actor.socket_position("guard").distance_to(node.global_position)<.001,"Actual blocked impact meets the promoted shield face")
  var shield=actor.model.get_node("Rig/Armature/Skeleton3D/KnightShield/Plate")
  assert(shield.has_node("PromotionShieldRim")==(actor.get_meta("promotion_look")=="bastion"))
  guards+=1
 elif node is Defeat:
  await process_frame
  var actor=node.actor
  if not actor is Imported or not actor.has_meta("promotion_look"):return
  while is_instance_valid(node) and actor.visible:await process_frame
  assert(not actor.visible and actor.model.get_node("Identity").blink.closed)
  departures+=1
func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="user://knight-promotion-guards-test.json";root.add_child(app);await process_frame
 app.preferences.values.character_models="revised";app.game.start_battle();app.make_map();app.show_battle();app.busy=true
 var saved=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state
 app.stage.child_entered_tree.connect(watch)
 var enemy=app.game.living("enemy").filter(func(unit):return not unit.get("boss",false))[0].duplicate(true)
 enemy.job="Vanguard";enemy.weapon="sword";enemy.item="estoc";enemy.x=9;enemy.y=4
 for id in ["petra","oren","rook"]:
  for promotion in ["bastion","sentinel"]:
   var unit=app.game.roster.filter(func(value):return value.id==id)[0].duplicate(true);unit.team="player";unit.promotion=promotion;unit.item="iron_lance";unit.x=8;unit.y=4
   await app.cinematic(enemy,unit,[{"actor":enemy.id,"target":unit.id,"damage":0,"remaining":unit.hp,"hit":true,"crit":true}],{enemy.id:20,unit.id:unit.hp})
   await app.cinematic(enemy,unit,[{"actor":enemy.id,"target":unit.id,"damage":unit.hp,"remaining":0,"hit":true,"crit":false}],{enemy.id:20,unit.id:unit.hp})
   assert(app.world.visible and app.pieces.visible and not app.stage.visible)
 assert(guards==6 and departures==6,str([guards,departures]))
 assert(app.game.save_data("battle")==saved and app.game.rng.state==rng)
 app.busy=false;await Shutdown.dispose(app);await process_frame
 print("PASS: six promoted shields receive actual critical blocks, six resolved armored defeats, normal map restoration and unchanged campaign/RNG")
 quit()
