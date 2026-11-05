extends SceneTree
const Imported=preload("res://scripts/imported_fighter.gd")
const Impact=preload("res://scripts/combat_impact.gd")
const Defeat=preload("res://scripts/combat_defeat.gd")
var contacts=0
var blocks=0
var departures=0
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")
func watch(node):
 if node is Impact:
  await process_frame
  var attackers=node.get_parent().get_children().filter(func(child):return child is Imported and child.pose_name=="strike")
  if not attackers.is_empty():
   assert(attackers[0].weapon_trail_points()[1].distance_to(node.global_position)<.015,"Actual lance impact meets the fitted tip")
   contacts+=1
  else:
   var guards=node.get_parent().get_children().filter(func(child):return child is Imported and child.pose_name=="guard")
   if not guards.is_empty():
    assert(guards[0].socket_position("guard").distance_to(node.global_position)<.001,"Blocked strikes meet the fitted shield face")
    blocks+=1
 elif node is Defeat:
  await process_frame
  if not node.actor is Imported:return
  var victim=node.actor
  while is_instance_valid(node) and victim.visible:await process_frame
  assert(not victim.visible and victim.model.get_node("Identity").blink.closed);departures+=1
func run():
 root.size=Vector2i(1024,640)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-knight-studies-save.json";root.add_child(app);await process_frame
 app.debug_session.begin(app.game,"camp");app.options_return="camp";var before=app.game.save_data("camp").duplicate(true);var seed=app.game.rng.state
 for key in ["knight_female","knight_male"]:
  app.show_debug_tools("camp");await process_frame
  app.ui.find_child("ModelStudy_"+key,true,false).pressed.emit();await process_frame
  assert(app.preview_actor is Imported and app.preview_actor.kind=="lance")
  app.ui.find_child("StudyStyle",true,false).button_pressed=true;await process_frame;await process_frame
  assert(app.preview_actor.model.get_node("Identity").armor!=null)
  for index in range(4):
   var choice=app.ui.find_child("StudyEquipment",true,false);var item=choice.get_item_metadata(index)
   app.preview_actor.rotation.y=.75;choice.select(index);choice.item_selected.emit(index);await process_frame;await process_frame
   assert(app.preview_unit.item==item and is_equal_approx(app.preview_actor.rotation.y,.75))
   for target in [1,2]:
    var selector=app.ui.find_child("StudyTarget",true,false);selector.select(target);selector.item_selected.emit(target);await app.stage.get_node("PreviewActionPlayer").finished
    var edge=app.preview_actor.weapon_trail_points();var point=app.preview_actor.get_node("StudyContactTarget").global_position
    assert(Geometry3D.get_closest_point_to_segment(point,edge[0],edge[1]).distance_to(point)<.01,"Actual target controls use the lance's combat spacing")
   var selector=app.ui.find_child("StudyTarget",true,false);selector.select(0);selector.item_selected.emit(0);await app.stage.get_node("PreviewActionPlayer").finished
   assert(not app.preview_actor.model.get_node("Rig/Armature/Skeleton3D/WeaponHand/Grip").arms.has_aim)
   for size_value in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
    root.size=size_value;app.ui.size=size_value;await process_frame;await process_frame
    for control in app.ui.find_children("*","Button",true,false):
     if control.is_visible_in_tree():assert(Rect2(Vector2.ZERO,size_value).grow(.1).encloses(control.get_global_rect()))
  app.close_model_view();await process_frame
 assert(app.game.save_data("camp")==before and app.game.rng.state==seed)
 app.debug_session.load_chapter(app.game,11);app.make_map();app.show_battle();app.busy=true;app.stage.child_entered_tree.connect(watch)
 var catalog=app.fighters.models.catalog.duplicate(true);var studies=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json"))
 var enemy=app.game.living("enemy")[0].duplicate(true);enemy.x=9;enemy.y=4;enemy.weapon="lance";enemy.item="iron_lance"
 for pair in [["knight_female","petra"],["knight_male","oren"]]:
  var spec=studies[pair[0]].duplicate(true);spec.appearance="Identity";app.fighters.models.catalog={"characters":{pair[1]:spec}}
  var unit=app.game.roster.filter(func(value):return value.id==pair[1])[0].duplicate(true);unit.team="player";unit.x=8;unit.y=4
  before=app.game.save_data("battle").duplicate(true);seed=app.game.rng.state
  for item in ["iron_lance","light_lance","pike","riders_bane"]:
   unit.item=item;enemy.job="Rider" if item in ["pike","riders_bane"] else "Knight"
   var counter=item=="riders_bane"
   await app.cinematic(enemy if counter else unit,unit if counter else enemy,[{"actor":unit.id,"target":enemy.id,"damage":0 if item=="light_lance" else 2,"remaining":20 if item=="light_lance" else 18,"hit":true,"crit":counter}],{unit.id:unit.hp,enemy.id:20})
  await app.cinematic(enemy,unit,[{"actor":enemy.id,"target":unit.id,"damage":0,"remaining":unit.hp,"hit":true,"crit":false}],{unit.id:unit.hp,enemy.id:20})
  await app.cinematic(enemy,unit,[{"actor":enemy.id,"target":unit.id,"damage":unit.hp,"remaining":0,"hit":true,"crit":false}],{unit.id:unit.hp,enemy.id:20})
  assert(app.game.save_data("battle")==before and app.game.rng.state==seed)
  assert(app.world.visible and app.pieces.visible and not app.stage.visible and app.camera.projection==Camera3D.PROJECTION_ORTHOGONAL)
 assert(contacts==8 and blocks==2 and departures==2)
 app.fighters.models.catalog=catalog;app.busy=false;await Shutdown.dispose(app);await process_frame
 print("PASS: both Knight study buttons, eight real equipment switches, sixteen foot/mounted target selections, cleared targets, preserved view angle, three-size controls, eight real tip contacts, two shield blocks, both defeats, restored map and exact campaign/RNG isolation")
 quit()
