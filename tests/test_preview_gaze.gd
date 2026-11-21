extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")
func select_action(app,key):
 var choice=app.ui.find_child("PreviewAction",true,false)
 for index in range(choice.item_count):
  if choice.get_item_metadata(index)==key:choice.select(index);choice.item_selected.emit(index);return
 assert(false,"Preview action exists: "+key)
func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-preview-gaze-test.json";root.add_child(app);await process_frame
 app.debug_session.begin(app.game,"camp");app.options_return="camp"
 var saved=app.game.save_data("camp").duplicate(true);var rng=app.game.rng.state;var cases=0
 for study in ["knight_female","rider_male","warden","warden_female","enemy_warden"]:
  for styled in [false,true]:
   var healing=study.contains("warden");var action="cast" if healing else "critical_throw"
   app.show_source_model_view(study,"beacon_staff" if healing else "javelin",styled);await process_frame;await process_frame
   var actor=app.preview_actor;var controller=app.stage.get_node("PreviewActionPlayer");var choice=app.ui.find_child("PreviewAction",true,false);var target_choice=app.ui.find_child("StudyTarget",true,false)
   assert(target_choice!=null,"Healing and throwing studies expose targets")
   if healing:assert(target_choice.get_item_text(1)=="Target: standing ally" and target_choice.get_item_text(2)=="Target: mounted ally")
   select_action(app,action);await controller.finished
   for selected in [1,2]:
    target_choice.select(selected);target_choice.item_selected.emit(selected);await controller.finished
    var marker=actor.get_node("StudyContactTarget")
    assert(choice.get_item_metadata(choice.selected)==action and controller.selected_action==action,"Target switches retain the selected healing or critical throwing action")
    assert(is_equal_approx(marker.position.z,-4) and marker.socket_position("gaze")==marker.global_position+Vector3.UP*.55)
    if styled:
     var gaze=actor.model.get_node("Identity").gaze;var face=gaze.rig.get_node("Face")
     assert(gaze.opponent.get_ref()==marker and gaze.modifier.active,"Selected study targets drive real native gaze")
     await create_timer(.4).timeout
     assert(face.global_basis.z.normalized().dot((gaze.target.global_position-face.global_position).normalized())>.998)
     for dimensions in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
      root.size=dimensions;app.ui.size=dimensions;actor.rotation.y+=PI/6;await process_frame;await process_frame
      var framing=app.stage.get_node("PreviewCamera");var clear=framing.clear_rect()
      for mesh in face.find_children("*","MeshInstance3D",true,false):
       if not mesh.is_visible_in_tree() or mesh.mesh==null:continue
       for corner in range(8):assert(clear.grow(1).has_point(app.camera.unproject_position(mesh.to_global(mesh.mesh.get_aabb().get_endpoint(corner)))),"Tracked face remains inside the clear preview region")
      for control in app.ui.find_children("*","Button",true,false):
       if control.is_visible_in_tree():assert(Rect2(Vector2.ZERO,dimensions).grow(1).encloses(control.get_global_rect()),"Healing target controls fit all supported sizes")
    cases+=1
   if healing:
    select_action(app,"cast_windup");await controller.finished
    target_choice.select(1);target_choice.item_selected.emit(1);await controller.finished
    assert(choice.get_item_metadata(choice.selected)=="cast_windup" and actor.pose_name=="cast_windup","Changing recipient retains a held healing preparation")
   target_choice.select(0);target_choice.item_selected.emit(0);await controller.finished;await process_frame
   if styled:
    var gaze=actor.model.get_node("Identity").gaze
    assert(gaze.opponent==null and not gaze.modifier.active,"Target none clears gaze instead of watching an invisible marker")
   var retained=weakref(actor);select_action(app,action);app.close_model_view();await process_frame;await process_frame
   assert(retained.get_ref()==null,"Closing the preview releases actor, target and queued action")
 assert(app.game.save_data("camp")==saved and app.game.rng.state==rng,"Target/gaze controls never mutate campaign or random state")
 await Shutdown.dispose(app);await process_frame
 print("PASS: ten source/styled gaze viewers, ",cases," standing/mounted targets, retained healing/critical selection, tracked-face bounds and controls at three sizes, target clearing and teardown with exact campaign/RNG isolation");quit()
