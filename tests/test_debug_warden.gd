extends SceneTree
const Imported=preload("res://scripts/imported_fighter.gd")
const Actor=preload("res://scripts/fighter_actor.gd")
const Defeat=preload("res://scripts/combat_defeat.gd")
const Heal=preload("res://scripts/combat_heal.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var heals=0
var departures=0
func _initialize():call_deferred("run")
func watch(node):
 if node is Heal:heals+=1
 elif node is Defeat:
  await process_frame
  if not node.actor is Imported:return
  var actor=node.actor
  while is_instance_valid(node) and actor.visible:await process_frame
  assert(not actor.visible and actor.model.get_node("Identity").blink.closed);departures+=1
func run():
 root.size=Vector2i(1024,640)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-debug-warden-save.json";root.add_child(app);await process_frame
 app.game.story_seen=["opening_0"];app.show_camp();assert(app.persist_campaign("camp"))
 var original=app.game.save_data("camp").duplicate(true);var disk=FileAccess.get_file_as_string(app.save_path);var catalog=app.fighters.models.catalog.duplicate(true)
 var unit=app.game.roster.filter(func(value):return value.id=="ivo")[0].duplicate(true);unit.team="player"
 assert(not app.debug_session.set_revised_warden(true));app.debug_session.revised_warden=true
 var actor=app.make_fighter(unit,Vector3.ZERO);assert(actor is Actor);actor.queue_free();await process_frame
 app.show_options("camp");app.ui.find_child("DebugMode",true,false).button_pressed=true;app.show_debug_tools("camp");await process_frame
 var toggle=app.ui.find_child("DebugWardenModel",true,false);assert(not toggle.button_pressed);toggle.button_pressed=true
 var checkpoint=app.game.save_data("camp").duplicate(true);var rng=app.game.rng.state
 for id in ["ivo","esme","galen"]:
  unit=app.game.roster.filter(func(value):return value.id==id)[0].duplicate(true);unit.team="player"
  for item in ["field_staff","mend_staff","beacon_staff"]:
   unit.item=item;actor=app.make_fighter(unit,Vector3.ZERO)
   assert(actor is Imported and actor.model.get_meta("character_identity")==id and actor.model.get_node("Rig/Armature/Skeleton3D/WeaponHand/Staff").equipped==item)
   actor.queue_free();await process_frame
  for patch in [{"team":"enemy"},{"id":"lyra"},{"job":"Arcanist"},{"weapon":"magic","item":"ember"},{"item":"unknown_staff"},{"promotion":"test_promotion"}]:
   var changed=unit.duplicate(true);changed.merge(patch,true);assert(app.debug_warden.build(app.stage,changed,Vector3.ZERO)==null)
  app.show_model_view(unit);await process_frame;assert(app.preview_actor is Imported and app.preview_actor.model.get_meta("character_identity")==id);app.close_model_view();await process_frame
 var mage=app.game.roster.filter(func(value):return value.id=="tarin")[0].duplicate(true);mage.team="player"
 actor=app.make_fighter(mage,Vector3.ZERO);assert(actor is Actor);actor.queue_free();await process_frame
 app.debug_session.set_revised_caster(true);actor=app.make_fighter(mage,Vector3.ZERO);assert(actor is Imported);actor.queue_free();await process_frame
 app.debug_session.set_revised_caster(false);app.show_debug_report();await process_frame
 var presentation=JSON.parse_string(app.ui.find_child("DebugReport",true,false).text).presentation
 assert(presentation.revised_warden and not presentation.revised_caster and not presentation.revised_duelists and not presentation.revised_vanguard)
 assert(app.game.save_data("camp")==checkpoint and app.game.rng.state==rng and app.persist_campaign("camp") and FileAccess.get_file_as_string(app.save_path)==disk)
 app.debug_session.load_chapter(app.game,11);app.make_map();app.show_battle();app.busy=true;app.stage.child_entered_tree.connect(watch)
 var patient=app.game.roster[0].duplicate(true);patient.team="player";patient.x=9;patient.y=4;var enemy=app.game.living("enemy")[0].duplicate(true);enemy.x=9;enemy.y=4
 for id in ["ivo","esme","galen"]:
  unit=app.game.roster.filter(func(value):return value.id==id)[0].duplicate(true);unit.team="player";unit.x=7;unit.y=4;unit.item="mend_staff"
  var before=app.game.save_data("battle").duplicate(true);rng=app.game.rng.state
  await app.cinematic(unit,patient,[{"actor":unit.id,"target":patient.id,"healing":6}],{unit.id:unit.hp,patient.id:patient.hp-6})
  await app.cinematic(enemy,unit,[{"actor":enemy.id,"target":unit.id,"damage":2,"remaining":unit.hp-2,"hit":true,"crit":false}],{unit.id:unit.hp,enemy.id:enemy.hp})
  assert(app.game.save_data("battle")==before and app.game.rng.state==rng)
 var before=app.game.save_data("battle").duplicate(true);rng=app.game.rng.state
 await app.cinematic(enemy,unit,[{"actor":enemy.id,"target":unit.id,"damage":unit.hp,"remaining":0,"hit":true,"crit":true}],{unit.id:unit.hp,enemy.id:enemy.hp})
 assert(app.game.save_data("battle")==before and app.game.rng.state==rng and heals==3 and departures==1)
 assert(app.world.visible and app.pieces.visible and not app.stage.visible and app.camera.projection==Camera3D.PROJECTION_ORTHOGONAL)
 app.busy=false;app.show_options("battle");app.ui.find_child("DebugMode",true,false).button_pressed=false
 assert(not app.debug_session.active and not app.debug_session.revised_warden and app.game.save_data("camp")==original and app.fighters.models.catalog==catalog and FileAccess.get_file_as_string(app.save_path)==disk)
 actor=app.make_fighter(unit,Vector3.ZERO);assert(actor is Actor);actor.queue_free();await process_frame
 app.show_options("camp");app.ui.find_child("DebugMode",true,false).button_pressed=true;assert(not app.debug_session.revised_warden)
 app.debug_session.end(app.game);await Shutdown.dispose(app);await process_frame
 print("PASS: independent Warden comparison, nine staff/identity bindings, promotion/class/item/enemy fallback, three previews/heals/reactions, resolved defeat, normal map restoration, report and exact campaign/save/RNG isolation")
 quit()
