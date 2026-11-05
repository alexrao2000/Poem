extends SceneTree
const Imported=preload("res://scripts/imported_fighter.gd")
const Actor=preload("res://scripts/fighter_actor.gd")
const Impact=preload("res://scripts/combat_impact.gd")
const Defeat=preload("res://scripts/combat_defeat.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var contacts=0
var departures=0
func _initialize():call_deferred("run")
func watch(node):
 if node is Impact:
  await process_frame
  var attackers=node.get_parent().get_children().filter(func(child):return child is Imported and child.pose_name=="strike")
  if attackers.is_empty():return
  var edge=attackers[0].weapon_trail_points()
  assert(Geometry3D.get_closest_point_to_segment(node.global_position,edge[0],edge[1]).distance_to(node.global_position)<.015,"Actual enemy sword contact meets its blade")
  contacts+=1
 elif node is Defeat:
  await process_frame
  if not node.actor is Imported:return
  var victim=node.actor
  while is_instance_valid(node) and victim.visible:await process_frame
  assert(not victim.visible and victim.model.get_node("Identity").blink.closed);departures+=1
func run():
 root.size=Vector2i(1024,640)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-enemy-study-save.json";root.add_child(app);await process_frame
 app.debug_session.begin(app.game,"camp");app.options_return="camp"
 var before=app.game.save_data("camp").duplicate(true);var rng=app.game.rng.state;var profiles=app.fighters.profiles.duplicate(true);var enemy_looks=app.fighters.enemy_looks.duplicate(true)
 var rejected=load("res://scripts/debug_source_models.gd").new(["enemy_duelist"]);assert(rejected.identities.is_empty() and not rejected.models.issues.is_empty(),"Enemy studies cannot alias a company recruit")
 app.show_debug_tools("camp");app.ui.find_child("ModelStudy_enemy_duelist",true,false).pressed.emit();await process_frame
 assert(app.preview_actor is Imported and app.preview_unit.team=="enemy" and app.preview_actor.model.get_node("Identity").identity.is_empty())
 app.preview_actor.rotation.y=.6;app.ui.find_child("StudyStyle",true,false).button_pressed=true;await process_frame;await process_frame
 assert(is_equal_approx(app.preview_actor.rotation.y,.6))
 for index in range(3):
  var selector=app.ui.find_child("StudyEquipment",true,false);selector.select(index);selector.item_selected.emit(index);await process_frame;await process_frame
  var actor=app.preview_actor;var identity=actor.model.get_node("Identity");var appearance=enemy_looks.Duelist
  assert(actor.model.get_meta("enemy_appearance")=="Duelist" and identity.head.get_meta("enemy_headgear")=="Duelist" and identity.head.get_meta("face_variant")==int(appearance.face_variant))
  assert(identity.cloak.cloth.material_override.get_shader_parameter("cape_mark")==app.fighters.IMPERIAL_CAPE)
  for material in identity.painted_materials:assert(material.get_shader_parameter("tint")==Color(appearance.skin if material.get_meta("dye_mode")==3 else appearance.cloth))
  for target in [1,2]:
   var choice=app.ui.find_child("StudyTarget",true,false);choice.select(target);choice.item_selected.emit(target);await app.stage.get_node("PreviewActionPlayer").finished
   var edge=actor.weapon_trail_points();var point=actor.get_node("StudyContactTarget").global_position
   assert(Geometry3D.get_closest_point_to_segment(point,edge[0],edge[1]).distance_to(point)<.006)
  for size_value in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
   root.size=size_value;app.ui.size=size_value;await process_frame;await process_frame
   for button in app.ui.find_children("*","Button",true,false):
    if button.is_visible_in_tree():assert(Rect2(Vector2.ZERO,size_value).grow(.1).encloses(button.get_global_rect()))
 app.close_model_view();await process_frame
 assert(app.game.save_data("camp")==before and app.game.rng.state==rng)
 app.debug_session.load_chapter(app.game,6);app.make_map();app.show_battle();app.busy=true
 var enemy=app.game.living("enemy")[0].duplicate(true);enemy.job="Duelist";enemy.weapon="sword";enemy.boss=false;enemy.x=9;enemy.y=4
 var ally=app.game.roster.filter(func(value):return value.id=="lyra")[0].duplicate(true);ally.team="player";ally.x=8;ally.y=4
 var ordinary=app.make_fighter(enemy,Vector3.ZERO);assert(ordinary is Actor,"Source study leaves campaign enemies on the existing builder");ordinary.queue_free();await process_frame
 var catalog=app.fighters.models.catalog.duplicate(true);var spec=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json")).enemy_duelist;spec.appearance="Identity"
 app.fighters.models.catalog={"enemy_classes":{"Duelist":spec}};app.stage.child_entered_tree.connect(watch)
 before=app.game.save_data("battle").duplicate(true);rng=app.game.rng.state
 for item in ["iron_sword","dueling_sword","tempered_sword"]:
  enemy.item=item
  await app.cinematic(enemy,ally,[{"actor":enemy.id,"target":ally.id,"damage":2,"remaining":ally.hp-2,"hit":true,"crit":item=="tempered_sword"}],{enemy.id:20,ally.id:ally.hp})
 await app.cinematic(ally,enemy,[{"actor":enemy.id,"target":ally.id,"damage":2,"remaining":ally.hp-2,"hit":true,"crit":false}],{enemy.id:20,ally.id:ally.hp})
 for outcome in ["miss","guard","defeat"]:
  await app.cinematic(ally,enemy,[{"actor":ally.id,"target":enemy.id,"damage":20 if outcome=="defeat" else 0,"remaining":0 if outcome=="defeat" else 20,"hit":outcome!="miss","crit":false}],{enemy.id:20,ally.id:ally.hp})
 assert(contacts==4 and departures==1)
 assert(app.game.save_data("battle")==before and app.game.rng.state==rng and app.world.visible and app.pieces.visible and not app.stage.visible)
 assert(app.fighters.profiles==profiles and app.fighters.enemy_looks==enemy_looks)
 app.fighters.models.catalog=catalog;app.busy=false;await Shutdown.dispose(app);await process_frame
 print("PASS: enemy study source/style/equipment controls, original anonymous face/mask/palette/imperial crest, six actual target contacts, three-size controls, four actual enemy attacks including critical/counter, dodge/guard/defeat and exact campaign/RNG/profile isolation")
 quit()
