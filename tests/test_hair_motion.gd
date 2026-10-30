extends SceneTree
const Fighters=preload("res://scripts/fighters.gd")
const Rules=preload("res://scripts/rules.gd")
const Motion=preload("res://scripts/hair_motion.gd")
const Rig=preload("res://tests/test_rig_batching.gd")
const HitStop=preload("res://scripts/combat_hit_stop.gd")
func _initialize():call_deferred("run")
func run():
 var painter=Fighters.new();painter.batching_enabled=false
 var rules=Rules.new();var stage=Node3D.new();root.add_child(stage)
 var actors=[];var moving=0;var profiles={};var rng=rules.rng.state
 for recruit in rules.roster:
  var unit=recruit.duplicate(true);unit.team="player"
  var actor=painter.build(stage,unit,Vector3.ZERO);actor.set_process(false);actor.pose_tween.kill();actors.append(actor)
  var style=actor.bones.Head.get_meta("hair_style")
  if style not in ["long","ponytail","braid","side_braid"]:
   assert(actor.hair_motion.root==null and not actor.bones.has("HairFall"),"Caps, curls, buns and beards keep their existing head geometry")
   continue
  moving+=1;profiles[style]=true
  var fall=actor.bone("HairFall");var anchor=fall.position
  assert(fall==actor.hair_motion.root and fall.get_parent()==actor.bones.Head and fall.get_meta("dynamic"),"Loose hair binds a joint fixed beneath the head")
  var before=Rig.signature(actor);painter.batch_rig(actor);Rig.equivalent(before,Rig.signature(actor))
  assert(fall==actor.bone("HairFall") and fall.get_child_count()>0,"Baking preserves the root and all loose length geometry")
  var meshes=fall.find_children("*","MeshInstance3D",true,false);var reference=[]
  for mesh in meshes:
   assert(mesh.material_override.next_pass!=null,"Hair retains its thin silhouette outline after batching")
   for point in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:reference.append(mesh.to_global(point))
  var static_nodes=actor.bones.Head.get_children().filter(func(child):return child!=fall)
  var static_transforms=static_nodes.map(func(child):return child.transform)
  var clock=0.0;var maximum_movement=0.0
  for pose in ["idle","advance","critical_windup","strike","hit","victory","idle","down"]:
   for dt in [.016,.033,.1,.2,.5]:
    clock+=dt;actor.hair_motion.update(clock,pose,dt)
    assert(fall.position==anchor,"Length motion cannot detach the root from the scalp")
    assert(absf(fall.rotation.x)<=actor.hair_motion.strength+.000001 and absf(fall.rotation.z)<=actor.hair_motion.strength+.000001 and is_zero_approx(fall.rotation.y),"Secondary angles remain inside their style-specific envelope")
    assert(static_nodes.map(func(child):return child.transform)==static_transforms,"Hair motion never moves facial features, bangs or the scalp cap")
    var index=0
    for mesh in meshes:
     for point in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
      var distance=mesh.to_global(point).distance_to(reference[index]);maximum_movement=maxf(maximum_movement,distance)
      assert(distance<.12,"Actual loose hair vertices stay within a restrained twelve-centimeter envelope")
      index+=1
  assert(maximum_movement>.005,"Loose lengths actually move rather than only exposing a controller")
  var angle_before=actor.hair_motion.angle.length()
  actor.hair_motion.update(clock,"down",1.0)
  assert(actor.hair_motion.angle.length()<angle_before and actor.hair_motion.angle.length()<.001,"Defeat settles loose lengths toward their resting shape")
 assert(moving==10 and profiles.size()==4 and rules.rng.state==rng)
 var a=Motion.new();var b=Motion.new();var root_a=Node3D.new();var root_b=Node3D.new();stage.add_child(root_a);stage.add_child(root_b)
 a.root=root_a;b.root=root_b
 a.update(1.0,"advance",.5)
 for frame in range(10):b.update(1.0,"advance",.05)
 assert(a.angle.distance_to(b.angle)<.000001 and a.velocity.distance_to(b.velocity)<.000001,"Damped settling is invariant to frame subdivision for a fixed target")
 var active=actors.filter(func(actor):return actor.hair_motion.root!=null)
 var held=active[0];var other=active[1];held.set_process(true);other.set_process(true)
 var hold=HitStop.new();root.add_child(hold);hold.play([held],.2);hold.motion.pause()
 var held_angle=held.hair_motion.angle;var other_angle=other.hair_motion.angle
 for frame in range(3):await process_frame
 assert(held.hair_motion.angle==held_angle and other.hair_motion.angle!=other_angle,"Local hit stop holds hair while another actor settles")
 hold.queue_free();await process_frame
 held.hide();held_angle=held.hair_motion.angle
 for frame in range(3):await process_frame
 assert(held.hair_motion.angle==held_angle,"Hidden actors suspend hair motion")
 held.show()
 for frame in range(3):await process_frame
 assert(held.hair_motion.angle!=held_angle,"Visible actors resume settling")
 stage.queue_free();await process_frame
 print("PASS: ten personal hair rigs/four loose styles, preserved baked geometry, fixed roots, stable bounded settling, static faces/bangs, frame subdivision and local hit-stop/visibility")
 quit()
