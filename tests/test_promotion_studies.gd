extends SceneTree
# Ordinary training preview and resolved combat, without committing training.
const Imported=preload("res://scripts/imported_fighter.gd")
const Impact=preload("res://scripts/combat_impact.gd")
const Projectile=preload("res://scripts/combat_projectile.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var character_ids=["lyra","rhea"]
var promotion_ids=["standard_bearer","dawnblade"]
var item_ids=["iron_sword","dueling_sword","tempered_sword","estoc"]
var contacts=0
var flights=0
func _initialize():call_deferred("run")
func watch(node):
 if node is Projectile:
  await process_frame
  var archers=node.get_parent().get_children().filter(func(child):return child is Imported and child.has_meta("promotion_look") and child.kind=="bow" and child.pose_name=="strike")
  assert(archers.size()==1)
  var bow=archers[0].model.get_node("Rig/Armature/Skeleton3D/WeaponHand/Bow");var arrow=bow.get_node("Weapon/NockedArrow")
  assert(node.kind=="bow" and bow.projectile_spent and not arrow.visible)
  assert(node.origin.distance_to(arrow.to_global(Vector3(0,0,-Projectile.ARROW_LENGTH*.5-.075)))<.001,"Promoted bow launches from its actual arrow tip")
  flights+=1;return
 if not node is Impact:return
 await process_frame
 var actors=node.get_parent().get_children().filter(func(child):return child is Imported and child.has_meta("promotion_look") and child.kind in ["sword","axe"] and child.pose_name=="strike")
 if actors.is_empty():return
 var actor=actors[0];var edge=actor.weapon_trail_points()
 var gap=actor.sockets.trail_tip.global_position.distance_to(node.global_position) if actor.point_trail_width>0 else Geometry3D.get_closest_point_to_segment(node.global_position,edge[0],edge[1]).distance_to(node.global_position)
 assert(gap<.015,str(["Promoted blade contact",actor.model.get_meta("character_identity"),actor.model.get_node("Rig/Armature/Skeleton3D/WeaponHand/Grip").equipped,actor.get_meta("promotion_look"),gap,edge,node.global_position]));contacts+=1
func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-promotion-studies.json";root.add_child(app);await process_frame
 app.preferences.values.character_models="revised"
 for id in character_ids:
  var unit=app.game.roster.filter(func(value):return value.id==id)[0];unit.level=10
 var before=app.game.save_data("camp").duplicate(true);var rng=app.game.rng.state
 for id in character_ids:
  var unit=app.game.roster.filter(func(value):return value.id==id)[0]
  for path in app.game.promotion_options(unit):
   app.confirm_promotion(unit,path);await process_frame
   app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Preview outfit")[0].pressed.emit();await process_frame
   var actor=app.preview_actor;assert(actor is Imported and actor.get_meta("promotion_look")==path.id and actor.model.get_node("Identity").promotion!=null)
   for size_value in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
    root.size=size_value;app.ui.size=size_value;await process_frame;await process_frame
    for button in app.ui.find_children("*","Button",true,false):
     if button.is_visible_in_tree():assert(Rect2(Vector2.ZERO,size_value).grow(.1).encloses(button.get_global_rect()))
   app.close_model_view();await process_frame
   assert(app.screen=="promotion_confirm" and unit.get("promotion","")=="")
 assert(app.game.save_data("camp")==before and app.game.rng.state==rng,"Preview does not spend resources, train recruits or consume RNG")
 app.game.start_battle();app.make_map();app.show_battle();app.busy=true;app.stage.child_entered_tree.connect(watch)
 before=app.game.save_data("battle").duplicate(true);rng=app.game.rng.state
 var enemy=app.game.living("enemy").filter(func(unit):return not unit.get("boss",false))[0].duplicate(true);enemy.x=9;enemy.y=4;enemy.weapon="lance";enemy.item="iron_lance"
 for id in character_ids:
  var unit=app.game.roster.filter(func(value):return value.id==id)[0].duplicate(true);unit.team="player";unit.x=7 if unit.weapon=="bow" else 8;unit.y=4
  for promotion in promotion_ids:
   unit.promotion=promotion;enemy.job="Knight" if promotion==promotion_ids[0] else "Rider"
   for item in item_ids:
    unit.item=item
    await app.cinematic(unit,enemy,[{"actor":unit.id,"target":enemy.id,"damage":0 if item==item_ids[0] else 2,"remaining":20 if item==item_ids[0] else 18,"hit":true,"crit":item in item_ids.slice(2)}],{unit.id:unit.hp,enemy.id:20})
    assert(app.world.visible and app.pieces.visible and not app.stage.visible)
 assert(contacts+flights==character_ids.size()*promotion_ids.size()*item_ids.size(),str([contacts,flights,character_ids]))
 assert(app.game.save_data("battle")==before and app.game.rng.state==rng)
 app.busy=false;await Shutdown.dispose(app);await process_frame
 print("PASS: ",character_ids," ordinary promotion previews, three-size controls, cancel without training, ",contacts," critical/guard/mounted blade contacts, ",flights," exact arrow launches and campaign/RNG isolation")
 quit()
