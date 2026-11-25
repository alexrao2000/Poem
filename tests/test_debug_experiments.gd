extends SceneTree
const Rules=preload("res://scripts/rules.gd")
const Session=preload("res://scripts/debug_session.gd")
const Tactics=preload("res://scripts/tactics.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
const SETUP_IDS=["committed_losses","reset_pressure","section_retreat","rescue","last_rescue","legacy_recruits","sacrifice","aqueduct_retry"]
func _initialize():call_deferred("run")
func canonical(data):return JSON.parse_string(JSON.stringify(data))
func unit(game,id):return game.units.filter(func(u):return u.id==id)[0]
func press(app,text_value):
 var buttons=app.ui.find_children("*","Button",true,false).filter(func(b):return b.text==text_value)
 assert(buttons.size()==1 and not buttons[0].disabled);buttons[0].pressed.emit()
func settle(app):
 var deadline=Time.get_ticks_msec()+20000
 while app.busy and Time.get_ticks_msec()<deadline:
  await process_frame
  if is_instance_valid(app.reward_panel):app.reward_panel.request_continue()
  var card=app.ui.get_node_or_null("CasualtyCard")
  if card!=null:card.dismissed=true
 assert(not app.busy)
func saved_setup(app):
 var saved=Rules.new();assert(saved.load_game(app.save_path+".debug")=="battle")
 assert(canonical(saved.save_data("battle"))==canonical(app.game.save_data("battle")))
func consequences(game,session,id):
 if id=="committed_losses":
  assert(session.fall_unit(game,"oren") and game.trials.credits==1 and "faye" in game.trials.volunteers)
  assert(session.fall_unit(game,"lyra") and game.result()=="defeat")
  assert(game.retry_battle() and game.chapter==0 and game.trials.pressure==1 and "oren" in game.lost_ids())
  assert(game.trials.buy(game,"tempered_sword"))
 elif id=="reset_pressure":
  assert(unit(game,"lyra").hp==1 and game.pos(unit(game,"lyra"))==Vector2i(8,4))
  var positions={}
  for enemy in game.living("enemy"):positions[enemy.id]=game.pos(enemy);assert(enemy.held_tonics==2)
  assert(game.trials.restart(game));game.start_battle()
  assert(not game.permadeath and game.trials.pressure==1 and game.living("enemy").all(func(e):return e.held_tonics==1))
  assert(game.living("enemy").any(func(e):return e.get("raider",false) and game.pos(e)!=positions[e.id]))
 elif id=="section_retreat":
  assert(game.chapter==5 and game.trials.checkpoint.chapter==4 and game.permadeath)
  assert(game.lost_ids()==["oren"] and game.trials.credits==1 and game.trials.losses.oren==5)
  assert(game.trials.restart(game) and game.chapter==4 and game.trials.pressure==1)
  assert(game.lost_ids()==["oren"] and game.trials.credits==1 and "oren" not in game.deployed)
  assert("relief_4" in game.trials.earned_scenes and "memorial_4" in game.trials.earned_scenes and "retreat_4" in game.trials.earned_scenes)
 elif id=="rescue":
  assert(session.fall_unit(game,"oren"));var patient=unit(game,"oren")
  assert(game.DeathDoor.downed(patient) and patient.bleed_turns==2)
  assert(game.DeathDoor.rescue(game,unit(game,"lyra"),patient))
  assert(game.heal(unit(game,"ivo"),patient) and patient.hp>0 and patient.acted and patient.get("carried_by","").is_empty())
  assert(not "oren" in game.lost_ids())
 elif id=="last_rescue":
  var patient=unit(game,"oren");var carrier=unit(game,"lyra");var healer=unit(game,"ivo")
  assert(game.DeathDoor.downed(patient) and patient.bleed_turns==1 and healer.acted and not game.can_heal(healer,patient))
  var abandoned=Rules.new();assert(abandoned.restore_save(game.save_data("battle"))=="battle")
  abandoned.begin_enemy_phase();assert("oren" in abandoned.lost_ids() and not abandoned.DeathDoor.downed(unit(abandoned,"oren")),"Ignoring the last tick commits the actual permanent loss")
  assert(game.DeathDoor.rescue(game,carrier,patient));game.begin_enemy_phase()
  assert(patient.bleed_turns==1 and "oren" not in game.lost_ids())
  var planner=Tactics.new()
  for enemy in game.living("enemy"):
   if not enemy.acted:planner.apply_plan(game,enemy,planner.plan(game,enemy))
  assert(game.result()=="");game.next_player_turn()
  assert(game.move_unit(carrier,Vector2i(1,4)) and game.can_heal(healer,patient))
  assert(game.heal(healer,patient) and patient.hp>0 and patient.acted and patient.get("carried_by","").is_empty())
  assert(not "oren" in game.lost_ids() and game.valid_save(game.save_data("battle")))
 elif id=="legacy_recruits":
  var snapshot=game.save_data("battle").duplicate(true)
  var healer=unit(game,"esme")
  assert(game.roster.size()==24 and game.trials.volunteers.is_empty())
  for id_to_save in ["ivo","sera"]:
   var branch=Rules.new();assert(branch.restore_save(snapshot)=="battle")
   var patient=unit(branch,id_to_save)
   assert(branch.DeathDoor.downed(patient) and patient.bleed_turns==1)
   assert(branch.heal(unit(branch,healer.id),patient))
   branch.begin_enemy_phase()
   var expected="tovin" if id_to_save=="ivo" else "maelin"
   var other="maelin" if id_to_save=="ivo" else "tovin"
   assert(expected in branch.trials.volunteers and other not in branch.trials.volunteers and branch.trials.credits==1)
   assert(branch.trials.restart(branch) and branch.chapter==0 and branch.available().any(func(unit):return unit.id==expected))
  game.begin_enemy_phase()
  assert(game.trials.credits==2 and game.trials.earned_scenes.has("volunteer_maelin") and game.trials.earned_scenes.has("volunteer_tovin"))
 elif id=="sacrifice":
  assert(unit(game,"oren").hp==1 and unit(game,"enemy_4").hp==6 and game.action_saves)
  var attack=game.attack_power(unit(game,"lyra"))
  assert(session.fall_unit(game,"oren") and game.attack_power(unit(game,"lyra"))==attack+2)
  assert(game.trials.restart(game));game.start_battle();var patient=unit(game,"oren")
  assert(not game.permadeath and patient.hp==patient.max_hp-4 and patient.potions==1 and patient.recovering)
 else:
  assert(id=="aqueduct_retry" and game.chapter==7 and not game.permadeath and game.trials.pressure==1)
  var lyra=unit(game,"lyra");var tarin=unit(game,"tarin")
  assert(game.DeathDoor.downed(lyra) and lyra.bleed_turns==1 and game.can_heal(unit(game,"ivo"),lyra))
  assert(game.DeathDoor.downed(tarin) and tarin.bleed_turns==1 and game.DeathDoor.can_rescue(game,unit(game,"oren"),tarin))
  var enemy_preparation={}
  for enemy in game.living("enemy"):
   assert(enemy.held_tonics==1)
   enemy_preparation[enemy.id]={"pos":game.pos(enemy),"hp":enemy.max_hp,"pow":enemy.pow}
  game.begin_enemy_phase()
  assert(game.result()=="defeat" and game.lost_ids().is_empty() and game.trials.credits==0)
  assert(game.retry_battle() and game.chapter==7 and game.trials.pressure==2)
  game.start_battle()
  assert(game.living("enemy").all(func(enemy):return enemy.held_tonics==0))
  assert(game.living("enemy").any(func(enemy):return enemy.get("raider",false) and game.pos(enemy)!=enemy_preparation[enemy.id].pos))
  for enemy in game.living("enemy"):
   assert(enemy.max_hp==mini(game.STAT_CAPS.max_hp,enemy_preparation[enemy.id].hp+2))
   assert(enemy.pow==mini(game.STAT_CAPS.pow,enemy_preparation[enemy.id].pow+1))
  for patient in [unit(game,"lyra"),unit(game,"tarin")]:
   assert(patient.hp==patient.max_hp-4 and patient.potions==1 and patient.recovering)

func verify_aqueduct(app,disk):
 var game=app.game
 app.show_debug_experiments();app.ui.find_child("StartExperiment_aqueduct_retry",true,false).pressed.emit()
 await process_frame;await process_frame
 assert(app.ui.find_child("EndPlayerPhase",true,false).text=="End phase · 2 will fall")
 app.click_tile(game.pos(unit(game,"ivo")));app.click_tile(game.pos(unit(game,"lyra")))
 await settle(app);saved_setup(app)
 assert(unit(game,"lyra").hp>0 and not game.DeathDoor.downed(unit(game,"lyra")))
 app.click_tile(game.pos(unit(game,"oren")));app.click_tile(game.pos(unit(game,"tarin")))
 assert(app.screen=="triage");press(app,"Rescue Tarin")
 await settle(app);saved_setup(app)
 assert(unit(game,"tarin").carried_by=="oren" and unit(game,"tarin").bleed_turns==1)
 assert(app.screen=="battle" and game.trials.pressure==1)
 app.show_debug_experiments();app.ui.find_child("StartExperiment_aqueduct_retry",true,false).pressed.emit()
 await process_frame;await process_frame
 app.ui.find_child("EndPlayerPhase",true,false).pressed.emit()
 await settle(app);saved_setup(app)
 assert(app.screen=="result" and game.result()=="defeat")
 assert(app.ui.find_child("RestartPreview",true,false).text.contains("Return to Chapter 08 · Pressure 1 → 2"))
 assert(app.ui.find_child("DefeatRecovery",true,false).text.contains("Tarin"))
 press(app,"Regroup and retry")
 assert(app.screen=="camp" and game.chapter==7 and game.trials.pressure==2)
 var camp=Rules.new();assert(camp.load_game(app.save_path+".debug")=="camp")
 assert(canonical(camp.save_data("camp"))==canonical(game.save_data("camp")))
 press(app,"Deploy company  >");await settle(app);saved_setup(app)
 assert(app.screen=="battle" and game.chapter==7 and game.trials.pressure==2)
 assert(unit(game,"tarin").hp==unit(game,"tarin").max_hp-4 and unit(game,"tarin").potions==1)
 assert(game.lost_ids().is_empty() and game.living("enemy").all(func(enemy):return enemy.held_tonics==0))
 assert(FileAccess.get_file_as_string(app.save_path)==disk)
 print("PASS: the actual Old Aqueduct setup rescues both patients or advances the same chapter to pressure two with recoverable injuries")

func run():
 var rules=Rules.new();rules.start_battle();var session=Session.new();var original=rules.save_data("battle").duplicate(true)
 assert(not session.start_experiment(rules,"rescue") and rules.save_data("battle")==original)
 session.begin(rules,"battle",true);assert(not session.start_experiment(rules,"unknown") and rules.save_data("battle")==original)
 session.set_combat_seed(rules,309)
 for id in SETUP_IDS:
  assert(session.start_experiment(rules,id));var start=canonical(rules.save_data("battle"))
  assert(rules.valid_save(start) and session.revised_knight and session.revised_enemies)
  consequences(rules,session,id)
  assert(session.start_experiment(rules,id) and canonical(rules.save_data("battle"))==start,"Each setup rebuilds deterministically after its consequences")
 for seed_value in [472019,17,2026,8675309]:
  session.set_combat_seed(rules,seed_value);assert(session.start_experiment(rules,"last_rescue"));consequences(rules,session,"last_rescue")
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
 for id in SETUP_IDS:
  app.show_debug_tools("camp" if id=="committed_losses" else "battle")
  var before=app.game.save_data("battle").duplicate(true)
  press(app,"Choose an experiment setup");assert(app.screen=="debug_experiments")
  for dimensions in [Vector2(720,640),Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
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
 app.preferences.values.combat="map";app.preferences.values.auto_end=false
 app.show_debug_experiments();app.ui.find_child("StartExperiment_last_rescue",true,false).pressed.emit();await process_frame;await process_frame
 var branch_point=canonical(app.game.save_data("battle"))
 app.show_debug_tools("battle");press(app,"Save experiment checkpoint");press(app,"Restore experiment checkpoint")
 await settle(app);saved_setup(app)
 assert(app.screen=="battle" and canonical(app.game.save_data("battle"))==branch_point)
 assert(app.debug_session.trace.report().entries[-1].reason=="restore_experiment_checkpoint")
 var patient=unit(app.game,"oren");var carrier=unit(app.game,"lyra");var healer=unit(app.game,"ivo")
 app.click_tile(app.game.pos(carrier));app.click_tile(app.game.pos(patient));assert(app.screen=="triage")
 press(app,"Rescue Oren");await settle(app);saved_setup(app)
 assert(patient.carried_by==carrier.id and patient.bleed_turns==1)
 app.end_turn();await settle(app);saved_setup(app)
 assert(app.game.turn==2 and patient.bleed_turns==1 and patient.carried_by==carrier.id)
 app.click_tile(app.game.pos(carrier));app.click_tile(Vector2i(1,4));await settle(app);saved_setup(app)
 assert(app.game.pos(carrier)==Vector2i(1,4) and app.game.pos(patient)==Vector2i(1,4))
 var badge=app.unit_nodes[carrier.id].carry_screen_bounds(app.camera)
 assert(badge.has_area() and app.carried_healing_target_at(badge.get_center())==null,"The carry badge offers healing only to an eligible staff user")
 app.click_tile(app.game.pos(healer));assert(app.selected==healer and app.game.can_heal(healer,patient))
 var original_hp=carrier.hp
 for health in [carrier.max_hp,carrier.max_hp-1]:
  carrier.hp=health;app.highlight()
  var overlay=app.markers.get_node("HealingTargets")
  var marked=0
  for vertex in overlay.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
   if Vector2i(roundi(vertex.x),roundi(vertex.z))==app.game.pos(carrier):marked+=1
  assert(marked==30,"The carrier's tile is marked once when the patient is the only target and when both allies can be healed")
 carrier.hp=original_hp;app.highlight()
 assert("Carry badge: triage" in app.battle_hint.text)
 var saved=app.game.save_data("battle").duplicate(true)
 var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=badge.get_center()
 app._unhandled_input(click)
 assert(app.screen=="triage" and app.selected==healer and app.game.save_data("battle")==saved,"Badge opens patient-specific triage without acting")
 saved_setup(app)
 var back=InputEventKey.new();back.keycode=KEY_ESCAPE;back.pressed=true;app._unhandled_input(back)
 assert(app.screen=="battle" and app.selected==healer and app.game.save_data("battle")==saved)
 app._unhandled_input(click);assert(app.screen=="triage")
 press(app,"Heal carried Oren");await settle(app);saved_setup(app)
 assert(patient.hp>0 and patient.acted and not app.game.DeathDoor.downed(patient) and patient.get("carried_by","").is_empty() and "oren" not in app.game.lost_ids())
 app.show_debug_tools("battle");press(app,"Restore experiment checkpoint");await settle(app);saved_setup(app)
 assert(app.screen=="battle" and canonical(app.game.save_data("battle"))==branch_point,
  "Rescue and abandonment start from the same exact checkpoint, including the RNG")
 app.end_turn();await settle(app);saved_setup(app)
 assert("oren" in app.game.lost_ids() and app.game.turn==2 and FileAccess.get_file_as_string(app.save_path)==disk,"The contrasting actual end-phase path commits the loss only in the Debug slot")
 app.show_debug_experiments();app.ui.find_child("StartExperiment_legacy_recruits",true,false).pressed.emit()
 app.show_debug_tools("battle");press(app,"Save experiment checkpoint");press(app,"Restore experiment checkpoint")
 await settle(app);saved_setup(app)
 var pair_checkpoint=canonical(app.game.save_data("battle"))
 for id_to_save in ["ivo","sera"]:
  app.click_tile(app.game.pos(unit(app.game,"esme")));app.click_tile(app.game.pos(unit(app.game,id_to_save)))
  await settle(app);saved_setup(app)
  assert(unit(app.game,id_to_save).hp>0,"Esme's ordinary staff action can choose either patient")
  app.end_turn();await settle(app);saved_setup(app)
  var expected="tovin" if id_to_save=="ivo" else "maelin"
  var other="maelin" if id_to_save=="ivo" else "tovin"
  assert(expected in app.game.trials.volunteers and other not in app.game.trials.volunteers and app.game.trials.credits==1)
  assert(FileAccess.get_file_as_string(app.save_path)==disk)
  app.show_debug_tools("battle");press(app,"Restore experiment checkpoint")
  await settle(app);saved_setup(app)
  assert(canonical(app.game.save_data("battle"))==pair_checkpoint,"Both legacy branches use the same initial company, RNG and casualties")
 app.debug_session.set_combat_seed(app.game,472019)
 for opening in [false,true]:
  app.show_debug_experiments();app.ui.find_child("StartExperiment_sacrifice",true,false).pressed.emit()
  if not opening:
   app.show_options("battle");app.ui.find_child("sacrifice_cost",true,false).button_pressed=false
   press(app,"Apply and return [Esc]")
  assert(app.game.trials.flags.sacrifice_cost==opening and app.screen=="battle")
  app.end_turn();await settle(app);saved_setup(app)
  assert(unit(app.game,"oren").hp==0 and app.game.turn==2)
  var sera=unit(app.game,"sera");var guard=unit(app.game,"enemy_4")
  app.click_tile(app.game.pos(sera));app.click_tile(Vector2i(4,5));await settle(app);saved_setup(app)
  assert(app.game.pos(sera)==Vector2i(4,5) and app.game.pos(guard)==Vector2i(5,6) and guard.hp==6)
  var before=app.game.save_data("battle").duplicate(true)
  app.click_tile(app.game.pos(guard));assert(is_instance_valid(app.forecast_panel))
  var forecast=app.forecast_panel.records[0]
  assert(forecast.stats[0].value.text==("7" if opening else "5"))
  assert((forecast.note.text=="Opening +2")==opening and app.game.save_data("battle")==before)
  app.player_attack();await settle(app);saved_setup(app)
  assert(guard.hp==(0 if opening else 1) and FileAccess.get_file_as_string(app.save_path)==disk)
 print("PASS: the actual sacrifice setup shows 5 or 7 damage and only the opening secures the knockout")
 await verify_aqueduct(app,disk)
 app.show_options("battle");app.ui.find_child("DebugMode",true,false).button_pressed=false
 assert(not app.debug_session.active and app.game.save_data("camp")==live and FileAccess.get_file_as_string(app.save_path)==disk)
 await Shutdown.dispose(app);await process_frame
 print("PASS: eight deterministic experiment starters, five-seed rescue/bleed-out branches, matched Warden and Ranger replacement paths, recoverable late retry, carrier badge triage, four-size menus, separate saves, traces and exact campaign restoration")
 quit()
