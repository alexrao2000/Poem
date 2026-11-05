extends SceneTree
# Exercise real experimental controls and prove debug saves cannot replace the
# normal campaign. Restoration includes unsaved progress and simulation RNG.

const Rules=preload("res://scripts/rules.gd")
const Session=preload("res://scripts/debug_session.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")

func press(app,text_value: String):
 var buttons=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text==text_value)
 assert(buttons.size()==1 and not buttons[0].disabled,"Enabled debug control exists: "+text_value)
 buttons[0].pressed.emit()

func inspect(app):
 for dimensions in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions
  await process_frame;await process_frame
  for node in app.ui.find_children("*","Control",true,false):
   if not node.is_visible_in_tree():continue
   var parent=node.get_parent();var clipped=false
   while parent!=app.ui:
    if parent is ScrollContainer:clipped=true;break
    parent=parent.get_parent()
   if not clipped:assert(Rect2(Vector2.ZERO,dimensions).grow(1).encloses(node.get_global_rect()),"Debug fixed controls remain visible: "+app.screen)

func run():
 var rules=Rules.new();rules.new_campaign(true);rules.start_battle()
 var session=Session.new();var original=rules.save_data("battle").duplicate(true)
 session.load_chapter(rules,11);session.heal(rules);session.revive(rules);session.reset_battle(rules)
 assert(not session.set_combat_seed(rules,17) and session.report(rules).is_empty())
 assert(not session.test_pressure(rules,5),"Disabled debug cannot alter reset preparation")
 assert(rules.save_data("battle")==original,"Disabled debug methods cannot change gameplay")
 session.begin(rules,"battle");rules.turn=8;session.begin(rules,"camp")
 session.load_chapter(rules,-1);session.load_chapter(rules,12);assert(rules.turn==8,"Out-of-range chapter requests have no effect")
 assert(not session.set_combat_seed(rules,-1) and not session.set_combat_seed(rules,1.5) and not session.set_combat_seed(rules,"bad"))
 assert(session.set_combat_seed(rules,17));session.reset_battle(rules)
 var initial=rules.rng.state;var a=rules.units[0];var b=rules.living("enemy")[0];a.x=8;a.y=4;b.x=9;b.y=4
 var outcome=rules.combat(a,b);var state=rules.rng.state
 session.reset_battle(rules);assert(rules.rng.state==initial)
 a=rules.units[0];b=rules.living("enemy")[0];a.x=8;a.y=4;b.x=9;b.y=4
 assert(rules.combat(a,b)==outcome and rules.rng.state==state,"A seeded clean reset reproduces the actual exchange and random stream")
 var before_report=rules.save_data("battle").duplicate(true);var report=session.report(rules)
 assert(report.seed_for_new_attempts==17 and report.rng_state==str(state) and report.combatants.size()==rules.units.size() and rules.save_data("battle")==before_report,"Report inspection is read-only")
 var replay=Rules.new();assert(replay.import_code(report.save_code)=="battle" and replay.rng.state==state and replay.units[0].hp==a.hp,"Reports carry an exact restorable position")
 for invalid in [-1,11,1.5,"bad"]:assert(not session.test_pressure(rules,invalid))
 assert(session.test_pressure(rules,10) and rules.trials.pressure==10 and rules.trials.flags.reset_pressure and rules.turn==1)
 assert(rules.rng.state==initial and rules.living("enemy").all(func(enemy):return enemy.held_tonics==0),"Pressure test rebuilds with the chosen seed and depleted supplies")
 assert(session.report(rules).next_deployment_enemy_bonuses.pow==10)
 assert(session.end(rules)=="battle" and rules.save_data("battle")==original,"Repeated enabling never overwrites the original checkpoint")
 root.size=Vector2i(1440,900)
 var app=load("res://main.tscn").instantiate();app.settings_path="/private/tmp/poem-debug-preferences.json";app.save_path="/private/tmp/poem-debug-campaign.json"
 root.add_child(app);await process_frame
 app.game.new_campaign(true);app.game.story_seen=["opening_0"];app.show_camp();assert(app.persist_campaign("camp"))
 var disk=FileAccess.get_file_as_string(app.save_path)
 app.game.roster[0].xp=17
 var live=app.game.save_data("camp").duplicate(true)
 app.show_debug_tools("camp");assert(app.screen=="camp","Hidden tools cannot be opened before enabling debug")
 app.show_options("camp");app.ui.find_child("DebugMode",true,false).button_pressed=true
 assert(app.debug_session.active and app.campaign_save_path()==app.save_path+".debug")
 await inspect(app)
 app.ui.find_child("Permadeath",true,false).button_pressed=false
 assert(not app.game.permadeath,"Experimental rule toggle applies immediately")
 press(app,"Open debug tools");await inspect(app)
 app.ui.find_child("DebugSeed",true,false).value=309;press(app,"Apply seed to next rolls")
 assert(app.debug_session.combat_seed==309)
 press(app,"View experiment report");await inspect(app)
 var report_text=app.ui.find_child("DebugReport",true,false)
 assert(not report_text.editable and JSON.parse_string(report_text.text).seed_for_new_attempts==309)
 assert(report_text.text.find("\"settings\"")<report_text.text.find("\"save_code\""),"Readable report settings precede the long restore code")
 assert(app.ui.find_children("*","Button",true,false).any(func(button):return button.text=="Copy restore code" and not button.disabled))
 press(app,"Return to debug tools")
 var chooser=app.ui.find_child("DebugChapter",true,false)
 assert(chooser.item_count==12);chooser.select(11);press(app,"Load chapter with fresh roster")
 assert(app.screen=="battle" and app.game.chapter==11 and not app.game.permadeath and app.game.phase=="player","Chapter loader opens the actual chosen map with the experimental rule")
 assert("DEBUG" in app.status.text and not app.busy)
 var expected_rng=RandomNumberGenerator.new();expected_rng.seed=309
 assert(app.game.rng.state==expected_rng.state,"Fresh chapter loads use the chosen seed")
 var loaded=Rules.new();assert(loaded.load_game(app.save_path+".debug")=="battle" and loaded.chapter==11,"Debug actions persist into the separate slot")
 assert(FileAccess.get_file_as_string(app.save_path)==disk,"Chapter jump cannot overwrite the normal save")
 app.show_debug_tools("battle");await inspect(app)
 app.ui.find_child("DebugPressure",true,false).value=5;press(app,"Test pressure and reset battle")
 assert(app.screen=="battle" and app.game.trials.pressure==5 and app.game.trials.flags.reset_pressure)
 assert(loaded.load_game(app.save_path+".debug")=="battle" and loaded.trials.pressure==5 and FileAccess.get_file_as_string(app.save_path)==disk,"Pressure changes persist only in debug")
 var ally=app.game.living("player")[0];ally.hp=1;ally.acted=true;var rng=app.game.rng.state
 app.show_debug_tools("battle");press(app,"Heal deployed allies")
 assert(ally.hp==ally.max_hp and ally.acted and app.game.rng.state==rng,"Healing changes only health and preserves action/RNG state")
 app.game.roster[1].fallen=true;app.game.roster[1].fallen_chapter=0;app.game.roster[1].hp=0;app.game.deployed.erase(app.game.roster[1].id)
 press(app,"Revive company and reset battle")
 assert(app.game.lost_ids().is_empty() and app.game.units.any(func(unit):return unit.id=="oren" and unit.hp==unit.max_hp),"Revival clears memorials and rebuilds a legal full-health deployment")
 app.game.units[0].hp=1;app.game.turn=9
 app.show_debug_tools("battle");press(app,"Reset current battle")
 assert(app.game.turn==1 and app.game.units[0].hp==app.game.units[0].max_hp,"Reset starts the current chapter from preparation")
 app.show_debug_tools("battle");press(app,"Return to preparation");assert(app.screen=="camp" and app.game.units.is_empty())
 app.show_options("camp");app.ui.find_child("DebugMode",true,false).button_pressed=false
 assert(not app.debug_session.active and app.game.save_data("camp")==live,"Disabling debug restores the exact unsaved campaign, original rule and RNG")
 app.close_options();assert(app.screen=="camp" and app.campaign_save_path()==app.save_path)
 assert(loaded.load_game(app.save_path)=="camp" and loaded.roster[0].xp==17 and loaded.permadeath,"Normal saving resumes only after restoring the original campaign")
 app.show_options("camp");app.ui.find_child("Permadeath",true,false).button_pressed=false;app.close_options()
 assert(loaded.load_game(app.save_path)=="camp" and not loaded.permadeath,"Permadeath can be changed and saved outside debug as requested")
 await Shutdown.dispose(app);await process_frame
 print("PASS: opt-in debug controls, twelve-chapter chooser, heal/revive/reset, separate save slot, unsaved checkpoint restoration, guarded actions, three layouts and live permadeath toggle persistence")
 quit()
