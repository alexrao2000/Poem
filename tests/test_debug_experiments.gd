extends SceneTree
const Rules=preload("res://scripts/rules.gd")
const Session=preload("res://scripts/debug_session.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")
func canonical(data):return JSON.parse_string(JSON.stringify(data))
func unit(game,id):return game.units.filter(func(u):return u.id==id)[0]
func press(app,text_value):
 var buttons=app.ui.find_children("*","Button",true,false).filter(func(b):return b.text==text_value)
 assert(buttons.size()==1 and not buttons[0].disabled);buttons[0].pressed.emit()
func consequences(game,session,id):
 if id=="committed_losses":
  assert(session.fall_unit(game,"oren") and game.trials.credits==1 and "faye" in game.trials.volunteers)
  assert(session.fall_unit(game,"lyra") and game.result()=="defeat")
  assert(game.retry_battle() and game.chapter==0 and game.trials.pressure==1 and "oren" in game.lost_ids())
  assert(game.trials.buy(game,"tempered_sword"))
 elif id=="reset_pressure":
  var positions={}
  for enemy in game.living("enemy"):positions[enemy.id]=game.pos(enemy);assert(enemy.held_tonics==2)
  assert(game.trials.restart(game));game.start_battle()
  assert(not game.permadeath and game.trials.pressure==1 and game.living("enemy").all(func(e):return e.held_tonics==1))
  assert(game.living("enemy").any(func(e):return e.get("raider",false) and game.pos(e)!=positions[e.id]))
 elif id=="rescue":
  assert(session.fall_unit(game,"oren"));var patient=unit(game,"oren")
  assert(game.DeathDoor.downed(patient) and patient.bleed_turns==2)
  assert(game.DeathDoor.rescue(game,unit(game,"lyra"),patient))
  assert(game.heal(unit(game,"ivo"),patient) and patient.hp>0 and patient.acted and patient.get("carried_by","").is_empty())
  assert(not "oren" in game.lost_ids())
 else:
  var attack=game.attack_power(unit(game,"lyra"))
  assert(session.fall_unit(game,"oren") and game.attack_power(unit(game,"lyra"))==attack+2)
  assert(game.trials.restart(game));game.start_battle();var patient=unit(game,"oren")
  assert(not game.permadeath and patient.hp==patient.max_hp-4 and patient.potions==1 and patient.recovering)
func run():
 var rules=Rules.new();rules.start_battle();var session=Session.new();var original=rules.save_data("battle").duplicate(true)
 assert(not session.start_experiment(rules,"rescue") and rules.save_data("battle")==original)
 session.begin(rules,"battle",true);assert(not session.start_experiment(rules,"unknown") and rules.save_data("battle")==original)
 session.set_combat_seed(rules,309)
 for id in ["committed_losses","reset_pressure","rescue","sacrifice"]:
  assert(session.start_experiment(rules,id));var start=canonical(rules.save_data("battle"))
  assert(rules.valid_save(start) and session.revised_knight and session.revised_enemies)
  consequences(rules,session,id)
  assert(session.start_experiment(rules,id) and canonical(rules.save_data("battle"))==start,"Each setup rebuilds deterministically after its consequences")
 assert(session.end(rules)=="battle" and rules.save_data("battle")==original)
 root.size=Vector2i(1440,900)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-debug-experiment-setups.json"
 root.add_child(app);await process_frame
 app.game.new_campaign(true);app.game.story_seen=["opening_0"];app.show_camp();assert(app.persist_campaign("camp"))
 var disk=FileAccess.get_file_as_string(app.save_path);app.game.roster[0].xp=17
 var live=app.game.save_data("camp").duplicate(true)
 app.show_debug_experiments();assert(app.screen=="camp")
 app.show_options("camp");app.ui.find_child("DebugMode",true,false).button_pressed=true
 app.debug_session.set_combat_seed(app.game,309)
 var expected_rng=RandomNumberGenerator.new();expected_rng.seed=309
 for id in ["committed_losses","reset_pressure","rescue","sacrifice"]:
  app.show_debug_tools("camp" if id=="committed_losses" else "battle")
  var before=app.game.save_data("battle").duplicate(true)
  press(app,"Choose an experiment setup");assert(app.screen=="debug_experiments")
  for dimensions in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
   app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions
   await process_frame;await process_frame
   var start_button=app.ui.find_child("StartExperiment_"+id,true,false)
   var scroll=start_button.get_parent().get_parent();scroll.ensure_control_visible(start_button)
   await process_frame;await process_frame
   assert(scroll.get_global_rect().grow(1).encloses(start_button.get_global_rect()),"Each setup can be reached at supported sizes")
   var back=app.ui.find_children("*","Button",true,false).filter(func(b):return b.text=="Return to debug tools")[0]
   assert(Rect2(Vector2.ZERO,dimensions).grow(1).encloses(back.get_global_rect()),"Return remains fixed outside the scrolling recipes")
  assert(app.game.save_data("battle")==before,"Browsing setups is read-only")
  press(app,"Return to debug tools");assert(app.screen=="debug_tools" and app.game.save_data("battle")==before)
  press(app,"Choose an experiment setup")
  var key=InputEventKey.new();key.pressed=true;key.keycode=KEY_ESCAPE;key.echo=true;app._unhandled_input(key)
  assert(app.screen=="debug_experiments","Held Escape does not cascade through setup menus")
  key.echo=false;app._unhandled_input(key)
  assert(app.screen=="debug_tools" and app.game.save_data("battle")==before,"Escape returns without changing the sandbox")
  press(app,"Choose an experiment setup");app.ui.find_child("StartExperiment_"+id,true,false).pressed.emit()
  assert(app.screen=="battle" and not app.busy and app.game.rng.state==expected_rng.state)
  var loaded=Rules.new();assert(loaded.load_game(app.save_path+".debug")=="battle")
  assert(canonical(loaded.save_data("battle"))==canonical(app.game.save_data("battle")),"Actual start buttons persist the complete setup only to Debug")
  assert(FileAccess.get_file_as_string(app.save_path)==disk)
  var report=app.debug_session.report(app.game)
  assert(report.recent_actions.entries[-1].reason=="experiment:"+id and report.recent_actions.entries[-1].persistence=="written")
  consequences(loaded,app.debug_session,id)
 app.show_options("battle");app.ui.find_child("DebugMode",true,false).button_pressed=false
 assert(not app.debug_session.active and app.game.save_data("camp")==live and FileAccess.get_file_as_string(app.save_path)==disk)
 await Shutdown.dispose(app);await process_frame
 print("PASS: four deterministic experiment starters, real consequences, guarded/reset behavior, actual menu controls at three sizes, separate saved setups, trace labels and exact campaign restoration")
 quit()
