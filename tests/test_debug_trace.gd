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
 var displayed=JSON.parse_string(app.ui.find_child("DebugReport",true,false).text)
 assert(canonical(displayed.recent_actions)==canonical(trace.report()) and app.game.save_data("battle")==state and app.game.rng.state==rng)
 assert(FileAccess.get_file_as_string(app.save_path)==disk,"Debug actions never replace the normal save")
 app.show_options("battle");app.ui.find_child("DebugMode",true,false).button_pressed=false
 assert(canonical(app.game.save_data("battle"))==canonical(original) and trace.entries.is_empty() and FileAccess.get_file_as_string(app.save_path)==disk)
 await Shutdown.dispose(app)
