extends SceneTree
const Rules=preload("res://scripts/rules.gd")
const Session=preload("res://scripts/debug_session.gd")
const Encounters=preload("res://scripts/debug_encounters.gd")
const Imported=preload("res://scripts/imported_fighter.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")
func canonical(data):return JSON.parse_string(JSON.stringify(data))
func press_key(key,echo=false):
 for pressed in [true,false]:
  var event=InputEventKey.new();event.keycode=key;event.pressed=pressed;event.echo=echo;root.push_input(event,true)
func run():
 var game=Rules.new();game.start_battle();var session=Session.new();var original=game.save_data("battle").duplicate(true)
 assert(session.start_encounter(game,"sword").is_empty() and game.save_data("battle")==original)
 session.begin(game,"battle",true)
 assert(session.start_encounter(game,"unknown").is_empty() and game.save_data("battle")==original)
 for seed_value in [472019,17,309]:
  session.set_combat_seed(game,seed_value)
  for scene in Encounters.SCENES:
   var setup=session.start_encounter(game,scene.id);assert(not setup.is_empty())
   var snapshot=canonical(game.save_data("battle"));var positions=[]
   assert(game.valid_save(snapshot) and game.result()=="" and game.action_saves and not game.permadeath)
   assert(game.trials.flags.values().all(func(value):return not value))
   for unit in game.units:
    assert(game.pos(unit) not in positions and game.terrain(game.pos(unit)) not in ["#","~"]);positions.append(game.pos(unit))
   var a=game.units.filter(func(unit):return unit.id==setup.actor)[0];var b=game.units.filter(func(unit):return unit.id==setup.target)[0]
   assert(game.can_heal(a,b) if setup.healing else game.can_attack(a,b))
   var random=RandomNumberGenerator.new();random.seed=seed_value;assert(game.rng.state==random.state)
   if setup.healing:assert(game.heal(a,b))
   else:assert(not game.combat(a,b).is_empty())
   var loaded=Rules.new();assert(loaded.restore_save(game.save_data("battle"))=="battle")
   assert(canonical(loaded.save_data("battle"))==canonical(game.save_data("battle")))
   assert(not session.start_encounter(game,scene.id).is_empty() and canonical(game.save_data("battle"))==snapshot,"Staging again reproduces the same ordinary stats, positions and rolls")
 assert(session.end(game)=="battle" and game.save_data("battle")==original)
 await verify_controls()
 await verify_target_visibility()
 print("PASS: 24 deterministic playable encounters, eight legal attacks/heals, fresh rule isolation, saved replay, actual eight revised scene starters/actions, three-size controls and exact original campaign/file restoration")
 quit()
func verify_controls():
 root.size=Vector2i(1440,900)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-debug-encounters-%d.json"%Time.get_ticks_usec();root.add_child(app);await process_frame
 app.game.story_seen=["opening_0"];app.show_camp();assert(app.persist_campaign("camp"));var disk=FileAccess.get_file_as_string(app.save_path)
 app.game.roster[0].xp=17;var live=app.game.save_data("camp").duplicate(true)
 app.show_debug_encounters();assert(app.screen=="camp")
 app.preferences.values.character_models="revised";app.preferences.values.combat="all";app.preferences.values.auto_end=false
 var preferences=app.preferences.values.duplicate(true)
 app.show_options("camp");app.ui.find_child("DebugMode",true,false).button_pressed=true
 app.show_debug_tools("camp")
 app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Stage a combat encounter")[0].pressed.emit()
 var before=app.game.save_data("camp").duplicate(true)
 for dimensions in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions;await process_frame;await process_frame
  for scene in Encounters.SCENES:
   var button=app.ui.find_child("StageEncounter_"+scene.id,true,false);var scroll=button.get_parent().get_parent()
   scroll.ensure_control_visible(button);await process_frame;await process_frame
   assert(scroll.get_global_rect().grow(1).encloses(button.get_global_rect()))
   assert(button.size.x>=button.get_minimum_size().x and button.size.y>=36)
  var back=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Return to debug tools [Esc]")[0]
  assert(Rect2(Vector2.ZERO,dimensions).grow(1).encloses(back.get_global_rect()))
 assert(app.game.save_data("camp")==before)
 press_key(KEY_ESCAPE,true);assert(app.screen=="debug_encounters")
 press_key(KEY_ESCAPE);assert(app.screen=="debug_tools")
 app.preferences.values.combat="map";app.show_debug_encounters()
 assert(app.ui.find_child("EncounterMapMode",true,false)!=null and app.preferences.values.combat=="map","Scene starters explain the active map-only setting without overriding it")
 app.preferences.values.combat="all"
 for scene in Encounters.SCENES:
  app.show_debug_encounters();app.ui.find_child("StageEncounter_"+scene.id,true,false).pressed.emit();await process_frame;await process_frame
  assert(app.screen=="battle" and not app.busy and app.selected.id==scene.unit and app.cursor_visible)
  var loaded=Rules.new();assert(loaded.load_game(app.save_path+".debug")=="battle")
  assert(canonical(loaded.save_data("battle"))==canonical(app.game.save_data("battle")))
  assert(app.debug_session.report(app.game).recent_actions.entries[-1].reason=="encounter:"+scene.id)
  var actor=app.selected;var recipient=app.game.at(app.cursor_tile);var hp=recipient.hp
  if scene.id!="healing":
   var before_preview=app.game.save_data("battle").duplicate(true)
   press_key(KEY_ENTER)
   assert(app.target==recipient and not app.busy and is_instance_valid(app.forecast_panel) and app.game.save_data("battle")==before_preview,"The first Enter previews an attack without rolling or resolving it")
  press_key(KEY_ENTER);assert(app.busy and actor.acted,"Confirmation resolves the staged action through the actual battle controls")
  var saw_actor=false;var skip_sent=false;var deadline=Time.get_ticks_msec()+12000
  while app.busy and Time.get_ticks_msec()<deadline:
   await process_frame
   if is_instance_valid(app.reward_panel):app.reward_panel.request_continue()
   if app.stage.visible:
    var actors=app.stage.get_children().filter(func(node):return node is Imported)
    saw_actor=saw_actor or actors.size()==2
    if scene.id not in ["sword","healing"] and not skip_sent and actors.any(func(node):return node.pose_name in ["windup","cast_windup"]):press_key(KEY_TAB);skip_sent=true
  assert(not app.busy and saw_actor and not app.stage.visible,"The staged action reaches actual revised combat and returns")
  if scene.id=="healing":assert(recipient.hp>hp)
  assert(loaded.load_game(app.save_path+".debug")=="battle" and canonical(loaded.save_data("battle"))==canonical(app.game.save_data("battle")))
  assert(FileAccess.get_file_as_string(app.save_path)==disk and app.preferences.values==preferences)
 await verify_battle_shortcut(app)
 app.show_options("battle");app.ui.find_child("DebugMode",true,false).button_pressed=false
 assert(app.game.save_data("camp")==live and FileAccess.get_file_as_string(app.save_path)==disk and app.preferences.values==preferences)
 app.game.start_battle();app.make_map();app.selected=null;app.target=null;app.show_battle();app.show_battle_menu()
 assert(not app.ui.find_children("*","Button",true,false).any(func(button):return button.text=="Combat encounters"),"Normal campaigns do not expose the temporary encounter shortcut")
 await Shutdown.dispose(app);await process_frame

func verify_battle_shortcut(app):
 app.show_battle();app.selected=app.game.units[0];app.update_side()
 var snapshot=app.game.save_data("battle").duplicate(true);var camera=app.map_navigation.capture_view();var selected=app.selected
 var trace=app.debug_session.trace.report();var disk=FileAccess.get_file_as_string(app.save_path+".debug")
 for dimensions in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions;app.show_battle_menu();await process_frame;await process_frame
  var button=app.ui.find_children("*","Button",true,false).filter(func(item):return item.text=="Combat encounters")[0]
  var options=app.ui.find_children("*","Button",true,false).filter(func(item):return item.text=="Options / audio")[0]
  assert(Rect2(Vector2.ZERO,dimensions).grow(1).encloses(app.battle_menu.get_node("MenuFrame").get_global_rect()))
  assert(not button.get_global_rect().intersects(options.get_global_rect()) and button.size.x>=button.get_minimum_size().x and options.size.x>=options.get_minimum_size().x)
  options.grab_focus();press_key(KEY_RIGHT);assert(button.has_focus(),"The Debug shortcut is reachable horizontally from Options")
  press_key(KEY_ENTER);assert(app.screen=="debug_encounters" and app.encounter_return=="battle_menu")
  press_key(KEY_ESCAPE,true);assert(app.screen=="debug_encounters")
  press_key(KEY_ESCAPE);assert(app.screen=="battle_menu" and app.selected==selected)
  assert(app.game.save_data("battle")==snapshot and app.map_navigation.capture_view()==camera and app.debug_session.trace.report()==trace and FileAccess.get_file_as_string(app.save_path+".debug")==disk,"Browsing scenes and returning preserves the current position, RNG, selection, trace and written checkpoint")
  app.ui.find_children("*","Button",true,false).filter(func(item):return item.text=="Combat encounters")[0].pressed.emit()
  app.ui.find_children("*","Button",true,false).filter(func(item):return item.text=="Return to battle menu [Esc]")[0].pressed.emit()
  assert(app.screen=="battle_menu");app.close_battle_menu()

func verify_target_visibility():
 var viewport=SubViewport.new();viewport.size=Vector2i(1440,900);viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-encounter-view-%d.json"%Time.get_ticks_usec();viewport.add_child(app);await process_frame
 app.debug_session.begin(app.game,"camp")
 for dimensions in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
  viewport.size=dimensions;await process_frame
  assert(app.camera.get_viewport().get_visible_rect().size==Vector2(dimensions))
  for scene in Encounters.SCENES:
   app.show_debug_encounters();app.ui.find_child("StageEncounter_"+scene.id,true,false).pressed.emit();await process_frame;await process_frame
   assert(app.target==null and app.forecast_panel==null,"Starters show the tactical view until the player asks for a matchup")
   var recipient=app.game.at(app.cursor_tile);var bounds=app.unit_nodes[recipient.id].screen_bounds(app.camera)
   var safe=Rect2(Vector2(22,112),Vector2(dimensions.x-365,dimensions.y-222))
   assert(safe.encloses(bounds) and not bounds.intersects(app.terrain_card.get_global_rect()),"The actual recipient sprite remains visible before preview at all three viewport sizes")
   assert(app.markers.has_node("MapCursor"))
 await Shutdown.dispose(app);viewport.queue_free();await process_frame
