extends SceneTree
const Fighters=preload("res://scripts/fighters.gd")
const Rules=preload("res://scripts/rules.gd")
const Framing=preload("res://scripts/preview_camera.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
const POSES=["idle","windup","critical_windup","strike","recover","cast_windup","cast","guard","hit","critical_hit","down","victory_flourish","victory"]
func _initialize():call_deferred("run")
func run():
 var viewport=SubViewport.new();viewport.size=Vector2i(1024,640);root.add_child(viewport)
 var world=Node3D.new();viewport.add_child(world);var camera=Camera3D.new();world.add_child(camera);camera.current=true
 var controls=Control.new();viewport.add_child(controls);controls.position=Vector2(28,28);controls.size=Vector2(310,584)
 var painter=Fighters.new();var rules=Rules.new();var samples=0;var looks=0
 var saved=rules.roster.duplicate(true);var rng=rules.rng.state
 for recruit in rules.roster:
  var paths=[""]
  for promotion in rules.promotion_options(recruit):paths.append(promotion.id)
  for path in paths:
   var unit=recruit.duplicate(true);unit.team="player";unit.promotion=path
   var actor=painter.build(world,unit,Vector3(35,0,0));actor.set_process(false)
   var framing=Framing.new();world.add_child(framing);framing.configure(actor,camera,controls,POSES);framing.set_process(false)
   assert(actor.pose_name=="idle" and not actor.face_blink.focused and not actor.face_blink.closed,"Measuring a new outfit restores its ready stance and attentive face")
   var radius=framing.radius;var low=framing.low;var high=framing.high
   for pose_key in POSES:
    actor.pose(pose_key,1).custom_step(1);actor.apply_constraints();framing._process(0)
    for size_value in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
     viewport.size=size_value;framing.reframe();var fixed=camera.transform;var offset=camera.h_offset
     for turn in range(12):
      actor.rotation.y=PI-.35+turn*PI/6
      var area=framing.clear_rect().grow(.01)
      for entry in framing.geometry:
       for vertex in entry[1]:
        var point=entry[0].to_global(vertex)
        assert(not camera.is_position_behind(point) and area.has_point(camera.unproject_position(point)),"Complete outfit and weapon fit beside controls: "+unit.id+" "+path+" "+pose_key+" "+str(size_value)+" "+str(turn))
      assert(camera.transform==fixed and camera.h_offset==offset,"Pose and rotation never pump the sampled camera frame")
      samples+=1
   assert(framing.radius==radius and framing.low==low and framing.high==high,"Measured envelope stays stable throughout normal actions")
   for zoom_value in [.6,1.3]:
    framing.zoom=zoom_value
    for size_value in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
     viewport.size=size_value;framing.reframe()
     assert(framing.clear_rect().has_point(camera.unproject_position(actor.socket_position("gaze"))),"Inspection zoom keeps the actual face inside the free viewer area")
   framing.zoom=1.0;framing.reframe()
   actor.rotation.y=0;actor.pose("idle",1).custom_step(1)
   actor.bones.Weapon.position.x+=3
   framing._process(0)
   assert(framing.radius>radius,"Unexpected future equipment or imported animation can expand the frame")
   framing.free();actor.queue_free();await process_frame;looks+=1
 assert(rules.roster==saved and rules.rng.state==rng,"Camera measurement cannot alter progression or randomness")
 viewport.queue_free();await process_frame
 root.size=Vector2i(1440,900)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-preview-camera-save.json";root.add_child(app);await process_frame
 for job in ["Vanguard","Rider","Warden"]:
  var unit=app.game.roster.filter(func(value):return value.job==job)[0]
  app.show_model_view(unit);await process_frame;await process_frame
  var framing=app.stage.get_node("PreviewCamera")
  assert(framing.actor==app.preview_actor and framing.camera==app.camera,"Real viewer owns the actual outfit and active camera")
  verify_gestures(app,framing)
  var selector=app.ui.find_child("PreviewAction",true,false)
  selector.item_selected.emit(selector.item_count-2);await process_frame
  assert(app.preview_actor.pose_name=="victory_flourish","Real action selector still plays the selected pose")
  app.close_model_view();await process_frame
  assert(app.screen=="dossier" and not is_instance_valid(framing),"Closing preview destroys its camera controller")
 await Shutdown.dispose(app);await process_frame
 print("PASS: ",looks," base/promoted outfits and ",samples," full-mesh preview layouts, stable rotation/action framing, bounded face-focused zoom, real drag/scroll/fit input, live expansion and viewer lifecycle")
 quit()

func pointer_button(point: Vector2,button: int,pressed=true,double=false):
 var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=button;event.pressed=pressed;event.double_click=double
 Input.parse_input_event(event);Input.flush_buffered_events()
 if pressed and button in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
  var release=event.duplicate();release.pressed=false;Input.parse_input_event(release);Input.flush_buffered_events()

func pointer_motion(point: Vector2,relative: Vector2,held=true):
 var event=InputEventMouseMotion.new();event.position=point;event.global_position=point;event.relative=relative;event.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0
 Input.parse_input_event(event);Input.flush_buffered_events()

func verify_gestures(app,framing):
 var area=framing.clear_rect();var center=area.get_center();var panel=framing.controls.get_global_rect().get_center()
 var original=app.camera.transform;var offset=app.camera.h_offset;var saved=app.game.save_data("camp").duplicate(true);var rng=app.game.rng.state
 assert(framing.hint.get_minimum_size().x<=framing.hint.size.x and framing.hint.get_rect().end.y<=app.ui.size.y,"Gesture hint fits below the model without entering its frame")
 pointer_button(panel,MOUSE_BUTTON_WHEEL_UP)
 assert(framing.zoom==1.0,"Scrolling over the controls never zooms the model")
 pointer_button(center,MOUSE_BUTTON_WHEEL_UP)
 assert(framing.zoom<1 and app.camera.transform!=original,"Real viewer scroll zooms toward the outfit")
 for index in range(20):pointer_button(center,MOUSE_BUTTON_WHEEL_UP)
 assert(is_equal_approx(framing.zoom,.6) and area.has_point(app.camera.unproject_position(app.preview_actor.socket_position("gaze"))),"Close inspection is bounded and focuses toward the face")
 for index in range(20):pointer_button(center,MOUSE_BUTTON_WHEEL_DOWN)
 assert(is_equal_approx(framing.zoom,1.3),"Repeated zoom-out has a stable limit")
 pointer_button(center,MOUSE_BUTTON_LEFT,true,true);pointer_button(center,MOUSE_BUTTON_LEFT,false)
 assert(framing.zoom==1 and not framing.dragging and app.camera.transform.is_equal_approx(original) and is_equal_approx(app.camera.h_offset,offset),"Double-click restores the original full-outfit composition")
 var rotation=app.preview_actor.rotation.y
 pointer_button(center,MOUSE_BUTTON_LEFT);pointer_motion(panel,Vector2(80,0))
 assert(framing.dragging and absf(angle_difference(rotation,app.preview_actor.rotation.y)-.72)<.001,"Dragging turns the actual model even when the pointer crosses the panel")
 pointer_button(panel,MOUSE_BUTTON_LEFT,false);rotation=app.preview_actor.rotation.y;pointer_motion(center,Vector2(40,0),false)
 assert(not framing.dragging and app.preview_actor.rotation.y==rotation,"Release outside the viewer prevents further rotation")
 pointer_button(center,MOUSE_BUTTON_LEFT);pointer_motion(center,Vector2.ZERO,false)
 assert(not framing.dragging,"A missing held-button mask cancels a lost drag")
 pointer_button(center,MOUSE_BUTTON_LEFT);framing.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 assert(not framing.dragging,"Focus loss cannot leave rotation latched")
 assert(app.screen=="model" and app.game.save_data("camp")==saved and app.game.rng.state==rng,"Inspection gestures do not activate panel buttons or modify progression")
