extends SceneTree
const Rules=preload("res://scripts/rules.gd")
const Settings=preload("res://scripts/campaign_settings.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")
func canonical(data):return JSON.parse_string(JSON.stringify(data))
func press(app,text_value):
 var buttons=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text==text_value)
 assert(buttons.size()==1 and not buttons[0].disabled);buttons[0].pressed.emit()
func skip(app):
 var key=InputEventKey.new();key.keycode=KEY_TAB;key.pressed=true;app._unhandled_input(key)
func run():
 root.size=Vector2i(1440,900)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-campaign-settings-%d.json"%Time.get_ticks_usec();root.add_child(app);await process_frame
 app.preferences.values.combat="map";app.preferences.values.auto_end=false
 # Title Options seed the proposed new rules, without requiring an existing save.
 app.show_options("title")
 for setting in Settings.SWITCHES:app.ui.find_child(setting.key,true,false).button_pressed=true
 app.show_campaign_rules();await process_frame
 for setting in Settings.SWITCHES:assert(app.ui.find_child(setting.key,true,false).button_pressed)
 var proposed=Settings.snapshot(app.game);var live=canonical(app.game.save_data("battle"));var rng=app.game.rng.state
 for size in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=size;await process_frame;await process_frame
  for setting in Settings.SWITCHES:
   var control=app.ui.find_child(setting.key,true,false);control.button_pressed=false
   var scroll=control.get_parent().get_parent();scroll.ensure_control_visible(control);await process_frame;await process_frame
   assert(scroll.get_global_rect().grow(1).encloses(control.get_global_rect()) and control.size.x>=control.get_minimum_size().x)
   var description=control.get_parent().get_child(control.get_index()+1)
   assert(description.text==setting.text)
  for title in ["Begin the chronicle","Return to title"]:
   var control=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text==title)[0]
   assert(Rect2(Vector2.ZERO,size).grow(1).encloses(control.get_global_rect()))
 assert(Settings.snapshot(app.game)==proposed and canonical(app.game.save_data("battle"))==live and app.game.rng.state==rng,"Creation toggles are a local draft")
 assert(not FileAccess.file_exists(app.save_path))
 press(app,"Return to title");assert(Settings.snapshot(app.game)==proposed and not FileAccess.file_exists(app.save_path))
 app.show_campaign_rules()
 for setting in Settings.SWITCHES:assert(app.ui.find_child(setting.key,true,false).button_pressed,"Cancelled drafts do not overwrite the previous rules")
 var escape=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true;app._unhandled_input(escape)
 assert(app.screen=="title" and Settings.snapshot(app.game)==proposed)
 var profiles=[[]]
 for setting in Settings.SWITCHES:profiles.append([setting.key])
 profiles.append(Settings.SWITCHES.map(func(setting):return setting.key))
 var starts=0
 for permanent in [false,true]:
  for enabled in profiles:
   app.game.new_campaign(not permanent);app.game.chapter=4;app.game.roster[1].fallen=true;app.game.roster[1].fallen_chapter=1;app.game.trials.pressure=4
   for setting in Settings.SWITCHES:Settings.set_enabled(app.game,setting.key,true)
   app.game.trials.losses={"oren":1};app.game.trials.credits=1;app.game.trials.volunteers=["faye"];app.game.trials.injuries={"sera":5};app.game.trials.purchases=["tempered_sword"]
   app.show_campaign_rules();var previous=canonical(app.game.save_data("camp"));var disk=FileAccess.get_file_as_string(app.save_path) if FileAccess.file_exists(app.save_path) else ""
   app.ui.find_child("Permadeath",true,false).button_pressed=permanent
   for setting in Settings.SWITCHES:app.ui.find_child(setting.key,true,false).button_pressed=setting.key in enabled
   assert(canonical(app.game.save_data("camp"))==previous)
   assert((FileAccess.get_file_as_string(app.save_path) if FileAccess.file_exists(app.save_path) else "")==disk)
   press(app,"Begin the chronicle");assert(app.screen=="dialogue" and app.game.permadeath==permanent and app.game.chapter==0)
   for setting in Settings.SWITCHES:assert(Settings.enabled(app.game,setting.key)==(setting.key in enabled))
   assert(app.game.lost_ids().is_empty() and app.game.trials.pressure==0 and app.game.trials.credits==0 and app.game.trials.volunteers.is_empty() and app.game.trials.injuries.is_empty() and app.game.trials.purchases.is_empty())
   app.finish_dialogue();assert(app.screen=="camp");press(app,"Deploy company  >")
   var deadline=Time.get_ticks_msec()+4000
   while app.busy and Time.get_ticks_msec()<deadline:skip(app);await process_frame
   assert(not app.busy and app.screen=="battle")
   var expected=Rules.new();expected.new_campaign(permanent);expected.story_seen=["opening_0"]
   for setting in Settings.SWITCHES:Settings.set_enabled(expected,setting.key,setting.key in enabled)
   expected.start_battle()
   assert(canonical(app.game.save_data("battle"))==canonical(expected.save_data("battle")),"First deployment uses exactly the chosen rules and fresh campaign consequences")
   var loaded=Rules.new();assert(loaded.load_game(app.save_path)=="battle" and canonical(loaded.save_data("battle"))==canonical(expected.save_data("battle")))
   app.show_options("battle")
   for setting in Settings.SWITCHES:
    var toggle=app.ui.find_child(setting.key,true,false);assert(toggle.button_pressed==(setting.key in enabled))
    toggle.button_pressed=not toggle.button_pressed;assert(Settings.enabled(app.game,setting.key)==toggle.button_pressed)
   starts+=1
 assert(starts==18)
 # Starting another chronicle inside Debug still writes only the sandbox slot.
 app.show_battle();var original=app.game.save_data("battle").duplicate(true);var saved_original=FileAccess.get_file_as_string(app.save_path)
 app.debug_session.begin(app.game,"battle");app.show_campaign_rules()
 for setting in Settings.SWITCHES:app.ui.find_child(setting.key,true,false).button_pressed=false
 press(app,"Begin the chronicle");app.finish_dialogue();press(app,"Deploy company  >")
 while app.busy:skip(app);await process_frame
 var debug_copy=Rules.new();assert(debug_copy.load_game(app.save_path+".debug")=="battle" and Settings.SWITCHES.all(func(setting):return not Settings.enabled(debug_copy,setting.key)))
 assert(FileAccess.get_file_as_string(app.save_path)==saved_original and app.debug_session.end(app.game)=="battle" and app.game.save_data("battle")==original)
 await Shutdown.dispose(app);await process_frame
 print("PASS: 18 actual new-campaign rule combinations, title-option inheritance, draft/cancel/file isolation, three-size reachable choices and fixed actions, exact first deployments/checkpoints, shared live Options and Debug-only new campaigns")
 quit()
