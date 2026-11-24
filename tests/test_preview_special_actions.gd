extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
const Imported=preload("res://scripts/imported_fighter.gd")
var study_ids=["female","male","vanguard","vanguard_male"]
func _initialize():call_deferred("run")
func index_for(choice,key):
 for index in range(choice.item_count):
  if choice.get_item_metadata(index)==key:return index
 return -1
func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-special-preview.json";root.add_child(app);await process_frame
 var normal=app.game.save_data("camp").duplicate(true);app.debug_session.begin(app.game,"camp");app.options_return="camp"
 var saved=app.game.save_data("camp").duplicate(true);var rng=app.game.rng.state;var count=0;var target_count=0
 for study in study_ids:
  var axe=study.begins_with("corsair");var lance=study.begins_with("knight") or study.begins_with("rider");var ranger=study.begins_with("ranger");var caster=study.begins_with("caster")
  var clip="CriticalSpellRelease" if caster else "BowRelease" if ranger else "LanceStrike" if lance else "AxeCriticalAttack" if axe else "SwordCriticalAttack"
  for styled in [false,true]:
   for item in (["ember","thunder"] if caster else ["recurve","longbow"] if ranger else ["light_lance","riders_bane"] if lance else ["hatchet","war_hammer"] if axe else ["iron_sword","estoc"]):
    app.show_source_model_view(study,item,styled);await process_frame;await process_frame
    var actor=app.preview_actor;var choice=app.ui.find_child("PreviewAction",true,false);var actions=app.stage.get_node("PreviewActionPlayer");var framing=app.stage.get_node("PreviewCamera")
    assert(actor is Imported and index_for(choice,"critical_strike")>=0 and index_for(choice,"victory_flourish")>=0,"Source and styled studies expose generated critical and finishing actions")
    for size_value in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
     root.size=size_value;app.ui.size=size_value;await process_frame;framing.reframe()
     for button in app.ui.find_children("*","Button",true,false):
      if button.is_visible_in_tree():assert(Rect2(Vector2.ZERO,Vector2(size_value)).grow(.1).encloses(button.get_global_rect()),"Expanded action list keeps its controls inside the viewport")
    var before=Vector3(framing.radius,framing.low,framing.high)
    if actor.poses.has("victory_flourish"):
     choice.select(index_for(choice,"victory_flourish"));choice.item_selected.emit(choice.selected);await actions.finished
     assert(actor.pose_name=="victory_flourish" and actor.player.assigned_animation==("SpellFinish" if caster else "LanceFinish" if lance else "BowFinish" if ranger else "AxeFinishFlourish" if axe else "SwordFinishFlourish"))
    assert(Vector3(framing.radius,framing.low,framing.high).is_equal_approx(before),"Flourish replay uses the premeasured silhouette without pumping the frame")
    choice.select(index_for(choice,"critical_strike"));choice.item_selected.emit(choice.selected);await actions.finished
    assert(actor.pose_name=="strike" and actor.player.assigned_animation==clip,"Critical attack preview plays preparation and the real contact clip")
    var equipment=actor.model.get_node("Rig/Armature/Skeleton3D/"+("BookHand/Folio" if caster else "WeaponHand/Bow" if ranger else "WeaponHand/Grip"))
    assert(equipment.critical_prepared)
    var target=app.ui.find_child("StudyTarget",true,false)
    if caster:assert(target==null and actor.to_local(actor.socket_position("projectile")).z<-.5,"Critical cast finishes with the actual free palm extended")
    for target_index in ([] if caster else [1,2]):
     target_count+=1
     target.select(target_index);target.item_selected.emit(target_index);await actions.finished
     assert(choice.get_item_metadata(choice.selected)=="critical_strike" and actor.player.assigned_animation==clip,"Changing target height preserves critical preview selection")
     var point=actor.get_node("StudyContactTarget").global_position;var edge=actor.weapon_trail_points()
     if ranger:
      var arrow=equipment.get_node("Weapon/NockedArrow")
      assert((-arrow.global_basis.z.normalized()).dot((point-arrow.global_position).normalized())>.999999 and equipment.projectile_spent and not arrow.visible,"Replayed critical shot aims its released arrow at the actual selected target")
     else:
      var gap=actor.sockets.trail_tip.global_position.distance_to(point) if item=="estoc" else Geometry3D.get_closest_point_to_segment(point,edge[0],edge[1]).distance_to(point)
      assert(gap<.006,"Replayed critical attack reaches the selected real target")
    actions.play("critical_strike");await create_timer(.04).timeout;actions.play("down");await actions.finished
    assert(actor.pose_name=="down" and actions.pending.is_empty(),"Replacing critical preparation cancels its queued strike")
    actions.play("strike");await actions.finished;assert(actor.player.assigned_animation==("Spell_Simple_Shoot" if caster else "BowRelease" if ranger else "LanceStrike" if lance else "Sword_Attack") and not equipment.critical_prepared,"Ordinary attack resets critical state after replacement")
    actions.play("critical_strike");var pending=actions.current;app.close_model_view();await process_frame
    assert(not is_instance_valid(actions) and not pending.is_valid() and app.screen=="debug_tools")
    assert(app.game.save_data("camp")==saved and app.game.rng.state==rng,"Pose inspection leaves the sandbox and RNG unchanged")
    count+=1
 app.debug_session.end(app.game);assert(app.game.save_data("camp")==normal)
 app.preferences.values.character_models="current"
 var lyra=app.game.roster.filter(func(value):return value.id=="lyra")[0]
 app.show_model_view(lyra);await process_frame
 var ordinary_choice=app.ui.find_child("PreviewAction",true,false);var ordinary_actions=app.stage.get_node("PreviewActionPlayer")
 assert(not app.preview_actor is Imported and index_for(ordinary_choice,"critical_strike")>=0)
 ordinary_choice.select(index_for(ordinary_choice,"critical_strike"));ordinary_choice.item_selected.emit(ordinary_choice.selected);await ordinary_actions.finished
 assert(app.preview_actor.pose_name=="strike" and ordinary_actions.pending.is_empty(),"Current roster replays its critical preparation and strike too")
 app.close_model_view();await process_frame
 app.preferences.values.character_models="revised"
 for id in ["lyra","mara","dax","hale","ivo","tarin","sera","petra","una"]:
  var unit=app.game.roster.filter(func(value):return value.id==id)[0];app.show_model_view(unit);await process_frame
  var choice=app.ui.find_child("PreviewAction",true,false)
  assert((index_for(choice,"victory_flourish")>=0)==(id in ["lyra","mara","dax","hale","sera","petra","una","tarin"]),"Ordinary previews omit finishing gestures unsupported by their actual actor")
  app.close_model_view();await process_frame
 assert(not FileAccess.file_exists(app.save_path) and not FileAccess.file_exists(app.save_path+".debug"))
 await Shutdown.dispose(app);await process_frame
 print("PASS: ",count," source/styled weapon previews, critical and flourish visibility, three-size controls, premeasured flourish, ",target_count," real target selections, replay/replacement/close, unsupported-action filtering and exact campaign/RNG isolation")
 quit()
