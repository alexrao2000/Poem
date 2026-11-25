extends SceneTree
const Rules=preload("res://scripts/rules.gd")
const Session=preload("res://scripts/debug_session.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")
func canonical(data):return JSON.parse_string(JSON.stringify(data))

func observe(session,game,reason,persistence="written"):
 var state=game.save_data("battle").duplicate(true);var rng=game.rng.state
 session.observe(game,"battle",reason,persistence)
 assert(game.save_data("battle")==state and game.rng.state==rng,"Diagnostics cannot modify the simulation")
 return session.trace.entries[-1]

func run():
 var game=Rules.new();game.new_campaign(true);game.death_door=true;game.action_saves=true;game.trials.flags.death_legacies=true;game.start_battle()
 var a=game.units[0];var patient=game.units[1];var medic=game.units[3]
 a.x=2;a.y=3;patient.x=3;patient.y=2;medic.x=1;medic.y=2
 var original=game.save_data("battle").duplicate(true);var session=Session.new();session.begin(game,"battle")
 assert(game.move_unit(a,Vector2i(2,2)))
 var entry=observe(session,game,"move")
 assert(entry.units.size()==1 and entry.units[0].id==a.id and entry.units[0].changes.y=={"before":3,"after":2})
 var count=session.trace.entries.size();session.observe(game,"battle","save","written");assert(session.trace.entries.size()==count,"An unchanged routine save is not another action")
 patient.hp=0;game.DeathDoor.fall(game,patient);entry=observe(session,game,"fall")
 assert(entry.units[0].changes.downed.after==true and entry.units[0].changes.hp.after==0)
 assert(game.DeathDoor.rescue(game,a,patient));entry=observe(session,game,"rescue")
 var patient_change=entry.units.filter(func(unit):return unit.id==patient.id)[0]
 assert(patient_change.changes.carried_by.after==a.id,"Trace captures the rescue relationship")
 assert(game.heal(medic,patient));entry=observe(session,game,"heal")
 patient_change=entry.units.filter(func(unit):return unit.id==patient.id)[0]
 assert(patient_change.changes.hp.after>0 and patient_change.changes.carried_by.after==null,"Healing records recovery and release from carrying")
 game.death_door=false;patient.hp=0;game.DeathDoor.fall(game,patient);game.commit_casualties();entry=observe(session,game,"fall")
 assert(entry.changes.credits.before==0 and entry.changes.credits.after==1 and patient.id in entry.changes.casualties.after,"Permanent losses retain legacy and casualty consequences")
 game.rng.randi();entry=observe(session,game,"roll")
 assert(entry.rng_before!=entry.rng_after)
 a.acted=false;a.moved=false;assert(game.wait_unit(a));entry=observe(session,game,"wait","not_requested")
 assert(entry.persistence=="not_requested")
 entry=observe(session,game,"save","written");assert(entry.persistence=="written" and entry.units.is_empty(),"A later successful save remains explicit")
 for index in range(70):game.turn+=1;observe(session,game,"turn")
 var report=session.report(game);assert(report.report_version==2 and report.recent_actions.volatile and report.recent_actions.entries.size()==64 and report.recent_actions.discarded>0)
 var retained=session.trace.entries.duplicate(true);report.recent_actions.entries[0].changes.clear();assert(session.trace.entries==retained,"Editing the report cannot alter retained evidence")
 var imported=Rules.new();assert(imported.import_code(report.save_code)=="battle" and not imported.save_data("battle").has("recent_actions"),"Action history is absent from transfer saves")
 session.end(game);assert(canonical(game.save_data("battle"))==canonical(original) and session.trace.entries.is_empty() and session.trace.baseline.is_empty())
 session.observe(game,"battle","inactive","written");assert(session.trace.entries.is_empty())
 await verify_app()
 await verify_summary()
 print("PASS: bounded read-only Debug history for movement, rescue, recovery, permanent losses, legacy credit and RNG; actual checkpoint/save-failure/retry/import/report flows preserve the normal campaign")
 quit()

func verify_app():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-debug-trace-%d.json"%Time.get_ticks_usec()
 root.add_child(app);await process_frame
 app.game.start_battle();app.make_map();app.show_battle();app.preferences.values.auto_end=false
 var original=app.game.save_data("battle").duplicate(true);assert(app.persist_campaign("battle"));var disk=FileAccess.get_file_as_string(app.save_path)
 assert(app.debug_session.trace.entries.is_empty(),"Ordinary campaign saves do not collect diagnostics")
 app.show_options("battle");app.ui.find_child("DebugMode",true,false).button_pressed=true
 app.game.action_saves=true;app.show_battle()
 var unit=app.game.living("player")[0];app.selected=unit
 var destination=app.game.reachable(unit).keys().filter(func(point):return point!=app.game.pos(unit) and app.game.at(point)==null)[0]
 app.click_tile(destination)
 var trace=app.debug_session.trace;var entry=trace.entries[-1]
 assert(app.busy and entry.reason=="move" and entry.persistence=="written","Debug records the committed move before its animation")
 while app.busy:await process_frame
 var code=app.game.export_code("battle");var working_path=app.save_path
 app.save_path=working_path+"/missing/save.json";app.selected=unit;app.wait_action()
 assert(app.save_failed and trace.entries[-1].reason=="wait" and trace.entries[-1].persistence=="failed")
 app.save_path=working_path;await app.retry_action_save()
 assert(not app.save_failed and trace.entries[-1].persistence=="written" and trace.entries[-1].units.is_empty(),"Retry records persistence without replaying the action")
 var count=trace.entries.size();assert(app.persist_campaign("battle"));assert(trace.entries.size()==count)
 app.show_save_transfer("battle");app.transfer_text.text=code;await app.import_pasted_save()
 assert(trace.entries[-1].reason=="import","Replacing a Debug position is an explicit history boundary")
 app.preferences.values.combat="map"
 var attacker=app.game.living("player")[0];var foe=app.game.living("enemy")[0]
 attacker.x=8;attacker.y=4;attacker.speed=255;attacker.pow=255;attacker.acted=false
 foe.x=9;foe.y=4;foe.hp=1
 app.debug_session.observe(app.game,"battle","fixture","not_requested")
 app.make_map();app.show_battle();app.selected=attacker;app.target=foe
 app.player_attack();entry=trace.entries[-1]
 assert(entry.reason=="attack" and entry.rng_before!=entry.rng_after and entry.units.any(func(unit_change):return unit_change.id==foe.id and unit_change.changes.hp.after==0),"Actual combat records its random sequence and defeat before presentation")
 while app.busy:
  await process_frame
  if is_instance_valid(app.reward_panel):app.reward_panel.request_continue()
 var ally=app.game.living("player")[1];ally.hp=ally.max_hp-5;ally.acted=false;app.game.action_saves=false
 app.debug_session.observe(app.game,"battle","fixture","not_requested")
 app.refresh_pieces();app.selected=ally;app.tonic()
 assert(trace.entries[-1].reason=="tonic" and trace.entries[-1].persistence=="not_requested","Disabled action checkpoints remain distinguishable from saved actions")
 while app.busy:await process_frame
 assert(trace.entries[-1].persistence=="written" and trace.entries[-1].units.is_empty(),"End-of-action autosave records the later write")
 var state=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state
 app.show_debug_tools("battle");app.show_debug_report();await process_frame
 var report_text=app.ui.find_child("DebugReport",true,false).text
 var displayed=JSON.parse_string(report_text)
 assert(canonical(displayed.recent_actions)==canonical(trace.report()) and app.game.save_data("battle")==state and app.game.rng.state==rng)
 var trace_before=trace.report()
 var debug_path=app.campaign_save_path()
 var debug_disk=FileAccess.get_file_as_string(debug_path)
 var save_report=app.ui.find_child("SaveDebugReport",true,false)
 var output=app.save_path.get_basename()+"-report.json"
 save_report.pressed.emit();await process_frame
 var picker=app.ui.find_child("DebugReportFilePicker",true,false)
 assert(picker.file_mode==FileDialog.FILE_MODE_SAVE_FILE and picker.current_file.begins_with("poem-experiment-ch01-turn-01-seed-"))
 picker.canceled.emit();await process_frame
 assert(not FileAccess.file_exists(output) and app.ui.find_child("DebugReportFilePicker",true,false)==null)
 save_report.pressed.emit();await process_frame
 app.ui.find_child("DebugReportFilePicker",true,false).file_selected.emit(output);await process_frame
 assert(FileAccess.get_file_as_string(output)==report_text)
 var exported=JSON.parse_string(FileAccess.get_file_as_string(output))
 var restored=Rules.new();assert(restored.import_code(exported.save_code)=="battle")
 assert(canonical(restored.save_data("battle"))==canonical(state))
 save_report.pressed.emit();await process_frame
 app.ui.find_child("DebugReportFilePicker",true,false).file_selected.emit(output.path_join("unwritable.json"));await process_frame
 assert(FileAccess.get_file_as_string(output)==report_text and trace.report()==trace_before)
 assert(app.game.save_data("battle")==state and app.game.rng.state==rng)
 assert(FileAccess.get_file_as_string(debug_path)==debug_disk)
 print("PASS: Debug saves exactly the displayed report and restores its code without changing either campaign save")
 app.game.rng.randi()
 assert(app.game.rng.state!=rng and app.persist_campaign("battle",true,"fixture"))
 var changed_disk=FileAccess.get_file_as_string(debug_path)
 app.show_battle()
 app.show_save_transfer("battle");await process_frame
 var field=app.transfer_text
 var changed_code=field.text
 assert(changed_code!=exported.save_code)
 var damaged_path=output.get_basename()+"-damaged.json"
 var damaged=FileAccess.open(damaged_path,FileAccess.WRITE);damaged.store_string("{\"debug\":");damaged.close()
 var open_report=app.ui.find_child("OpenSaveCodeFile",true,false)
 open_report.pressed.emit();await process_frame
 app.ui.find_child("SaveCodeFilePicker",true,false).file_selected.emit(damaged_path);await process_frame
 assert(field.text==changed_code and FileAccess.get_file_as_string(debug_path)==changed_disk)
 open_report.pressed.emit();await process_frame
 var report_picker=app.ui.find_child("SaveCodeFilePicker",true,false)
 assert(report_picker.filters[0].contains("*.json"))
 report_picker.file_selected.emit(output);await process_frame
 assert(field.text==exported.save_code and field.has_focus())
 assert(app.game.rng.state!=rng and FileAccess.get_file_as_string(debug_path)==changed_disk)
 await app.import_pasted_save()
 assert(app.screen=="battle" and canonical(app.game.save_data("battle"))==canonical(state))
 assert(trace.entries[-1].reason=="import" and app.game.rng.state==rng)
 var persisted=Rules.new(app.game.content)
 assert(persisted.load_game(debug_path)=="battle" and canonical(persisted.save_data("battle"))==canonical(state))
 assert(FileAccess.get_file_as_string(app.save_path)==disk,"Debug actions never replace the normal save")
 app.show_options("battle");app.ui.find_child("DebugMode",true,false).button_pressed=false
 assert(canonical(app.game.save_data("battle"))==canonical(original) and trace.entries.is_empty() and FileAccess.get_file_as_string(app.save_path)==disk)
 app.show_battle()
 app.show_save_transfer("battle");await process_frame
 var ordinary_code=app.transfer_text.text
 app.ui.find_child("OpenSaveCodeFile",true,false).pressed.emit()
 app.ui.find_child("SaveCodeFilePicker",true,false).file_selected.emit(output);await process_frame
 assert(app.transfer_text.text==ordinary_code and FileAccess.get_file_as_string(app.save_path)==disk)
 assert(DirAccess.remove_absolute(damaged_path)==OK and DirAccess.remove_absolute(output)==OK)
 print("PASS: an exported report stages its restore code only in Debug, and explicit import restores the exact saved battle")
 await Shutdown.dispose(app)

func verify_summary():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-debug-summary-%d.json"%Time.get_ticks_usec();root.add_child(app);await process_frame
 app.game.story_seen=["opening_0"];app.show_camp();assert(app.persist_campaign("camp"))
 var original=app.game.save_data("camp").duplicate(true);var normal_disk=FileAccess.get_file_as_string(app.save_path)
 app.debug_session.begin(app.game,"camp")
 var game=app.game;game.new_campaign(true);game.chapter=1;game.action_saves=true
 for flag in ["death_legacies","sacrifice_cost","reset_pressure"]:game.trials.flags[flag]=true
 game.trials.pressure=2;game.deployed=game.available().map(func(unit):return unit.id);game.start_battle()
 var fallen=game.units.filter(func(unit):return unit.id=="oren")[0];fallen.hp=0;game.commit_casualties()
 game.death_door=true
 for id in ["sera","ivo"]:
  var unit=game.units.filter(func(candidate):return candidate.id==id)[0];unit.hp=0;game.DeathDoor.fall(game,unit)
 var carrier=game.units.filter(func(unit):return unit.id=="lyra")[0];var patient=game.units.filter(func(unit):return unit.id=="ivo")[0]
 patient.x=carrier.x+1;patient.y=carrier.y;assert(game.DeathDoor.rescue(game,carrier,patient))
 game.trials.injuries.mara=game.chapter+1
 assert(game.valid_save(game.save_data("battle")) and app.persist_campaign("battle"))
 var debug_disk=FileAccess.get_file_as_string(app.save_path+".debug");var preferences=app.preferences.values.duplicate(true)
 for stage in ["battle","camp"]:
  for permanent in [true,false]:
   game.permadeath=permanent;app.options_return=stage
   var state=game.save_data("battle").duplicate(true);var trace=app.debug_session.trace.report()
   app.show_debug_report()
   for dimensions in [Vector2(720,640),Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
    app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions;await process_frame;await process_frame
    var position=app.ui.find_child("DebugReportPosition",true,false);var summary=app.ui.find_child("DebugReportSummary",true,false);var report=app.ui.find_child("DebugReport",true,false)
    assert(position.text.contains("Chapter 02") and position.text.contains("Permadeath "+("ON" if permanent else "OFF")))
    assert(position.text.contains("War council") if stage=="camp" else position.text.contains("Turn 1 · Player phase"))
    assert(summary.text.contains("Fallen: 1") and summary.text.contains("Recovering next: 1") and summary.text.contains("Pressure: 2") and summary.text.contains("Credits: 1"))
    if stage=="battle":assert(summary.text.contains("Awaiting rescue: 1") and summary.text.contains("Carried: 1"),"A carried patient is not counted twice")
    else:assert(not summary.text.contains("Awaiting rescue") and not summary.text.contains("Carried"),"Preparation does not report stale battle patients")
    for control in [position,summary,report]+app.ui.find_children("*","Button",true,false):
     assert(Rect2(Vector2.ZERO,dimensions).grow(1).encloses(control.get_global_rect()),"%s must fit the %s report viewport, got %s"%[control.name,dimensions,control.get_global_rect()])
     assert(control.size.x>=control.get_minimum_size().x and control.size.y>=control.get_minimum_size().y)
    assert(position.get_global_rect().end.y<=summary.get_global_rect().position.y and summary.get_global_rect().end.y<=report.get_global_rect().position.y)
    var displayed=JSON.parse_string(report.text);assert(displayed.report_version==2);displayed.erase("presentation")
    assert(canonical(displayed)==canonical(app.debug_session.report(game,stage)),"Summary leaves copied JSON and restore data unchanged")
   assert(game.save_data("battle")==state and app.debug_session.trace.report()==trace and app.preferences.values==preferences)
   assert(FileAccess.get_file_as_string(app.save_path)==normal_disk and FileAccess.get_file_as_string(app.save_path+".debug")==debug_disk)
 game.trials.flags.sacrifice_cost=false;app.show_debug_report()
 assert(app.ui.find_child("DebugReportSummary",true,false).text.contains("Recovering next: 0"),"Stored injuries are inactive when the experiment is disabled")
 assert(app.debug_session.end(game)=="camp" and game.save_data("camp")==original)
 await Shutdown.dispose(app)
