extends SceneTree
const Imported=preload("res://scripts/imported_fighter.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")
func select_action(app,key):
 var choice=app.ui.find_child("PreviewAction",true,false)
 for index in range(choice.item_count):
  if choice.get_item_metadata(index)==key:
   choice.select(index);choice.item_selected.emit(index);return
 assert(false,"Javelin action is available: "+key)
func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.preferences.values.character_models="current";app.save_path="/private/tmp/poem-preview-critical-javelin.json";root.add_child(app);await process_frame
 app.debug_session.begin(app.game,"camp");app.options_return="camp"
 var saved=app.game.save_data("camp").duplicate(true);var rng=app.game.rng.state;var count=0
 for study in ["knight_female","knight_male","rider_female","rider_male"]:
  for styled in [false,true]:
   app.show_source_model_view(study,"javelin",styled);await process_frame;await process_frame
   var actor=app.preview_actor;var controller=app.stage.get_node("PreviewActionPlayer");var grip=actor.model.get_node("Rig/Armature/Skeleton3D/WeaponHand/Grip");var weapon=actor.projectile_source()
   select_action(app,"critical_throw_windup");await controller.finished
   assert(grip.critical_throw_prepared and weapon.visible,"Critical throw preparation is inspectable with the held spear")
   select_action(app,"critical_throw");await controller.finished
   var choice=app.ui.find_child("PreviewAction",true,false);var target_choice=app.ui.find_child("StudyTarget",true,false)
   for target in [1,2]:
    target_choice.select(target);target_choice.item_selected.emit(target);await controller.finished
    var marker=actor.get_node("StudyContactTarget")
    assert(choice.get_item_metadata(choice.selected)=="critical_throw" and controller.selected_action=="critical_throw","Changing target preserves the selected critical ranged replay")
    assert(actor.pose_name=="throw" and grip.critical_throw_prepared and not grip.critical_prepared and not weapon.visible,"Completed critical preview releases the spear and retains distinct ranged preparation")
    assert(is_equal_approx(absf(marker.position.z),4.0),"Critical throw targets use ranged distance rather than melee spacing")
    var launch_direction=(marker.global_position+Vector3.UP*PI*.08-weapon.global_position).normalized()
    assert((-weapon.global_basis.z).normalized().dot(launch_direction)>.999,"Critical release points along the real javelin launch tangent toward either target")
    count+=1
   var replay=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Play again")[0]
   replay.pressed.emit();await controller.finished;assert(grip.critical_throw_prepared and not weapon.visible)
   select_action(app,"throw");await controller.finished;assert(not grip.critical_throw_prepared and not weapon.visible,"Ordinary replay clears critical throw state")
   select_action(app,"critical_throw");select_action(app,"idle");await controller.finished;await create_timer(.1).timeout
   assert(actor.pose_name=="idle" and not grip.critical_throw_prepared and weapon.visible,"Replacing a queued critical replay restores the ordinary held spear")
   for dimensions in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
    root.size=dimensions;app.ui.size=dimensions;await process_frame;await process_frame
    for control in app.ui.find_children("*","Button",true,false):
     if control.is_visible_in_tree():assert(Rect2(Vector2.ZERO,dimensions).grow(1).encloses(control.get_global_rect()),"Critical javelin controls fit every supported window")
   var retained=weakref(actor);select_action(app,"critical_throw");app.close_model_view();await process_frame;await process_frame
   assert(retained.get_ref()==null,"Closing a critical preview releases its pending actor")
 var ordinary=app.game.roster.filter(func(unit):return unit.id=="oren")[0].duplicate(true);ordinary.team="player";ordinary.item="javelin"
 app.show_model_view(ordinary);await process_frame;assert(not app.preview_actor is Imported)
 var controller=app.stage.get_node("PreviewActionPlayer");select_action(app,"critical_throw");await controller.finished
 assert(app.preview_actor.pose_name=="throw" and not app.preview_actor.bones.Weapon.visible,"Current models retain their own critical throw preparation and release")
 app.close_model_view();await process_frame
 assert(app.game.save_data("camp")==saved and app.game.rng.state==rng,"Javelin study interactions leave campaign and random state unchanged")
 await Shutdown.dispose(app);await process_frame
 print("PASS: eight source/styled critical javelin viewers, ",count," standing/mounted targets, release aim, repeat/cancel/close, current-model replay and three-size controls without campaign/RNG mutation");quit()
