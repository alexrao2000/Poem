extends SceneTree
# Exercise real experimental controls and prove debug saves cannot replace the
# normal campaign. Restoration includes unsaved progress and simulation RNG.

const Rules=preload("res://scripts/rules.gd")
const Session=preload("res://scripts/debug_session.gd")
const Draft=preload("res://scripts/campaign_draft.gd")
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

func verify_navigation(app):
 var before=app.game.save_data("camp").duplicate(true);var rng=app.game.rng.state
 for dimensions in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions
  await process_frame;await process_frame
  var heading=app.ui.find_child("DebugModelHeading",true,false)
  var sections=app.ui.find_child("DebugSections",true,false)
  var scroll=heading.get_parent().get_parent()
  for name in ["DebugChapter","DebugPressure","DebugLevel","DebugCasualty","DebugPatient"]:
   assert(app.ui.find_child(name,true,false).get_index()<heading.get_index(),"Campaign experiment controls precede character studies")
  var fixed=sections.get_global_rect();press(app,"Character studies");await process_frame;await process_frame
  assert(absf(heading.global_position.y-scroll.global_position.y)<2,"Character jump aligns the study heading at the top of the scrolling area")
  assert(scroll.get_global_rect().grow(1).encloses(app.ui.find_child("DebugVanguardModel",true,false).get_global_rect()),"The first model comparison is immediately visible after jumping")
  assert(app.ui.find_child("DebugVanguardModel",true,false).has_focus(),"Keyboard navigation continues from the first model toggle after a section jump")
  assert(sections.get_global_rect()==fixed and Rect2(Vector2.ZERO,dimensions).encloses(fixed),"Section navigation stays visible and stationary while content scrolls")
  press(app,"Campaign experiments");await process_frame;await process_frame
  assert(app.ui.find_child("DebugSeed",true,false).get_line_edit().has_focus(),"Campaign jump places keyboard focus in the seed control")
  assert(scroll.scroll_vertical==0 and sections.get_global_rect()==fixed,"Campaign jump returns to the seed and chapter controls without rebuilding the menu")
 assert(app.game.save_data("camp")==before and app.game.rng.state==rng,"Section navigation changes no experiment, campaign or random state")

func verify_debug_casualties():
 var g=Rules.new();g.new_campaign(true);g.action_saves=true;g.start_battle();var session=Session.new()
 var before=g.save_data("battle").duplicate(true)
 assert(not session.fall_unit(g,"oren") and not session.set_bleed_turns(g,"oren",1) and g.save_data("battle")==before)
 session.begin(g,"battle");assert(session.fall_unit(g,"oren") and g.roster[1].fallen)
 g.death_door=true;before=g.save_data("battle").duplicate(true)
 assert(not session.fall_unit(g,"oren") and g.save_data("battle")==before,"A repeated debug fall cannot revive a permanent casualty as a downed unit")
 assert(g.valid_save(before))
 session.load_chapter(g,0);assert(session.fall_unit(g,"oren"));var patient=g.units[1]
 assert(g.DeathDoor.downed(patient) and patient.bleed_turns==2)
 before=g.save_data("battle").duplicate(true)
 for value in [0,3,1.5,"bad"]:assert(not session.set_bleed_turns(g,"oren",value))
 assert(not session.fall_unit(g,"oren") and not session.fall_unit(g,g.living("enemy")[0].id) and not session.fall_unit(g,"missing"))
 assert(g.save_data("battle")==before,"Invalid debug casualties and countdown values leave the battle untouched")
 assert(session.set_bleed_turns(g,"oren",1) and patient.bleed_turns==1 and g.rng.state==int(before.rng) and g.turn==before.turn)
 var carrier=g.units[0];assert(g.DeathDoor.rescue(g,carrier,patient));before=g.save_data("battle").duplicate(true)
 assert(not session.set_bleed_turns(g,"oren",2) and not session.fall_unit(g,"oren") and g.save_data("battle")==before,"Paused carried patients cannot be forced into an invalid debug state")
 assert(g.valid_save(g.save_data("battle")))

func verify_retry_previews():
 for sample in [[false,0,6,1,5],[false,10,6,10,5],[true,2,5,3,5],[false,1,8,2,7]]:
  var g=Rules.new();g.new_campaign(sample[0]);g.chapter=4
  g.trials.flags.section_restarts=sample[0];g.trials.flags.reset_pressure=true;g.trials.flags.hard_campaign=true
  g.trials.pressure=sample[1];g.start_battle()
  g.chapter=sample[4];g.start_battle()
  var session=Session.new();session.begin(g,"battle")
  var saved=g.save_data("battle").duplicate(true);var history=session.trace.report()
  var preview=session.report(g).retry_deployment
  var incremental=session.retry_deployment(saved,true)
  assert(preview.chapter==sample[2] and preview.pressure==sample[3] and preview.reference_pressure==0)
  assert(incremental.chapter==preview.chapter and incremental.pressure==preview.pressure and incremental.reference_pressure==sample[1])
  assert(not preview.enemies.is_empty())
  var advances=0
  for enemy in preview.enemies:
   assert(enemy.after.hp-enemy.before.hp==2*preview.pressure)
   assert(enemy.after.attack-enemy.before.attack==preview.pressure)
   assert(enemy.before.held_tonics==2 and enemy.after.held_tonics==maxi(0,2-preview.pressure))
   assert(enemy.after.speed==enemy.before.speed and enemy.after.defense==enemy.before.defense)
   if enemy.before.position!=enemy.after.position:
    assert(enemy.raider);advances+=1
  assert(advances>0,"At least one real raider advances under the chosen pressure")
  var further_advances=0
  for index in incremental.enemies.size():
   var enemy=incremental.enemies[index]
   var ordinary=preview.enemies[index]
   assert(enemy.id==ordinary.id and enemy.after==ordinary.after)
   var gain=incremental.pressure-incremental.reference_pressure
   assert(enemy.after.hp-enemy.before.hp==gain*2 and enemy.after.attack-enemy.before.attack==gain)
   assert(enemy.before.held_tonics==maxi(0,2-incremental.reference_pressure))
   if enemy.before.position!=enemy.after.position:
    assert(enemy.raider);further_advances+=1
  if incremental.chapter==8:assert(further_advances>0,"The repeated Aqueduct preview shows the scout’s additional movement")
  if sample[1]==10:assert(further_advances==0)
  assert(session.report(g).retry_deployment==preview and not session.report(g,"camp").has("retry_deployment"))
  assert(g.save_data("battle")==saved and session.trace.report()==history,"Retry inspection changes no campaign, RNG or trace")
  assert(g.trials.restart(g));g.start_battle()
  var deployed=g.living("enemy")
  assert(deployed.size()==preview.enemies.size())
  for index in range(deployed.size()):
   var unit=deployed[index];var expected=preview.enemies[index]
   assert(unit.id==expected.id and [unit.x,unit.y]==expected.after.position)
   assert(unit.hp==expected.after.hp and g.attack_power(unit)==expected.after.attack and unit.held_tonics==expected.after.held_tonics)

func verify_experiment_checkpoint():
 var g=Rules.new();g.new_campaign(false)
 var session=Session.new();var original=g.save_data("camp").duplicate(true)
 assert(not session.capture_experiment(g,"camp") and session.restore_experiment(g)=="")
 session.begin(g,"camp")
 assert(session.set_combat_seed(g,221) and session.capture_experiment(g,"camp"))
 var branch=g.save_data("camp").duplicate(true)
 assert(not session.capture_experiment(g,"ending"))
 session.load_chapter(g,7);assert(session.set_combat_seed(g,333))
 assert(g.chapter==7 and session.restore_experiment(g)=="camp")
 assert(session.combat_seed==221 and g.save_data("camp")==branch)
 session.load_chapter(g,2);assert(session.restore_experiment(g)=="camp" and g.save_data("camp")==branch)
 assert(session.end(g)=="camp" and g.save_data("camp")==original)
 assert(session.experiment_checkpoint.is_empty(),"Leaving Debug discards the experiment checkpoint and restores the original")

func verify_retry_cells(table: GridContainer,preview: Dictionary):
 var fields=["position","hp","attack","speed","defense","held_tonics"]
 assert(table.columns==7 and table.get_child_count()==7*(preview.enemies.size()+1))
 for index in preview.enemies.size():
  var record=preview.enemies[index];var first=7*(index+1)
  assert(table.get_child(first).text==record.name)
  for offset in fields.size():
   var field=fields[offset];var before=record.before[field];var after=record.after[field]
   var expected=("%d,%d"%after if field=="position" else str(int(after)))
   if before!=after:expected=("%d,%d"%before if field=="position" else str(int(before)))+" → "+expected
   assert(table.get_child(first+offset+1).text==expected)

func verify_retry_table(app,preview: Dictionary):
 press(app,"Compare enemies")
 assert(app.screen=="debug_retry_deployment")
 var table=app.ui.find_child("DebugRetryEnemies",true,false)
 var baseline=app.ui.find_child("DebugRetryBaseline",true,false)
 var pressure=app.ui.find_child("DebugRetryPressure",true,false)
 var incremental=app.debug_session.retry_deployment(app.game.save_data("battle"),true)
 assert(baseline.item_count==2 and baseline.selected==0 and pressure.text.contains("Pressure 0 → 6"))
 verify_retry_cells(table,preview)
 for dimensions in [Vector2(720,480),Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions
  for option in [1,0]:
   baseline.select(option);baseline.item_selected.emit(option)
   await process_frame;await process_frame
   assert(pressure.text.contains("Pressure %d → 6"%(5 if option==1 else 0)))
   verify_retry_cells(table,incremental if option==1 else preview)
   var scroll=table.get_parent().get_parent()
   var bounds=table.get_global_rect()
   var window=Rect2(Vector2.ZERO,dimensions).grow(1)
   assert(bounds.position.x>=scroll.global_position.x and bounds.end.x<=scroll.get_global_rect().end.x+1)
   assert(window.encloses(table.get_child(6).get_global_rect()) and window.encloses(baseline.get_global_rect()),
    "Comparison controls in %s, header %s, baseline %s"%[window,table.get_child(6).get_global_rect(),baseline.get_global_rect()])
   var close=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Return to experiment report")[0]
   assert(window.encloses(close.get_global_rect()))
 escape_key(true);assert(app.screen=="debug_retry_deployment")
 escape_key();assert(app.screen=="debug_report")
 press(app,"Compare enemies");press(app,"Return to experiment report");assert(app.screen=="debug_report")
 print("PASS: both retry table references across four viewports, including current pressure and a read-only return")

func verify_authored_debug(app):
 var ordinary=app.game
 var normal_disk=FileAccess.get_file_as_string(app.save_path)
 var scratch="/private/tmp/poem-authored-debug-%d"%OS.get_process_id()
 assert(DirAccess.make_dir_recursive_absolute(scratch)==OK)
 app.campaign_playtest_directory=scratch
 app.campaign_draft_library.path=scratch.path_join("drafts.json")
 var draft=Draft.new();draft.data=draft.new_document(false)
 var stage=draft.insert_blank_war_table(0)
 draft.data.chapters[stage].section=true
 draft.data.chapters[stage].level.enemies[0].name="Chart commander"
 for flag in ["permadeath","action_saves","reset_pressure","section_restarts"]:draft.data.settings[flag]=true
 app.campaign_draft=draft;app.campaign_editor_chapter=stage
 app.show_campaign_editor("title");await process_frame
 press(app,"Play chapter");await process_frame
 assert(app.screen=="camp" and app.game.chapter==stage and app.campaign_preview.return=="editor")
 press(app,"Deploy company  >")
 app.valley_reveal_skip=true
 var deadline=Time.get_ticks_msec()+5000
 while app.busy and Time.get_ticks_msec()<deadline:
  await process_frame
  if app.chapter_card_active:app.chapter_card_skip=true
  if app.phase_banner_active:app.phase_skip=true
 assert(app.screen=="battle" and not app.busy)
 var path=app.campaign_save_path()
 var disk=FileAccess.get_file_as_string(path)
 assert(not disk.is_empty())
 app.game.roster[0].xp+=7
 var live=app.game.export_code("battle")
 app.show_options("battle")
 var debugging=app.ui.find_child("DebugMode",true,false)
 assert(not debugging.disabled);debugging.button_pressed=true
 assert(app.campaign_save_path()==path+".debug")
 press(app,"Open debug tools")
 assert(app.ui.find_child("DebugChapter",true,false).item_count==2)
 press(app,"Save experiment checkpoint")
 app.ui.find_child("DebugPressure",true,false).value=2;press(app,"Test pressure and reset battle")
 var loader=Rules.new(app.game.content)
 assert(loader.load_game(path+".debug")=="battle" and loader.trials.pressure==2)
 app.show_debug_tools("battle");press(app,"View experiment report")
 var deployment=JSON.parse_string(app.ui.find_child("DebugReport",true,false).text).retry_deployment
 assert(deployment.chapter==2 and deployment.pressure==3 and deployment.enemies[0].name=="Chart commander")
 press(app,"Compare enemies")
 var baseline=app.ui.find_child("DebugRetryBaseline",true,false)
 assert(baseline.item_count==2)
 baseline.select(1);baseline.item_selected.emit(1)
 assert("Pressure 2 → 3" in app.ui.find_child("DebugRetryPressure",true,false).text)
 app.show_debug_tools("battle");press(app,"Restore experiment checkpoint");await process_frame
 assert(app.game.export_code("battle")==live and FileAccess.get_file_as_string(path)==disk)
 app.show_options("battle");app.ui.find_child("DebugMode",true,false).button_pressed=false
 assert(app.campaign_save_path()==path and app.game.export_code("battle")==live)
 assert(FileAccess.get_file_as_string(path)==disk and FileAccess.get_file_as_string(app.save_path)==normal_disk)
 app.close_options();app.show_battle_menu();press(app,"Return to editor");await process_frame
 assert(app.screen=="campaign_editor" and app.game==ordinary and FileAccess.get_file_as_string(app.save_path)==normal_disk)
 print("PASS: authored Debug checkpoints, pressure comparisons and writes stay in the draft’s separate sandbox")

func run():
 verify_debug_casualties()
 verify_retry_previews()
 verify_experiment_checkpoint()
 var rules=Rules.new();rules.new_campaign(true);rules.start_battle()
 var session=Session.new();var original=rules.save_data("battle").duplicate(true)
 session.load_chapter(rules,11);session.heal(rules);session.revive(rules);session.reset_battle(rules)
 assert(not session.set_combat_seed(rules,17) and session.report(rules).is_empty())
 assert(not session.test_pressure(rules,5),"Disabled debug cannot alter reset preparation")
 assert(not session.train_company(rules,10),"Disabled debug cannot grant growth")
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
 assert(not report.has("retry_deployment"),"Disabled reset pressure leaves the proposed deployment out of the report")
 var replay=Rules.new();assert(replay.import_code(report.save_code)=="battle" and replay.rng.state==state and replay.units[0].hp==a.hp,"Reports carry an exact restorable position")
 for invalid in [-1,11,1.5,"bad"]:assert(not session.test_pressure(rules,invalid))
 assert(session.test_pressure(rules,10) and rules.trials.pressure==10 and rules.trials.flags.reset_pressure and rules.turn==1)
 assert(rules.rng.state==initial and rules.living("enemy").all(func(enemy):return enemy.held_tonics==0),"Pressure test rebuilds with the chosen seed and depleted supplies")
 assert(session.report(rules).next_deployment_enemy_bonuses.pow==10)
 for invalid in [0,100,2.5,"bad"]:assert(not session.train_company(rules,invalid))
 rules.roster[1].fallen=true;rules.roster[1].fallen_chapter=0;rules.roster[1].hp=0
 var fallen=rules.roster[1].duplicate(true);var future=rules.roster[-1].duplicate(true)
 var expected=rules.available().duplicate(true)
 for unit in expected:rules.award_xp(unit,(20-int(unit.level))*100-int(unit.xp))
 var section=rules.trials.checkpoint.duplicate(true)
 assert(session.train_company(rules,20) and rules.available()==expected,"Training uses the ordinary growth rules exactly")
 assert(rules.roster[1]==fallen and rules.roster[-1]==future and rules.trials.checkpoint==section,"Training cannot revive losses, unlock future recruits or replace the section checkpoint")
 var promotion=rules.promotion_options(rules.roster[0])[0].id
 assert(rules.promote(rules.roster[0],promotion));var trained=rules.roster[0].duplicate(true)
 assert(session.train_company(rules,1) and rules.roster[0]==trained,"Lower targets never reduce levels or remove promotions")
 assert(rules.rng.state==initial and rules.units.all(func(unit):return unit.id!="oren"),"Training rebuilds a legal deployment with the chosen combat seed")
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
 app.show_save_transfer("camp");await inspect(app)
 assert(app.ui.find_child("TransferInstructions",true,false).text.contains("temporary Debug campaign"))
 assert(FileAccess.get_file_as_string(app.save_path)==disk)
 app.close_save_transfer();app.show_options("camp")
 app.ui.find_child("Permadeath",true,false).button_pressed=false
 assert(not app.game.permadeath,"Experimental rule toggle applies immediately")
 press(app,"Open debug tools");await inspect(app);await verify_navigation(app)
 app.ui.find_child("DebugSeed",true,false).value=309;press(app,"Apply seed to next rolls")
 assert(app.debug_session.combat_seed==309)
 press(app,"View experiment report");await inspect(app)
 var report_text=app.ui.find_child("DebugReport",true,false)
 assert(not report_text.editable and JSON.parse_string(report_text.text).seed_for_new_attempts==309)
 assert(report_text.text.find("\"settings\"")<report_text.text.find("\"save_code\""),"Readable report settings precede the long restore code")
 assert(app.ui.find_children("*","Button",true,false).any(func(button):return button.text=="Copy restore code" and not button.disabled))
 assert(app.ui.find_child("DebugCompareEnemies",true,false)==null,"Preparation reports omit battle-only comparison controls")
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
 app.show_debug_tools("battle");await inspect(app)
 var on_disk=FileAccess.get_file_as_string(app.save_path+".debug")
 var live_battle=app.game.save_data("battle").duplicate(true)
 press(app,"View experiment report");await inspect(app)
 var preview_label=app.ui.find_child("DebugRetryPreview",true,false)
 assert(preview_label!=null and preview_label.text.begins_with("Retry preview · Chapter 12 · Pressure 6"))
 var preview=JSON.parse_string(app.ui.find_child("DebugReport",true,false).text).retry_deployment
 assert(preview.chapter==12 and preview.pressure==6 and preview.enemies.all(func(enemy):return enemy.after.held_tonics==0))
 var trace=app.debug_session.trace.report()
 await verify_retry_table(app,preview)
 assert(app.game.save_data("battle")==live_battle and FileAccess.get_file_as_string(app.save_path+".debug")==on_disk)
 assert(app.debug_session.trace.report()==trace and FileAccess.get_file_as_string(app.save_path)==disk)
 press(app,"Return to debug tools")
 app.ui.find_child("DebugLevel",true,false).value=20;press(app,"Raise company and reset battle")
 assert(app.screen=="battle" and app.game.available().all(func(unit):return unit.level>=20))
 assert(loaded.load_game(app.save_path+".debug")=="battle" and loaded.roster[0].level==20 and FileAccess.get_file_as_string(app.save_path)==disk,"Training persists only in the debug save")
 var ally=app.game.living("player")[0];ally.hp=1;ally.acted=true;var rng=app.game.rng.state
 app.show_debug_tools("battle");assert(app.ui.find_child("DebugLevel",true,false).value==20,"Training control reflects the prepared company level");press(app,"Heal deployed allies")
 assert(ally.hp==ally.max_hp and ally.acted and app.game.rng.state==rng,"Healing changes only health and preserves action/RNG state")
 app.game.roster[1].fallen=true;app.game.roster[1].fallen_chapter=0;app.game.roster[1].hp=0;app.game.deployed.erase(app.game.roster[1].id)
 press(app,"Revive company and reset battle")
 assert(app.game.lost_ids().is_empty() and app.game.units.any(func(unit):return unit.id=="oren" and unit.hp==unit.max_hp),"Revival clears memorials and rebuilds a legal full-health deployment")
 app.game.units[0].hp=1;app.game.turn=9
 app.show_debug_tools("battle");press(app,"Reset current battle")
 assert(app.game.turn==1 and app.game.units[0].hp==app.game.units[0].max_hp,"Reset starts the current chapter from preparation")
 app.game.death_door=true;app.game.action_saves=true;app.show_debug_tools("battle")
 var casualty_choice=app.ui.find_child("DebugCasualty",true,false)
 for index in range(casualty_choice.item_count):
  if casualty_choice.get_item_metadata(index)=="oren":casualty_choice.select(index)
 press(app,"Test selected ally falling")
 var patient=app.game.units.filter(func(unit):return unit.id=="oren")[0]
 assert(app.screen=="battle" and app.game.DeathDoor.downed(patient) and patient.bleed_turns==2)
 app.show_debug_tools("battle");await inspect(app)
 var saved_point=app.game.save_data("battle").duplicate(true)
 var trace_at_capture=app.debug_session.trace.report()
 var disk_at_capture=FileAccess.get_file_as_string(app.save_path+".debug")
 var restore_button=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Restore experiment checkpoint")[0]
 assert(restore_button.disabled)
 press(app,"Save experiment checkpoint");await inspect(app)
 assert(app.ui.find_child("ExperimentCheckpointStatus",true,false).text.contains("Chapter 12 · Turn 1"))
 assert(app.debug_session.trace.report()==trace_at_capture and FileAccess.get_file_as_string(app.save_path+".debug")==disk_at_capture)
 casualty_choice=app.ui.find_child("DebugCasualty",true,false)
 for index in range(casualty_choice.item_count):assert(casualty_choice.get_item_metadata(index)!="oren","Downed allies are excluded from the lethal-hit selector")
 app.ui.find_child("DebugBleedTurns",true,false).value=1;press(app,"Set rescue countdown")
 assert(app.screen=="battle" and patient.bleed_turns==1 and app.unit_nodes[patient.id].rescue_marker.get_meta("turns")==1)
 assert(app.side.get_node("EndPlayerPhase").text=="End phase · 1 will fall","Countdown experiments update the live tactical warning")
 assert(loaded.load_game(app.save_path+".debug")=="battle" and loaded.units.filter(func(unit):return unit.id=="oren")[0].bleed_turns==1 and FileAccess.get_file_as_string(app.save_path)==disk,"The exact countdown persists only in the debug slot")
 app.show_debug_tools("battle")
 app.ui.find_child("DebugSeed",true,false).value=712;press(app,"Apply seed to next rolls")
 press(app,"Restore experiment checkpoint");await process_frame
 assert(app.screen=="battle" and app.game.save_data("battle")==saved_point and app.debug_session.combat_seed==309)
 assert(app.unit_nodes["oren"].rescue_marker.get_meta("turns")==2,"Restoring recreates the earlier rescue countdown on the map")
 assert(loaded.load_game(app.save_path+".debug")=="battle" and loaded.units.filter(func(unit):return unit.id=="oren")[0].bleed_turns==2)
 var restored_trace=app.debug_session.trace.report().entries[-1]
 assert(restored_trace.reason=="restore_experiment_checkpoint" and restored_trace.persistence=="written")
 assert(FileAccess.get_file_as_string(app.save_path)==disk)
 app.show_debug_tools("battle");press(app,"Return to preparation");assert(app.screen=="camp" and app.game.units.is_empty())
 var back_state=app.game.save_data("camp").duplicate(true)
 app.show_debug_tools("camp");escape_key(true);assert(app.screen=="debug_tools")
 escape_key();assert(app.screen=="options" and app.debug_session.active)
 escape_key(true);assert(app.screen=="options","Held back key cannot leave the next menu")
 escape_key();assert(app.screen=="camp" and app.debug_session.active and app.game.save_data("camp")==back_state)
 assert(FileAccess.get_file_as_string(app.save_path)==disk,"Keyboard back-navigation keeps Debug isolated from the normal campaign")
 app.show_options("camp");app.ui.find_child("DebugMode",true,false).button_pressed=false
 assert(not app.debug_session.active and app.game.save_data("camp")==live,"Disabling debug restores the exact unsaved campaign, original rule and RNG")
 app.close_options();assert(app.screen=="camp" and app.campaign_save_path()==app.save_path)
 assert(loaded.load_game(app.save_path)=="camp" and loaded.roster[0].xp==17 and loaded.permadeath,"Normal saving resumes only after restoring the original campaign")
 app.show_options("camp");app.ui.find_child("Permadeath",true,false).button_pressed=false;app.close_options()
 assert(loaded.load_game(app.save_path)=="camp" and not loaded.permadeath,"Permadeath can be changed and saved outside debug as requested")
 await verify_authored_debug(app)
 await Shutdown.dispose(app);await process_frame
 print("PASS: opt-in debug controls, repeatable experiment checkpoints, exact retry deployment previews, four retry table layouts, twelve-chapter chooser, heal/revive/reset, separate save slot, unsaved checkpoint restoration, guarded actions and live permadeath toggle persistence")
 quit()

func escape_key(echo=false):
 var event=InputEventKey.new();event.keycode=KEY_ESCAPE;event.pressed=true;event.echo=echo;root.push_input(event,true)
 var release=InputEventKey.new();release.keycode=KEY_ESCAPE;root.push_input(release,true)
