extends SceneTree
const Rules=preload("res://scripts/rules.gd")
const Encounters=preload("res://scripts/debug_encounters.gd")
const Session=preload("res://scripts/debug_session.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")
func canonical(data):return JSON.parse_string(JSON.stringify(data))
func choose(control,value):
 for index in control.item_count:
  if control.get_item_metadata(index)==value:control.select(index);control.item_selected.emit(index);return
 assert(false,"Missing equipment selection: "+value)
func enter():
 for pressed in [true,false]:
  var event=InputEventKey.new();event.keycode=KEY_ENTER;event.pressed=pressed;root.push_input(event,true)
func run():
 var game=Rules.new();game.start_battle();var original=game.save_data("battle").duplicate(true);var session=Session.new()
 assert(session.start_recruit_encounter(game,"oren","","javelin").is_empty() and game.save_data("battle")==original)
 session.begin(game,"battle",true)
 for invalid in [["oren","unknown"],["oren","thunder"],["lyra","beacon_staff"]]:
  assert(session.start_recruit_encounter(game,invalid[0],"",invalid[1]).is_empty() and game.save_data("battle")==original)
 var count=0;var expected_count=0
 for recruit in game.content.roster:expected_count+=game.equipment.filter(func(item):return item.kind==recruit.weapon).size()*(1+game.promotion_options(recruit).size())*2
 for seed_value in [17,309]:
  session.set_combat_seed(game,seed_value)
  for recruit in game.content.roster:
   for path in [""]+game.promotion_options(recruit).map(func(p):return p.id):
    for item in game.equipment:
     if item.kind!=recruit.weapon:continue
     var setup=session.start_recruit_encounter(game,recruit.id,path,item.id);assert(not setup.is_empty(),recruit.id+" / "+path+" / "+item.id)
     var snapshot=canonical(game.save_data("battle"));assert(game.valid_save(snapshot))
     var actor=game.units.filter(func(u):return u.id==setup.actor)[0];var target=game.units.filter(func(u):return u.id==setup.target)[0]
     assert(game.item_for(actor).id==item.id and actor.get("promotion","")==path and game.distance(actor,target)==int(item.max_range))
     assert(game.chapter==maxi(maxi(Encounters.scene_for_recruit(game.content.roster,recruit.id).chapter,int(recruit.join)),int(item.unlock)))
     assert(game.trials.purchases.is_empty() and game.trials.flags.values().all(func(v):return not v) and not game.permadeath and game.action_saves)
     var positions=[]
     for unit in game.units:
      assert(game.pos(unit) not in positions and game.terrain(game.pos(unit)) not in ["#","~"]);positions.append(game.pos(unit))
     var random=RandomNumberGenerator.new();random.seed=seed_value;assert(game.rng.state==random.state)
     if setup.healing:assert(game.can_heal(actor,target) and game.heal(actor,target))
     else:assert(game.can_attack(actor,target) and not game.combat(actor,target).is_empty())
     var copy=Rules.new();assert(copy.restore_save(game.save_data("battle"))=="battle" and canonical(copy.save_data("battle"))==canonical(game.save_data("battle")))
     assert(not session.start_recruit_encounter(game,recruit.id,path,item.id).is_empty() and canonical(game.save_data("battle"))==snapshot)
     count+=1
 assert(count==expected_count and session.end(game)=="battle" and game.save_data("battle")==original)
 await controls()
 await visibility()
 print("PASS: all catalogued equipped base/promoted encounters, max-range legal actions, ordinary unlock/growth/equip rules, exact seeded replay/save roundtrips, invalid/inactive isolation, three-size selectors twelve real current/revised scenes and 72 actual viewport target bounds")
 quit()
func controls():
 root.size=Vector2i(1440,900)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-encounter-equipment-%d.json"%Time.get_ticks_usec();root.add_child(app);await process_frame
 app.game.story_seen=["opening_0"];app.show_camp();assert(app.persist_campaign("camp"));var disk=FileAccess.get_file_as_string(app.save_path)
 app.game.roster[0].xp=17;var original=app.game.save_data("camp").duplicate(true)
 app.preferences.values.combat="all";app.preferences.values.auto_end=false;var preferences=app.preferences.values.duplicate(true)
 app.show_options("camp");app.ui.find_child("DebugMode",true,false).button_pressed=true;app.show_debug_encounters()
 var before=app.game.save_data("camp").duplicate(true);var trace=app.debug_session.trace.report();var debug_disk=FileAccess.get_file_as_string(app.save_path+".debug")
 for size in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=size;await process_frame;await process_frame
  var recruits=app.ui.find_child("EncounterRecruit",true,false);var equipment=app.ui.find_child("EncounterEquipment",true,false)
  for recruit in app.game.content.roster:
   choose(recruits,recruit.id);assert(equipment.selected==0 and app.encounter_item.is_empty())
   assert(equipment.icon.resource_path=="res://assets/ui/items/"+app.game.item_for(recruit).id+".svg","Changing recruits restores the matching normal-equipment icon")
   var items=app.game.equipment.filter(func(item):return item.kind==recruit.weapon);assert(equipment.item_count==items.size()+1)
   for item in items:
    choose(equipment,item.id);assert(app.encounter_item==item.id)
    assert(equipment.icon.resource_path=="res://assets/ui/items/"+item.id+".svg" and equipment.get_popup().get_item_icon(equipment.selected)==equipment.icon,"The selected control and popup entry retain the same actual item artwork")
    var detail=app.ui.find_child("EncounterDetail",true,false)
    var chapter=maxi(maxi(Encounters.scene_for_recruit(app.game.content.roster,recruit.id).chapter,int(recruit.join)),int(item.unlock))
    assert(detail.text.contains(app.game.content.chapters[chapter].place) and detail.text.contains(item.name) and detail.text.contains("target %d tile"%int(item.max_range)))
  for name in ["EncounterEquipment","EncounterDetail","StageRecruitEncounter"]:
   var control=app.ui.find_child(name,true,false);var scroll=control.get_parent().get_parent();scroll.ensure_control_visible(control);await process_frame;await process_frame
   assert(scroll.get_global_rect().grow(1).encloses(control.get_global_rect()) and control.size.x>=control.get_minimum_size().x)
 assert(app.game.save_data("camp")==before and app.debug_session.trace.report()==trace and app.preferences.values==preferences and FileAccess.get_file_as_string(app.save_path)==disk and FileAccess.get_file_as_string(app.save_path+".debug")==debug_disk)
 for model in ["current","revised"]:
  for sample in [["oren","sentinel","javelin"],["ari","pathfinder","longbow"],["vela","spellwarden","thunder"],["galen","wayfarer","beacon_staff"],["oren","sentinel","rally_lance"],["galen","wayfarer","vigil_staff"]]:
   app.show_debug_encounters();await process_frame;await process_frame
   app.ui.find_child("EncounterModels_"+model,true,false).pressed.emit()
   choose(app.ui.find_child("EncounterRecruit",true,false),sample[0]);choose(app.ui.find_child("EncounterTraining",true,false),sample[1]);choose(app.ui.find_child("EncounterEquipment",true,false),sample[2])
   app.ui.find_child("StageRecruitEncounter",true,false).pressed.emit();await process_frame;await process_frame
   var actor=app.selected;var recipient=app.game.at(app.cursor_tile)
   assert(app.screen=="battle" and actor.id==sample[0] and actor.promotion==sample[1] and actor.item==sample[2] and app.target==null)
   assert(app.game.distance(actor,recipient)==app.game.item_for(actor).max_range)
   assert(app.debug_session.report(app.game).recent_actions.entries[-1].reason=="encounter:recruit:"+":".join(sample))
   var expected=Rules.new();assert(expected.restore_save(app.game.save_data("battle"))=="battle")
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
   var equipment=app.ui.find_child("EncounterEquipment",true,false);assert(equipment.get_item_metadata(equipment.selected)==sample[2])
 app.show_options("battle");app.ui.find_child("DebugMode",true,false).button_pressed=false
 assert(app.game.save_data("camp")==original and FileAccess.get_file_as_string(app.save_path)==disk and app.preferences.values==preferences)
 await Shutdown.dispose(app)

func visibility():
 var viewport=SubViewport.new();viewport.size=Vector2i(1440,900);viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-encounter-equipment-view-%d.json"%Time.get_ticks_usec();viewport.add_child(app);await process_frame
 app.debug_session.begin(app.game,"camp")
 var items={"sword":"estoc","lance":"javelin","axe":"war_hammer","bow":"longbow","magic":"thunder","staff":"beacon_staff"}
 for dimensions in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
  viewport.size=dimensions;await process_frame
  assert(app.camera.get_viewport().get_visible_rect().size==Vector2(dimensions))
  for recruit in app.game.content.roster:
   var setup=app.debug_session.start_recruit_encounter(app.game,recruit.id,"",items[recruit.weapon]);app.open_debug_encounter(setup,"equipment-view")
   await process_frame;await process_frame
   var recipient=app.game.at(app.cursor_tile);var bounds=app.unit_nodes[recipient.id].screen_bounds(app.camera)
   var safe=Rect2(Vector2(22,112),Vector2(dimensions.x-365,dimensions.y-222))
   assert(safe.encloses(bounds) and not bounds.intersects(app.terrain_card.get_global_rect()),"Equipped recipient visible: "+recruit.id+" / "+str(dimensions)+" / "+str(bounds))
   assert(app.target==null and app.forecast_panel==null and app.markers.has_node("MapCursor"))
 await Shutdown.dispose(app);viewport.queue_free();await process_frame
