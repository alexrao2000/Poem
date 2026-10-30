extends SceneTree
const Fighters=preload("res://scripts/fighters.gd")
const Rules=preload("res://scripts/rules.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var interrupted: WeakRef
var interrupted_position=Vector3.ZERO
func _initialize():call_deferred("run")

func skip_approach(app):
 var deadline=Time.get_ticks_msec()+10000
 while Time.get_ticks_msec()<deadline:
  await process_frame
  if not app.stage.visible:continue
  for actor in app.stage.get_children():
   if not actor is Fighters.Actor or actor.pose_name!="advance" or absf(actor.gait_phase)<.1:continue
   interrupted=weakref(actor);interrupted_position=actor.position
   var key=InputEventKey.new();key.keycode=KEY_TAB;key.pressed=true;app._unhandled_input(key)
   return
 assert(false,"The real cinematic reaches its moving approach")

func lowest_boot(actor) -> float:
 var lowest=INF
 for boot in actor.find_children("Boot","MeshInstance3D",true,false):
  for point in boot.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
   lowest=minf(lowest,boot.to_global(point).y-actor.global_position.y)
 return lowest

func run():
 var fighters=Fighters.new();fighters.batching_enabled=false;var game=Rules.new();var state=game.rng.state;var samples=0
 var stage=Node3D.new();root.add_child(stage)
 for entry in game.roster:
  var unit=entry.duplicate(true);unit.team="player"
  var actor=fighters.build(stage,unit,Vector3.ZERO);actor.set_process(false)
  for facing in [-PI/2,PI/2]:
   actor.rotation.y=facing
   for direction in [-1,1]:
    await actor.pose("advance",.001).finished
    for step in range(24):
     actor.position+=-actor.basis.z*.08*direction;actor._process(.016)
     if not actor.mounted:
      var height=lowest_boot(actor)
      assert(height>=-.001 and height<.025,"Actual boot vertices stay above the arena floor with a planted support foot")
     else:
      assert(is_equal_approx(actor.bones.LeftLeg.rotation.x,.85) and is_equal_approx(actor.bones.RightKnee.rotation.x,-1.25),"Distance-driven horse gait leaves the rider seated")
     samples+=1
    var phase=actor.gait_phase;var key="HorseLeg0" if actor.mounted else "LeftLeg"
    var settled=actor.bones[key].rotation
    actor._process(3.0)
    assert(is_equal_approx(phase,actor.gait_phase) and actor.bones[key].rotation.is_equal_approx(settled),"Stationary actors cannot run in place")
  await actor.pose("windup",.001).finished
  var rotation=actor.bones.LeftLeg.rotation;actor.position.x+=.2;actor._process(.02)
  assert(actor.bones.LeftLeg.rotation.is_equal_approx(rotation),"Combat poses reclaim locomotion joints")
  actor.queue_free();await process_frame
 # Equivalent travel, subdivided into different frames, has identical stride.
 await verify_contacts(fighters,stage,game)
 var unit=game.roster[0].duplicate(true);unit.team="player"
 var one=fighters.build(stage,unit,Vector3.ZERO);var many=fighters.build(stage,unit,Vector3.ZERO)
 for actor in [one,many]:
  actor.set_process(false);await actor.pose("idle",.001).finished;await actor.pose("advance",.001).finished
 one.position.z-=.63;one._process(.1)
 for step in range(9):many.position.z-=.07;many._process(.1/9)
 assert(absf(one.gait_phase-many.gait_phase)<.00001 and one.bones.LeftLeg.rotation.distance_to(many.bones.LeftLeg.rotation)<.00001,"Stride follows distance independently of frame subdivision")
 var before=one.gait_phase;one.position.z+=.1;one._process(.01)
 assert(one.gait_phase<before,"Retreat reverses the gait while preserving opponent-facing orientation")
 assert(Fighters.Actor.approach_duration(3)>Fighters.Actor.approach_duration(.5) and Fighters.Actor.approach_duration(100)<=.65,"Longer approaches get bounded extra travel time")
 assert(game.rng.state==state,"Locomotion uses no gameplay randomness")
 stage.queue_free();await process_frame;await process_frame
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-locomotion-test.json"
 root.add_child(app);await process_frame;app.game.start_battle();app.make_map();app.show_battle()
 var a=app.game.units[0];var b=app.game.living("enemy")[0];a.x=8;a.y=4;b.x=9;b.y=4
 var saved=app.game.save_data("battle").duplicate(true);var camera=app.camera.transform
 skip_approach(app)
 await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"hit":true,"crit":false,"damage":1,"remaining":19}],{a.id:20,b.id:20})
 var stopped=interrupted.get_ref() if interrupted!=null else null
 assert(stopped!=null and stopped.pose_name=="advance" and stopped.position.distance_to(interrupted_position)<.1,"Tab kills the actual travel tween before preparation begins")
 assert(not app.stage.visible and app.camera.transform.is_equal_approx(camera) and app.game.save_data("battle")==saved,"Interrupted approach restores the tactical view without changing campaign state")
 await Shutdown.dispose(app);await process_frame
 print("PASS: ",samples," roster travel samples, planted actual boot geometry, mounted seating, stationary/pose isolation, reversed travel, frame-independent stride/contacts, silent stationary/hidden poses and real Tab interruption")
 quit()

func verify_contacts(fighters,stage,game):
 for job in ["Vanguard","Rider"]:
  var unit=game.roster.filter(func(entry):return entry.job==job)[0].duplicate(true);unit.team="player"
  for direction in [-1,1]:
   var totals=[]
   for subdivisions in [1,40]:
    var actor=fighters.build(stage,unit,Vector3.ZERO);actor.set_process(false)
    await actor.pose("advance",.001).finished
    var contacts=[];actor.travel_contact.connect(func(index):contacts.append(index))
    var stride=2.8 if actor.mounted else 1.6
    for step in range(subdivisions):
     actor.position.z-=stride*direction/subdivisions;actor._process(.016)
    assert(contacts==[0,1],"A complete forward or backward stride emits exactly two alternating contacts regardless of frame subdivision")
    totals.append(actor.gait_phase)
    actor._process(1);assert(contacts.size()==2,"Stationary advance cannot play walking sounds")
    actor.hide();actor.position.z-=.9;actor._process(1);assert(contacts.size()==2,"Covered actors do not emit travel cues")
    actor.show();await actor.pose("windup",.001).finished;actor.position.z-=.9;actor._process(.02)
    assert(contacts.size()==2,"Weapon poses do not borrow locomotion contacts")
    actor.queue_free();await process_frame
   assert(absf(totals[0]-totals[1])<.0001)
