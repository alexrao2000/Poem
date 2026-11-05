extends SceneTree
const Imported=preload("res://scripts/imported_fighter.gd")
const Actor=preload("res://scripts/fighter_actor.gd")
const Defeat=preload("res://scripts/combat_defeat.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var departures=0
var appearances=0
func _initialize():call_deferred("run")
func watch(node):
 if node is Imported:
  appearances+=1
  assert(node.model.get_meta("character_identity")=="tarin")
 if node is Defeat:
  await process_frame
  if not node.actor is Imported:return
  var victim=node.actor
  while is_instance_valid(node) and victim.visible:await process_frame
  assert(not victim.visible and victim.model.get_node("Identity").blink.closed)
  departures+=1
func skip_phase(app,phase,record):
 var deadline=Time.get_ticks_msec()+8000
 while Time.get_ticks_msec()<deadline:
  await process_frame
  if not app.stage.visible:continue
  var found=app.stage.has_node("CombatProjectile") if phase=="projectile" else app.stage.get_children().any(func(node):return node is Imported and node.pose_name==phase)
  if not found:continue
  record.requested=true
  var tab=InputEventKey.new();tab.keycode=KEY_TAB;tab.pressed=true;app._input(tab)
  var frames=0
  while not app.ui.get_node("CombatTransition").visible and frames<6:await process_frame;frames+=1
  assert(frames<=2,"Casting skip starts the return transition within two frames")
  return
 assert(false,"Reached requested source-casting phase: "+phase)
func run():
 root.size=Vector2i(1024,640)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-debug-caster-save.json";root.add_child(app);await process_frame
 app.game.story_seen=["opening_0"];app.show_camp();assert(app.persist_campaign("camp"))
 var disk=FileAccess.get_file_as_string(app.save_path);var original=app.game.save_data("camp").duplicate(true);var catalog=app.fighters.models.catalog.duplicate(true)
 var unit=app.game.roster.filter(func(value):return value.id=="tarin")[0].duplicate(true);unit.team="player"
 assert(not app.debug_session.set_revised_caster(true))
 app.debug_session.revised_caster=true
 var plain=app.make_fighter(unit,Vector3.ZERO);assert(plain is Actor);plain.queue_free();await process_frame
 app.show_options("camp");app.ui.find_child("DebugMode",true,false).button_pressed=true;app.show_debug_tools("camp");await process_frame
 var toggle=app.ui.find_child("DebugCasterModel",true,false);assert(not toggle.button_pressed);toggle.button_pressed=true
 var state=app.game.save_data("camp").duplicate(true);var seed=app.game.rng.state
 for item in ["ember","gale","thunder"]:
  unit.item=item
  var actor=app.make_fighter(unit,Vector3.ZERO);assert(actor is Imported and actor.model.get_meta("character_identity")=="tarin")
  assert(actor.model.get_node("Rig/Armature/Skeleton3D/BookHand/Folio").equipped==item)
  actor.queue_free();await process_frame
 for patch in [{"team":"enemy"},{"id":"vela"},{"job":"Warden"},{"weapon":"staff","item":"mend_staff"},{"item":"unsupported_folio"},{"promotion":"test_promotion"}]:
  var changed=unit.duplicate(true);changed.merge(patch,true)
  assert(app.debug_caster.build(app.stage,changed,Vector3.ZERO)==null,"Unsupported identity, class, promotion or equipment retains the normal builder")
 var nell=app.game.roster.filter(func(value):return value.id=="nell")[0].duplicate(true);nell.team="player"
 var duelist=app.make_fighter(nell,Vector3.ZERO);assert(duelist is Actor);duelist.queue_free();await process_frame
 app.debug_session.set_revised_duelists(true)
 duelist=app.make_fighter(nell,Vector3.ZERO);assert(duelist is Imported);duelist.queue_free();await process_frame
 app.debug_session.set_revised_duelists(false)
 app.show_model_view(unit);await process_frame
 assert(app.preview_actor is Imported and app.preview_actor.model.get_meta("character_identity")=="tarin")
 app.close_model_view();await process_frame;app.show_debug_tools("camp");assert(app.ui.find_child("DebugCasterModel",true,false).button_pressed)
 app.show_debug_report();await process_frame
 var presentation=JSON.parse_string(app.ui.find_child("DebugReport",true,false).text).presentation
 assert(presentation.revised_caster and not presentation.revised_duelists)
 assert(app.game.save_data("camp")==state and app.game.rng.state==seed and app.fighters.models.catalog==catalog)
 assert(app.persist_campaign("camp") and FileAccess.get_file_as_string(app.save_path)==disk)
 app.debug_session.load_chapter(app.game,6);app.make_map();app.show_battle();app.busy=true
 app.stage.child_entered_tree.connect(watch)
 var enemy=app.game.living("enemy")[0].duplicate(true);enemy.x=9;enemy.y=4;enemy.job="Rider";enemy.weapon="lance";enemy.item="iron_lance";unit.x=7;unit.y=4
 var saved=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state;var camera=app.camera.transform;var score=app.score
 for item in ["ember","gale","thunder"]:
  unit.item=item
  await app.cinematic(unit,enemy,[{"actor":unit.id,"target":enemy.id,"damage":3,"remaining":17,"hit":true,"crit":item=="thunder"}],{unit.id:unit.hp,enemy.id:20})
 await app.cinematic(enemy,unit,[{"actor":enemy.id,"target":unit.id,"damage":0,"remaining":unit.hp,"hit":false,"crit":false}],{unit.id:unit.hp,enemy.id:20})
 await app.cinematic(unit,enemy,[{"actor":unit.id,"target":enemy.id,"damage":20,"remaining":0,"hit":true,"crit":false}],{unit.id:unit.hp,enemy.id:20})
 await app.cinematic(enemy,unit,[{"actor":enemy.id,"target":unit.id,"damage":unit.hp,"remaining":0,"hit":true,"crit":false}],{unit.id:unit.hp,enemy.id:20})
 assert(appearances==6 and departures==1,"Actual elemental, critical, mounted, dodge, finish and defeat paths use the debug builder")
 for phase in ["windup","strike","projectile","down"]:
  var report={};skip_phase(app,phase,report)
  var falling=phase=="down"
  await app.cinematic(enemy if falling else unit,unit if falling else enemy,[{"actor":enemy.id if falling else unit.id,"target":unit.id if falling else enemy.id,"damage":unit.hp if falling else 3,"remaining":0 if falling else 17,"hit":true,"crit":false}],{unit.id:unit.hp,enemy.id:20})
  await process_frame;await process_frame
  assert(report.get("requested",false) and app.skip_combat)
  assert(not app.stage.visible and app.world.visible and app.camera.transform.is_equal_approx(camera))
  for name in ["CombatProjectile","CombatCharge","CombatHitStop","CombatTrail"]:assert(not app.stage.has_node(name))
  for actor in app.stage.get_children().filter(func(node):return node is Imported):assert(actor.can_process())
 assert(app.game.save_data("battle")==saved and app.game.rng.state==rng and app.score==score and Engine.time_scale==1.0)
 app.busy=false;app.show_debug_tools("battle");app.ui.find_child("DebugCasterModel",true,false).button_pressed=false
 plain=app.make_fighter(unit,Vector3.ZERO);assert(plain is Actor);plain.queue_free();await process_frame
 app.ui.find_child("DebugCasterModel",true,false).button_pressed=true
 app.show_options("battle");app.ui.find_child("DebugMode",true,false).button_pressed=false
 assert(not app.debug_session.active and not app.debug_session.revised_caster and app.game.save_data("camp")==original)
 assert(FileAccess.get_file_as_string(app.save_path)==disk and app.fighters.models.catalog==catalog)
 app.debug_session.begin(app.game,"camp");assert(not app.debug_session.revised_caster);app.debug_session.end(app.game)
 await Shutdown.dispose(app);await process_frame
 print("PASS: independent casting comparison, three folios, fallback identities/classes/promotions, outfit preview, report, six full exchanges, four phase skips and exact campaign/save/RNG/clock restoration")
 quit()
