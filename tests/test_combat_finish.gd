extends SceneTree
const Fighters=preload("res://scripts/fighters.gd")
const Rules=preload("res://scripts/rules.gd")
const Director=preload("res://scripts/combat_camera.gd")
const Finish=preload("res://scripts/combat_finish.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var observed=[]
var skip_finish=false
var expected_caption=""

func watch_finish(node):
 if not node is Finish:return
 await process_frame
 var app=node.get_parent().get_parent()
 var actors=app.stage.get_children().filter(func(child):return child is Fighters.Actor and not child.is_queued_for_deletion())
 var standing=actors.filter(func(actor):return actor.pose_name=="victory")
 assert(standing.size()==1 and actors.any(func(actor):return actor.pose_name=="down"),"Only the surviving fighter finishes while the defeated actor stays down")
 assert(app.ui.get_node("CombatCaption").text==expected_caption,"The confirmed survivor receives their own finishing line, with a name-only enemy fallback")
 observed.append(standing[0].kind)
 if skip_finish:
  var tab=InputEventKey.new();tab.keycode=KEY_TAB;tab.pressed=true;app._input(tab)

func _initialize():call_deferred("run")
func run():
 var painter=Fighters.new();painter.batching_enabled=false
 var rules=Rules.new();var world=Node3D.new();root.add_child(world)
 var camera=Camera3D.new();world.add_child(camera);camera.current=true
 var samples=0;var lines=[]
 for recruit in rules.roster:
  var unit=recruit.duplicate(true);unit.team="player"
  var line=Finish.quote_for(unit,painter.profiles)
  assert(not line.is_empty() and line not in lines,"Every recruit has an individual original finishing line")
  lines.append(line)
  var label=Label.new();label.add_theme_font_size_override("font_size",30);label.text=unit.name+" — "+line;root.add_child(label)
  assert(label.get_minimum_size().x<1024-48,"Name and full line fit the narrowest supported combat caption with outline margins")
  label.queue_free()
  unit.team="enemy";assert(Finish.quote_for(unit,painter.profiles).is_empty(),"Enemy IDs cannot borrow recruit dialogue")
 assert(Finish.quote_for({"id":"unknown","team":"player"},painter.profiles).is_empty(),"Old/custom saves keep a name-only fallback")
 for recruit in rules.roster:
  for direction in [-1,1]:
   var unit=recruit.duplicate(true);unit.team="player"
   var actor=painter.build(world,unit,Vector3(35,0,0));actor.set_process(false);actor.rotation.y=-direction*PI/2
   actor.pose("recover",1).custom_step(1)
   var idle_arm=actor.bones.Arm.rotation
   var motion=actor.pose("victory",1)
   for step in range(5):
    motion.custom_step(.25);actor.apply_constraints()
    assert(not actor.face_blink.closed,"Finishing face remains attentive")
    for mesh in actor.bones.Weapon.find_children("*","MeshInstance3D",true,false):
     for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
      assert(mesh.to_global(vertex).y>-.01,"Held weapon never intersects the floor while being lowered")
   assert(actor.bones.Arm.rotation.distance_to(idle_arm)>.1,"Weapon arm has a distinct finishing silhouette")
   if not actor.mounted:
    var bottom=INF
    for side in ["LeftKnee","RightKnee"]:
     var boot=actor.bones[side].get_node("Boot")
     for vertex in boot.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:bottom=minf(bottom,boot.to_global(vertex).y)
    assert(bottom>=-.001 and bottom<.018,"Infantry retains a planted supporting foot")
   for size_value in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
    root.size=size_value
    var frame=Director.frame_pair(actor.position,actor.position+Vector3(direction*4,0,0),"finish",false,actor.mounted)
    camera.position=frame.anchor;camera.look_at(frame.focus);camera.fov=frame.lens
    assert(frame.anchor.z>0 and signf(frame.anchor.x-frame.focus.x)==direction,"Finishing camera sees the fighter's front without crossing the combat axis")
    for key in ["Head","Body"]:
     var point=camera.unproject_position(actor.bones[key].global_position)
     assert(point.x>100 and point.x<size_value.x-100 and point.y>55 and point.y<size_value.y-160,"Head and torso remain above the combat nameplates at every supported size")
    samples+=1
   actor.queue_free();await process_frame
 world.queue_free();await process_frame
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-finish-test.json";root.add_child(app);await process_frame
 app.game.start_battle();app.make_map();app.show_battle();app.busy=true
 app.stage.child_entered_tree.connect(watch_finish)
 var a=app.game.units[0];var b=app.game.living("enemy")[0];a.x=8;a.y=4;b.x=9;b.y=4
 var start_camera=app.camera.transform;var saved=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state
 for mode in ["kill","counter","survive","skip"]:
  skip_finish=mode=="skip";observed.clear()
  var attacker=b if mode=="counter" else a;var target=a if mode=="counter" else b
  var quote=Finish.quote_for(attacker,app.fighters.profiles)
  expected_caption=attacker.name+(" — "+quote if not quote.is_empty() else "")
  var event={"actor":attacker.id,"target":target.id,"damage":1,"remaining":1 if mode=="survive" else 0,"hit":true,"crit":false}
  await app.cinematic(a,b,[event],{a.id:2,b.id:2})
  await process_frame
  assert(observed.size()==(0 if mode=="survive" else 1),"A finishing pose requires a resolved defeat, including counters")
  assert(not app.stage.has_node("CombatFinish") and app.world.visible and not app.stage.visible,"Finish/skip removes the sequence and restores the map")
  assert(app.camera.transform.is_equal_approx(start_camera) and app.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"Finish shot cannot retain ownership of the tactical camera")
  assert(app.game.save_data("battle")==saved and app.game.rng.state==rng,"Finishing never resolves or changes combat results")
 await Shutdown.dispose(app);await process_frame
 print("PASS: %d finishing camera layouts, 24 original caption fits, enemy/custom fallbacks, 48 planted weapon-rest poses, resolved kills/counters, no false finishes, Tab interruption and complete map restoration"%samples)
 quit()
