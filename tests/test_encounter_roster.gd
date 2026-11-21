extends SceneTree
const Rules=preload("res://scripts/rules.gd")
const Encounters=preload("res://scripts/debug_encounters.gd")
const Session=preload("res://scripts/debug_session.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")
func canonical(data):return JSON.parse_string(JSON.stringify(data))
func enter():
 for pressed in [true,false]:
  var event=InputEventKey.new();event.keycode=KEY_ENTER;event.pressed=pressed;root.push_input(event,true)
func choose(control,value):
 for index in control.item_count:
  if control.get_item_metadata(index)==value:control.select(index);control.item_selected.emit(index);return
 assert(false,"Available selector value: "+value)
func run():
 var game=Rules.new();game.start_battle();var session=Session.new();var original=game.save_data("battle").duplicate(true)
 assert(session.start_recruit_encounter(game,"rhea","dawnblade").is_empty() and game.save_data("battle")==original)
 session.begin(game,"battle",true)
 for invalid in [["unknown",""],["lyra","unknown"],["lyra","luminary"]]:
  assert(session.start_recruit_encounter(game,invalid[0],invalid[1]).is_empty() and game.save_data("battle")==original)
 assert(Encounters.start(game,"sword",309,"oren").is_empty() and game.save_data("battle")==original)
 var count=0
 for seed_value in [472019,17,309]:
  session.set_combat_seed(game,seed_value)
  for recruit in game.content.roster:
   var paths=[""]+game.promotion_options(recruit).map(func(path):return path.id)
   for path in paths:
    var setup=session.start_recruit_encounter(game,recruit.id,path);assert(not setup.is_empty())
    var snapshot=canonical(game.save_data("battle"));assert(game.valid_save(snapshot) and game.action_saves and not game.permadeath)
    assert(game.trials.flags.values().all(func(value):return not value) and session.model_choice()=="revised")
    var actor=game.units.filter(func(u):return u.id==recruit.id)[0];var target=game.units.filter(func(u):return u.id==setup.target)[0]
    assert(actor.get("promotion","")==path and (path.is_empty() or actor.level>=10) and game.item_for(actor).id==game.item_for(recruit).id)
    assert(game.chapter==maxi(Encounters.scene_for_recruit(game.content.roster,recruit.id).chapter,int(recruit.join)))
    var positions=[]
    for unit in game.units:
     assert(game.pos(unit) not in positions and game.terrain(game.pos(unit)) not in ["#","~"]);positions.append(game.pos(unit))
    var random=RandomNumberGenerator.new();random.seed=seed_value;assert(game.rng.state==random.state)
    if setup.healing:assert(game.can_heal(actor,target) and game.heal(actor,target))
    else:assert(game.can_attack(actor,target) and not game.combat(actor,target).is_empty())
    var restored=Rules.new();assert(restored.restore_save(game.save_data("battle"))=="battle" and canonical(restored.save_data("battle"))==canonical(game.save_data("battle")))
    assert(not session.start_recruit_encounter(game,recruit.id,path).is_empty() and canonical(game.save_data("battle"))==snapshot)
    count+=1
 assert(count==216 and session.end(game)=="battle" and game.save_data("battle")==original)
 await controls()
 print("PASS: 216 complete-roster seeded base/promotion encounters, invalid-call isolation, legal ordinary actions, exact replay/save roundtrips, three-size selectors, six actual current/revised promoted scenes and original campaign/file/preferences restoration")
 quit()
func controls():
 root.size=Vector2i(1440,900)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-encounter-roster-%d.json"%Time.get_ticks_usec();root.add_child(app);await process_frame
 app.game.story_seen=["opening_0"];app.show_camp();assert(app.persist_campaign("camp"));var disk=FileAccess.get_file_as_string(app.save_path)
 app.game.roster[0].xp=17;var original=app.game.save_data("camp").duplicate(true)
 app.preferences.values.combat="all";app.preferences.values.auto_end=false;var preferences=app.preferences.values.duplicate(true)
 app.show_options("camp");app.ui.find_child("DebugMode",true,false).button_pressed=true;app.show_debug_encounters()
 var before=app.game.save_data("camp").duplicate(true);var trace=app.debug_session.trace.report()
 for size in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=size;await process_frame;await process_frame
  var recruits=app.ui.find_child("EncounterRecruit",true,false);var training=app.ui.find_child("EncounterTraining",true,false)
  assert(recruits.item_count==24)
  for recruit in app.game.content.roster:
   choose(recruits,recruit.id);assert(training.item_count==3 and training.selected==0 and app.encounter_training.is_empty())
   assert(app.ui.find_child("EncounterDetail",true,false).text.contains(app.game.content.chapters[maxi(Encounters.scene_for_recruit(app.game.content.roster,recruit.id).chapter,int(recruit.join))].place))
   for path in app.game.promotion_options(recruit):choose(training,path.id);assert(app.encounter_training==path.id)
  for name in ["EncounterRecruit","EncounterTraining","EncounterDetail","StageRecruitEncounter"]:
   var control=app.ui.find_child(name,true,false);var scroll=control.get_parent().get_parent();scroll.ensure_control_visible(control);await process_frame;await process_frame
   assert(scroll.get_global_rect().grow(1).encloses(control.get_global_rect()) and control.size.x>=control.get_minimum_size().x)
 assert(app.game.save_data("camp")==before and app.debug_session.trace.report()==trace and FileAccess.get_file_as_string(app.save_path)==disk and app.preferences.values==preferences)
 for model in ["current","revised"]:
  for sample in [["rhea","dawnblade"],["galen","wayfarer"],["elian","iron_lancer"]]:
   app.show_debug_encounters();await process_frame;await process_frame
   app.ui.find_child("EncounterModels_"+model,true,false).pressed.emit()
   choose(app.ui.find_child("EncounterRecruit",true,false),sample[0]);choose(app.ui.find_child("EncounterTraining",true,false),sample[1])
   app.ui.find_child("StageRecruitEncounter",true,false).pressed.emit();await process_frame;await process_frame
   assert(app.screen=="battle" and app.selected.id==sample[0] and app.selected.promotion==sample[1] and app.target==null and app.cursor_visible)
   assert(app.debug_session.report(app.game).recent_actions.entries[-1].reason=="encounter:recruit:"+sample[0]+":"+sample[1])
   var actor=app.selected;var recipient=app.game.at(app.cursor_tile);var expected=Rules.new();assert(expected.restore_save(app.game.save_data("battle"))=="battle")
   var a=expected.units.filter(func(u):return u.id==actor.id)[0];var b=expected.units.filter(func(u):return u.id==recipient.id)[0]
   if actor.weapon=="staff":assert(expected.heal(a,b))
   else:assert(not expected.combat(a,b).is_empty());enter()
   enter();assert(app.busy)
   var saw_stage=false;var fast=false;var deadline=Time.get_ticks_msec()+12000
   while app.busy and Time.get_ticks_msec()<deadline:
    await process_frame;saw_stage=saw_stage or app.stage.visible
    var playback=app.ui.get_node_or_null("CombatPlayback")
    if playback!=null and not fast:playback.fast_button.button_pressed=true;fast=true
    if is_instance_valid(app.reward_panel):app.reward_panel.request_continue()
   assert(not app.busy and saw_stage and fast and not app.stage.visible)
   assert(canonical(app.game.save_data("battle"))==canonical(expected.save_data("battle")))
   var saved=Rules.new();assert(saved.load_game(app.save_path+".debug")=="battle" and canonical(saved.save_data("battle"))==canonical(expected.save_data("battle")))
   app.show_debug_encounters();await process_frame;await process_frame
   assert(app.ui.find_child("EncounterRecruit",true,false).get_item_metadata(app.ui.find_child("EncounterRecruit",true,false).selected)==sample[0])
   assert(app.ui.find_child("EncounterTraining",true,false).get_item_metadata(app.ui.find_child("EncounterTraining",true,false).selected)==sample[1])
 app.show_options("battle");app.ui.find_child("DebugMode",true,false).button_pressed=false
 assert(app.game.save_data("camp")==original and FileAccess.get_file_as_string(app.save_path)==disk and app.preferences.values==preferences)
 await Shutdown.dispose(app)
