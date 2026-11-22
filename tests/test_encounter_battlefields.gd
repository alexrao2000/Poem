extends SceneTree
## Exercise explicit battlefields through ordinary saves/actions and the real
## chooser. Rendering is not measured by these headless state and bounds checks.
const Rules=preload("res://scripts/rules.gd")
const Encounters=preload("res://scripts/debug_encounters.gd")
const Session=preload("res://scripts/debug_session.gd")
const Shutdown=preload("helpers/game_shutdown.gd")

func _initialize():call_deferred("run")
func canonical(data):return JSON.parse_string(JSON.stringify(data))
func choose(control,value):
 for index in control.item_count:
  if control.get_item_metadata(index)==value:
   assert(not control.is_item_disabled(index));control.select(index);control.item_selected.emit(index);return
 assert(false,"Missing chooser value: "+str(value))
func enter():
 for pressed in [true,false]:
  var event=InputEventKey.new();event.keycode=KEY_ENTER;event.pressed=pressed;root.push_input(event,true)

func run():
 var game=Rules.new();game.start_battle();var session=Session.new();var original=game.save_data("battle").duplicate(true)
 assert(session.start_recruit_encounter(game,"lyra","","",11).is_empty() and game.save_data("battle")==original)
 session.begin(game,"battle");session.set_combat_seed(game,309)
 var before=game.save_data("battle").duplicate(true)
 for invalid in [["lyra","",-2],["lyra","",12],["galen","",0],["oren","rally_lance",0],["lyra","thunder",11]]:
  assert(session.start_recruit_encounter(game,invalid[0],"",invalid[1],invalid[2]).is_empty() and game.save_data("battle")==before)
 var count=0;var chapters_seen={}
 for recruit in game.content.roster:
  for item in game.equipment:
   if item.kind!=recruit.weapon:continue
   for chapter in Encounters.available_chapters(game,recruit.id,item.id):
    var path=game.promotion_options(recruit)[chapter%2].id if chapter%3!=0 else ""
    var setup=session.start_recruit_encounter(game,recruit.id,path,item.id,chapter)
    assert(not setup.is_empty(),"%s / %s / chapter %d"%[recruit.id,item.id,chapter+1])
    var snapshot=canonical(game.save_data("battle"));assert(game.valid_save(snapshot) and game.chapter==chapter)
    var actor=game.units.filter(func(u):return u.id==setup.actor)[0];var target=game.units.filter(func(u):return u.id==setup.target)[0]
    assert(actor.item==item.id and actor.get("promotion","")==path and game.distance(actor,target)==int(item.max_range))
    assert(actor.level>=maxi(3,chapter+1) and (path.is_empty() or actor.level>=10))
    var positions=[]
    for unit in game.units:
     assert(game.pos(unit) not in positions and game.terrain(game.pos(unit)) not in ["#","~"]);positions.append(game.pos(unit))
    assert(game.can_heal(actor,target) if setup.healing else game.can_attack(actor,target))
    var restored=Rules.new();assert(restored.restore_save(snapshot)=="battle" and canonical(restored.save_data("battle"))==snapshot)
    if chapter==Encounters.available_chapters(game,recruit.id,item.id)[0]:
     assert(not session.start_recruit_encounter(game,recruit.id,path,item.id,chapter).is_empty() and canonical(game.save_data("battle"))==snapshot)
    count+=1;chapters_seen[chapter]=true
 assert(chapters_seen.size()==12 and session.end(game)=="battle" and game.save_data("battle")==original)
 print("PASS: %d legal recruit/equipment/battlefield setups, all twelve maps, save roundtrips, first-available seeded replay and invalid/inactive isolation"%count)
 await controls()
 quit()

func controls():
 root.size=Vector2i(1440,900)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-battlefields-%d.json"%Time.get_ticks_usec();root.add_child(app);await process_frame
 app.game.story_seen=["opening_0"];app.show_camp();assert(app.persist_campaign("camp"));var disk=FileAccess.get_file_as_string(app.save_path)
 app.game.roster[0].xp=17;var original=app.game.save_data("camp").duplicate(true)
 app.preferences.values.combat="all";app.preferences.values.auto_end=false;var preferences=app.preferences.values.duplicate(true)
 app.show_options("camp");app.ui.find_child("DebugMode",true,false).button_pressed=true;app.show_debug_encounters()
 var before=app.game.save_data("camp").duplicate(true);var trace=app.debug_session.trace.report();var debug_disk=FileAccess.get_file_as_string(app.save_path+".debug")
 for size in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=size;await process_frame;await process_frame
  var recruits=app.ui.find_child("EncounterRecruit",true,false);var equipment=app.ui.find_child("EncounterEquipment",true,false);var field=app.ui.find_child("EncounterBattlefield",true,false)
  assert(field.item_count==13)
  choose(recruits,"lyra");choose(field,0);choose(recruits,"galen")
  assert(app.encounter_chapter==-1 and field.selected==0 and field.is_item_disabled(1))
  choose(recruits,"oren");choose(field,0);choose(equipment,"rally_lance")
  assert(app.encounter_chapter==-1 and field.selected==0 and field.is_item_disabled(1))
  choose(field,11);choose(recruits,"lyra")
  assert(app.encounter_chapter==11 and field.selected==12)
  for chapter in 12:
   choose(field,chapter)
   var detail=app.ui.find_child("EncounterDetail",true,false)
   assert(detail.text.contains(app.game.content.chapters[chapter].place) and detail.text.contains("at least level %d"%maxi(3,chapter+1)))
  for name in ["EncounterBattlefield","EncounterDetail","StageRecruitEncounter"]:
   var control=app.ui.find_child(name,true,false);var scroll=control.get_parent().get_parent();scroll.ensure_control_visible(control);await process_frame;await process_frame
   assert(scroll.get_global_rect().grow(1).encloses(control.get_global_rect()) and control.size.x>=control.get_minimum_size().x)
 assert(app.game.save_data("camp")==before and app.debug_session.trace.report()==trace and app.preferences.values==preferences and FileAccess.get_file_as_string(app.save_path)==disk and FileAccess.get_file_as_string(app.save_path+".debug")==debug_disk)
 for chapter in 12:
  app.show_debug_encounters();await process_frame;await process_frame
  choose(app.ui.find_child("EncounterRecruit",true,false),"ivo" if chapter%3==1 else "lyra")
  choose(app.ui.find_child("EncounterBattlefield",true,false),chapter)
  app.ui.find_child("EncounterModels_"+("current" if chapter%2==0 else "revised"),true,false).pressed.emit()
  app.ui.find_child("StageRecruitEncounter",true,false).pressed.emit();await process_frame;await process_frame
  assert(app.game.chapter==chapter and app.screen=="battle" and app.debug_session.trace.report().entries[-1].reason.ends_with(":chapter:"+str(chapter+1)))
  var actor=app.selected;var target=app.game.at(app.cursor_tile);var expected=Rules.new();assert(expected.restore_save(app.game.save_data("battle"))=="battle")
  var a=expected.units.filter(func(u):return u.id==actor.id)[0];var b=expected.units.filter(func(u):return u.id==target.id)[0]
  if actor.weapon=="staff":assert(expected.heal(a,b))
  else:assert(not expected.combat(a,b).is_empty());enter()
  var lighting=app.lighting_state();enter();assert(app.busy)
  var saw_stage=false;var deadline=Time.get_ticks_msec()+12000
  while app.busy and Time.get_ticks_msec()<deadline:
   await process_frame
   var playback=app.ui.get_node_or_null("CombatPlayback")
   if playback!=null:playback.fast_button.button_pressed=true
   if app.stage.visible:
    saw_stage=true;assert(app.stage.get_meta("environment")==app.game.info().environment)
    if chapter%3==2 and playback!=null:playback.skip_button.pressed.emit()
   if is_instance_valid(app.reward_panel):app.reward_panel.request_continue()
  assert(not app.busy and saw_stage and not app.stage.visible and app.lighting_state()==lighting)
  assert(canonical(app.game.save_data("battle"))==canonical(expected.save_data("battle")))
  var saved=Rules.new();assert(saved.load_game(app.save_path+".debug")=="battle" and canonical(saved.save_data("battle"))==canonical(expected.save_data("battle")))
  app.show_debug_encounters();await process_frame;await process_frame
  assert(app.ui.find_child("EncounterBattlefield",true,false).get_item_metadata(app.ui.find_child("EncounterBattlefield",true,false).selected)==chapter)
 app.show_options("battle");app.ui.find_child("DebugMode",true,false).button_pressed=false
 assert(app.game.save_data("camp")==original and app.preferences.values==preferences and FileAccess.get_file_as_string(app.save_path)==disk)
 await Shutdown.dispose(app)
 print("PASS: three-size battlefield controls, unlock fallback, read-only browsing, twelve actual current/revised attack/heal/Skip scenes, lighting restoration and exact original campaign/file/preferences restoration")
