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
    actor.pose(pose_key,1).custom_step(1);actor.apply_constraints()
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
   actor.rotation.y=0;actor.pose("idle",1).custom_step(1)
   actor.bones.Weapon.position.x+=3
   framing._process(0)
   assert(framing.radius>radius,"Unexpected future equipment or imported animation can expand the frame")
   framing.free();actor.queue_free();await process_frame;looks+=1
 assert(rules.roster==saved and rules.rng.state==rng,"Camera measurement cannot alter progression or randomness")
 viewport.queue_free();await process_frame
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-preview-camera-save.json";root.add_child(app);await process_frame
 for job in ["Vanguard","Rider","Warden"]:
  var unit=app.game.roster.filter(func(value):return value.job==job)[0]
  app.show_model_view(unit);await process_frame;await process_frame
  var framing=app.stage.get_node("PreviewCamera")
  assert(framing.actor==app.preview_actor and framing.camera==app.camera,"Real viewer owns the actual outfit and active camera")
  var selector=app.ui.find_child("PreviewAction",true,false)
  selector.item_selected.emit(selector.item_count-2);await process_frame
  assert(app.preview_actor.pose_name=="victory_flourish","Real action selector still plays the selected pose")
  app.close_model_view();await process_frame
  assert(app.screen=="dossier" and not is_instance_valid(framing),"Closing preview destroys its camera controller")
 await Shutdown.dispose(app);await process_frame
 print("PASS: ",looks," base/promoted outfits and ",samples," full-mesh preview layouts, stable rotation/action framing, live expansion and actual viewer lifecycle")
 quit()
