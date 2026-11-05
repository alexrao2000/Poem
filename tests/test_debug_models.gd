extends SceneTree
const Imported=preload("res://scripts/imported_fighter.gd")
const Actor=preload("res://scripts/fighter_actor.gd")
const Defeat=preload("res://scripts/combat_defeat.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var character_ids=["nell","silas"]
var setting_name="revised_duelists"
var toggle_name="DebugDuelistModels"
var watched=false
var actual=[]
var departures=0
func _initialize():call_deferred("run")
func watch(node):
 if watched and node is Defeat:
  await process_frame
  if node.actor is Imported:
   var victim=node.actor
   while is_instance_valid(node) and victim.visible:await process_frame
   assert(not victim.visible and victim.model.get_node("Identity").blink.closed,"Styled defeat completes the fade with its defeated expression")
   departures+=1
 if not watched or not node is Imported:return
 actual.append(node.model.get_meta("character_identity",""))
 assert(node.model.get_node("Identity").painted_materials.size()>=3)
func run():
 root.size=Vector2i(1024,640)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-debug-models-save.json";root.add_child(app);await process_frame
 app.game.story_seen=["opening_0"];app.show_camp();assert(app.persist_campaign("camp"))
 var disk=FileAccess.get_file_as_string(app.save_path);var original=app.game.save_data("camp").duplicate(true);var catalog=app.fighters.models.catalog.duplicate(true)
 var nell=app.game.roster.filter(func(unit):return unit.id==character_ids[0])[0].duplicate(true);nell.team="player"
 assert(not app.debug_session.call("set_"+setting_name,true))
 app.debug_session.set(setting_name,true)
 var plain=app.make_fighter(nell,Vector3.ZERO);assert(plain is Actor,"The live debug guard prevents revised models outside the sandbox");plain.queue_free();await process_frame
 app.show_options("camp");app.ui.find_child("DebugMode",true,false).button_pressed=true;app.show_debug_tools("camp");await process_frame
 var toggle=app.ui.find_child(toggle_name,true,false);assert(not toggle.button_pressed,"A fresh debug session starts with the current campaign models")
 var state=app.game.save_data("camp").duplicate(true);var seed=app.game.rng.state
 toggle.button_pressed=true
 for id in character_ids:
  var unit=app.game.roster.filter(func(value):return value.id==id)[0].duplicate(true);unit.team="player"
  for item in ["iron_sword","dueling_sword","tempered_sword"]:
   unit.item=item
   var model=app.make_fighter(unit,Vector3.ZERO);assert(model is Imported and model.model.get_meta("character_identity")==id)
   assert(model.model.get_node("Rig/Armature/Skeleton3D/WeaponHand/Grip").equipped==item)
   var weapon=model.model.get_node("Rig/Armature/Skeleton3D/WeaponHand/Grip/Weapon")
   var mapping=model.poses.evade
   model.player.stop();model.player.play(mapping.clip,0)
   for step in range(17):
    model.player.seek(lerpf(mapping.from,mapping.to,float(step)/16),true,true);model.player.pause();model.refresh_skeleton()
    for mesh in weapon.find_children("*","MeshInstance3D",true,false):
     for surface in range(mesh.mesh.get_surface_count()):
      for point in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:assert(mesh.to_global(point).y>.04,"Standing dodge keeps the actual held blade and guard above the floor")
   model.queue_free();await process_frame
  unit.item="estoc"
  var thrust=app.make_fighter(unit,Vector3.ZERO);assert(thrust is Actor and thrust.attack_style=="thrust","The experiment retains the estoc's point-first motion");thrust.queue_free();await process_frame
  unit.item="iron_sword";unit.promotion=app.game.promotions.filter(func(value):return value.base==unit.job)[0].id
  var promoted=app.make_fighter(unit,Vector3.ZERO);assert(promoted is Actor and promoted.get_meta("promotion_look")==unit.promotion,"Promotion costumes remain visible in the experiment");promoted.queue_free();await process_frame
  unit.promotion="";unit.team="enemy"
  var enemy=app.make_fighter(unit,Vector3.ZERO);assert(enemy is Actor,"Enemies cannot inherit a recruit's experimental identity");enemy.queue_free();await process_frame
 var other=app.game.roster.filter(func(value):return value.id not in character_ids)[0].duplicate(true);other.team="player"
 var lord=app.make_fighter(other,Vector3.ZERO);assert(lord is Actor);lord.queue_free();await process_frame
 app.show_model_view(nell);await process_frame
 assert(app.preview_actor is Imported and app.preview_actor.model.get_meta("character_identity")==character_ids[0],"Normal outfit previews honor the debug comparison")
 app.close_model_view();await process_frame;app.show_debug_tools("camp")
 assert(app.ui.find_child(toggle_name,true,false).button_pressed)
 app.show_debug_report();await process_frame
 assert(JSON.parse_string(app.ui.find_child("DebugReport",true,false).text).presentation[setting_name])
 assert(app.game.save_data("camp")==state and app.game.rng.state==seed and app.fighters.models.catalog==catalog,"Model selection does not alter rules, RNG, equipment or the normal catalog")
 assert(app.persist_campaign("camp") and FileAccess.get_file_as_string(app.save_path)==disk)
 app.debug_session.load_chapter(app.game,6);app.make_map();app.show_battle();app.busy=true
 app.stage.child_entered_tree.connect(watch);watched=true
 var opponent=app.game.living("enemy")[0];opponent.x=9;opponent.y=4
 for id in character_ids:
  var unit=app.game.roster.filter(func(value):return value.id==id)[0].duplicate(true);unit.team="player";unit.x=8;unit.y=4;unit.item="dueling_sword"
  var before=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state
  await app.cinematic(unit,opponent,[{"actor":unit.id,"target":opponent.id,"damage":2,"remaining":18,"hit":true,"crit":true}],{unit.id:unit.hp,opponent.id:20})
  await app.cinematic(opponent,unit,[{"actor":opponent.id,"target":unit.id,"damage":0,"remaining":unit.hp,"hit":false,"crit":false}],{unit.id:unit.hp,opponent.id:20})
  assert(app.game.save_data("battle")==before and app.game.rng.state==rng)
 var expected=[]
 for id in character_ids:expected.append_array([id,id])
 assert(actual==expected,"Real critical and missed exchanges use the styled imported fighters through the normal builder")
 nell.x=8;nell.y=4
 var before_finish=app.game.save_data("battle").duplicate(true);var finish_rng=app.game.rng.state
 await app.cinematic(nell,opponent,[{"actor":nell.id,"target":opponent.id,"damage":20,"remaining":0,"hit":true,"crit":false}],{nell.id:nell.hp,opponent.id:20})
 await app.cinematic(opponent,nell,[{"actor":opponent.id,"target":nell.id,"damage":nell.hp,"remaining":0,"hit":true,"crit":false}],{nell.id:nell.hp,opponent.id:20})
 assert(departures==1 and app.game.save_data("battle")==before_finish and app.game.rng.state==finish_rng,"Styled victory and defeat playback complete without changing resolved simulation state")
 watched=false;app.busy=false;app.show_debug_tools("battle");app.ui.find_child(toggle_name,true,false).button_pressed=false
 var disabled=app.make_fighter(nell,Vector3.ZERO);assert(disabled is Actor);disabled.queue_free();await process_frame
 app.ui.find_child(toggle_name,true,false).button_pressed=true
 var back=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Return to Options")[0]
 back.pressed.emit();await process_frame
 assert(app.screen=="options","Returning from battle debug tools does not access the discarded battle panel")
 app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Restore defaults")[0].pressed.emit();await process_frame
 assert(app.screen=="options","Rebuilding battle Options after restoring preferences also works")
 app.ui.find_child("DebugMode",true,false).button_pressed=false
 assert(not app.debug_session.active and not app.debug_session.get(setting_name) and app.game.save_data("camp")==original)
 assert(FileAccess.get_file_as_string(app.save_path)==disk and app.fighters.models.catalog==catalog,"Leaving the model experiment restores the campaign and leaves its disk save intact")
 app.debug_session.begin(app.game,"camp");assert(not app.debug_session.get(setting_name));app.debug_session.end(app.game)
 await Shutdown.dispose(app);await process_frame
 print("PASS: reversible debug model toggle, ",character_ids.size()*3," styled sword bindings, estoc/promotion/enemy/roster fallback, real outfit preview, critical/missed exchanges, victory/defeat playback, floor-safe standing dodges, report visibility, fresh-session reset and exact campaign/save/RNG isolation")
 quit()
