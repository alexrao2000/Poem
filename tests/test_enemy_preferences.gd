extends SceneTree
const Imported=preload("res://scripts/imported_fighter.gd")
const Actor=preload("res://scripts/fighter_actor.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")
func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-enemy-preference-save.json";root.add_child(app);await process_frame
 app.game.story_seen=["opening_0"];app.show_camp();assert(app.persist_campaign("camp"))
 var before=app.game.save_data("camp").duplicate(true);var disk=FileAccess.get_file_as_string(app.save_path);var rng=app.game.rng.state;var catalog=app.fighters.models.catalog.duplicate(true)
 var studies=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json"));var count=0
 assert(app.revised_enemies.models.issues.is_empty() and app.revised_enemies.weapons.size()==8)
 assert(not app.debug_session.set_revised_enemies(true))
 for spec in studies.values():
  if not spec.has("study_enemy_class"):continue
  var enemy=app.game.roster.filter(func(value):return value.id==spec.study_character)[0].duplicate(true);enemy.id="enemy_study";enemy.team="enemy";enemy.job=spec.study_enemy_class
  app.preferences.values.character_models="current";enemy.item=spec.supported_items[0]
  var actor=app.make_fighter(enemy,Vector3.ZERO);assert(actor is Actor);actor.queue_free();await process_frame
  app.preferences.values.character_models="revised"
  for item in spec.supported_items:
   enemy.item=item;actor=app.make_fighter(enemy,Vector3.ZERO)
   assert(actor is Imported and actor.model.get_meta("enemy_appearance")==enemy.job and actor.model.get_node("Identity").identity==enemy.id)
   assert(actor.model.get_node("Identity").cloak.cloth.material_override.get_shader_parameter("cape_mark")==app.fighters.IMPERIAL_CAPE)
   actor.queue_free();await process_frame;count+=1
  for patch in [{"team":"player"},{"boss":true},{"promotion":"test_promotion"},{"weapon":"staff" if enemy.weapon!="staff" else "sword"},{"item":"unknown_item"},{"job":"unknown_job"}]:
   var changed=enemy.duplicate(true);changed.merge(patch,true);assert(app.revised_enemies.build(app.stage,changed,Vector3.ZERO)==null)
 assert(count==29 and app.game.save_data("camp")==before and app.game.rng.state==rng)
 app.preferences.values.character_models="current";app.show_options("camp");app.ui.find_child("DebugMode",true,false).button_pressed=true
 assert(not app.debug_session.revised_enemies and not app.debug_session.revised_vanguard)
 for size_value in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
  root.size=size_value;app.show_debug_tools("camp");await process_frame;await process_frame
  var toggle=app.ui.find_child("DebugEnemyModels",true,false);var scroll=app.ui.find_children("*","ScrollContainer",true,false)[0]
  scroll.ensure_control_visible(toggle);await process_frame;await process_frame
  assert(scroll.get_global_rect().grow(.1).encloses(toggle.get_global_rect()))
 app.ui.find_child("DebugEnemyModels",true,false).button_pressed=true
 var ally=app.game.roster[0].duplicate(true);ally.team="player"
 var enemy=ally.duplicate(true);enemy.id="enemy_vanguard";enemy.team="enemy"
 var actor=app.make_fighter(enemy,Vector3.ZERO);assert(actor is Imported);actor.queue_free();await process_frame
 actor=app.make_fighter(ally,Vector3.ZERO);assert(actor is Actor);actor.queue_free();await process_frame
 app.debug_session.set_revised_enemies(false);app.debug_session.set_revised_vanguard(true)
 actor=app.make_fighter(enemy,Vector3.ZERO);assert(actor is Actor);actor.queue_free();await process_frame
 actor=app.make_fighter(ally,Vector3.ZERO);assert(actor is Imported);actor.queue_free();await process_frame
 app.show_debug_report();var report=JSON.parse_string(app.ui.find_child("DebugReport",true,false).text).presentation
 assert(not report.revised_enemies and report.revised_vanguard and report.campaign_models=="current")
 app.debug_session.set_revised_enemies(true);assert(app.persist_campaign("camp") and FileAccess.get_file_as_string(app.save_path)==disk)
 app.show_options("camp");app.ui.find_child("DebugMode",true,false).button_pressed=false
 assert(not app.debug_session.revised_enemies and app.game.save_data("camp")==before and app.game.rng.state==rng)
 app.preferences.values.character_models="revised";app.show_options("camp");app.ui.find_child("DebugMode",true,false).button_pressed=true
 assert(app.debug_session.revised_enemies);app.debug_session.end(app.game);assert(not app.debug_session.revised_enemies)
 assert(FileAccess.get_file_as_string(app.save_path)==disk and app.fighters.models.catalog==catalog)
 await Shutdown.dispose(app);await process_frame
 print("PASS: 29 ordinary enemy equipment bindings, boss/promotion/team/class/weapon/item fallback, reachable three-size independent enemy debug switch, inheritance/reset/report and exact campaign/save/RNG isolation")
 quit()
