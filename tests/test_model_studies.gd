extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
const Imported=preload("res://scripts/imported_fighter.gd")
func _initialize():call_deferred("run")

func run():
 root.size=Vector2i(1440,900)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-model-study-save.json";root.add_child(app);await process_frame
 var normal=app.game.save_data("camp").duplicate(true)
 app.show_source_model_view("female");assert(app.screen!="model","Model studies require debug mode")
 app.debug_session.begin(app.game,"camp");app.options_return="camp"
 var saved=app.game.save_data("camp").duplicate(true);var rng=app.game.rng.state;var samples=0
 for gender in ["female","male"]:
  app.show_debug_tools("camp");await process_frame
  app.ui.find_child("ModelStudy_"+gender,true,false).pressed.emit();await process_frame;await process_frame
  assert(app.screen=="model" and app.preview_actor is Imported,"Debug controls open an actual authored actor")
  var actor=app.preview_actor;var framing=app.stage.get_node("PreviewCamera")
  framing.set_process(false)
  var skeleton=actor.model.get_node("Rig/Armature/Skeleton3D")
  assert(framing.skinned_geometry.size()==8,"Preview measures the animated meshes")
  assert(actor.sockets.size()==5 and actor.weapon_trail_points().size()==2)
  var grip=actor.model.get_node("Rig/Armature/Skeleton3D/WeaponHand/Grip")
  var hand=grip.get_parent();var expected_grip=grip.transform
  for pose_key in ["idle","advance","windup","strike","recover","hit","evade","down"]:
   var mapping=actor.poses[pose_key]
   for fraction in [0.0,.25,.5,.75,1.0]:
    actor.player.play(mapping.clip);actor.player.seek(lerpf(mapping.from,mapping.to,fraction),true,true);actor.player.pause();actor.refresh_skeleton()
    assert(hand.transform.is_equal_approx(skeleton.get_bone_global_pose(skeleton.find_bone("hand_r"))),"Weapon attachment follows the animated wrist")
    assert(grip.transform==expected_grip,"The fixed grip does not slide through the hand")
    assert(actor.weapon_trail_points()[0].distance_to(actor.weapon_trail_points()[1])>.25)
    framing.measure()
    for size_value in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
     app.ui.size=size_value;root.size=size_value;await process_frame;framing.reframe()
     for button in app.ui.find_children("*","Button",true,false):
      if button.is_visible_in_tree():assert(Rect2(Vector2.ZERO,size_value).grow(.1).encloses(button.get_global_rect()),"Study controls remain inside the smallest viewport")
     for turn in [0,2,4]:
      actor.rotation.y=turn*PI/3
      var clear=framing.clear_rect().grow(.01)
      for entry in framing.skinned_geometry:
       for point in entry[1].points(actor):assert(clear.has_point(app.camera.unproject_position(actor.to_global(point))),"Animated source body fits the actual preview")
      for entry in framing.geometry:
       for point in entry[1]:assert(clear.has_point(app.camera.unproject_position(entry[0].to_global(point))),"Original equipped sword fits the same preview")
      samples+=1
  var actions=app.stage.get_node("PreviewActionPlayer")
  var target_choice=app.ui.find_child("StudyTarget",true,false);var contact_target=actor.get_node("StudyContactTarget")
  for target_index in [1,2]:
   target_choice.select(target_index);target_choice.item_selected.emit(target_index);await actions.finished
   var target_edge=actor.weapon_trail_points()
   assert(Geometry3D.get_closest_point_to_segment(contact_target.global_position,target_edge[0],target_edge[1]).distance_to(contact_target.global_position)<.006,"Actual viewer selection fits the strike to its visible target")
   actor.rotation.y+=.7;await process_frame;await process_frame
   assert(actor.contact.target.is_equal_approx(contact_target.global_position),"Study target follows inspection rotation")
  target_choice.select(0);target_choice.item_selected.emit(0);await actions.finished
  assert(not actor.contact.has_target and contact_target.parts.all(func(part):return not part.visible),"Disabling the target restores the unmodified source strike")
  actions.play("strike");await actions.finished
  assert(actor.pose_name=="strike" and not actor.player.is_playing())
  assert(is_equal_approx(actor.player.current_animation_position,.433),"Attack ends at the measured forward-crossing frame")
  var edge=actor.weapon_trail_points();var local_tip=actor.to_local(edge[1])
  assert(local_tip.z< -1.5 and absf(local_tip.x)<.05 and local_tip.y>1.2 and local_tip.y<1.5,"Source strike crosses directly in front at chest height")
  target_choice.select(2);target_choice.item_selected.emit(2);await actions.finished
  actions.play("advance");await create_timer(.1).timeout
  assert(actions.playing and actor.player.is_playing())
  app.close_model_view();await process_frame
  assert(app.screen=="debug_tools" and not is_instance_valid(actions),"Closing source study cancels playback and returns to debug")
  assert(app.game.save_data("camp")==saved and app.game.rng.state==rng,"Model inspection never mutates the experiment")
 app.debug_session.end(app.game);assert(app.game.save_data("camp")==normal,"Leaving debug restores the original campaign")
 assert(not FileAccess.file_exists(app.save_path) and not FileAccess.file_exists(app.save_path+".debug"),"Model study does not save a campaign")
 await Shutdown.dispose(app);await process_frame
 print("PASS: ",samples," authored study layouts, live wrist/weapon sockets, contact-frame sections, replay, isolated debug entry and unchanged campaign/RNG")
 quit()
