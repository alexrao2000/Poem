extends SceneTree
## Verify actual bound fabric/outline materials, isolated clocks, hit-stop
## behavior and culling bounds. This does not substitute for rendered review.
const Fighters=preload("res://scripts/fighters.gd")
const Rules=preload("res://scripts/rules.gd")
const HitStop=preload("res://scripts/combat_hit_stop.gd")
func _initialize():call_deferred("run")
func run():
 var painter=Fighters.new();var game=Rules.new();var stage=Node3D.new();root.add_child(stage)
 var actors=[]
 for recruit in game.roster:
  var unit=recruit.duplicate(true);unit.team="player"
  var actor=painter.build(stage,unit,Vector3.ZERO);actor.set_process(false);actor.pose_tween.kill()
  assert(actor.cape_motion.surfaces.size()==2,"Each cape binds fabric and outline after batching")
  var cloth=actor.cape_motion.surfaces[0];var ink=actor.cape_motion.surfaces[1]
  assert(cloth.next_pass==ink and ink!=painter.Outline.material())
  assert(cloth.get_shader_parameter("tint")==Color(painter.profiles[unit.id].appearance.cape))
  for other in actors:
   assert(other.cape_motion.surfaces[0]!=cloth and other.cape_motion.surfaces[1]!=ink,"Cloth clocks cannot leak between actors sharing a palette")
  for mesh in actor.bone("Cape").find_children("*","MeshInstance3D",true,false):
   assert(mesh.extra_cull_margin>=.10,"Maximum hem deformation and outline remain in culling bounds")
   var points=mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
   var anchors=0
   for point in points:
    assert(point.y>=-1.0 and point.y<=.001,"Cape stays in the shader's shoulder-to-hem coordinate range")
    if is_zero_approx(point.y):anchors+=1
   assert(anchors>=7,"Cape has a continuous fixed shoulder edge")
  actor.elapsed=.25;actor.pose_name="advance";actor._process(.2)
  assert(cloth.get_shader_parameter("cloth_clock")==actor.elapsed and ink.get_shader_parameter("cloth_clock")==actor.elapsed)
  var moving=actor.cape_motion.drive
  assert(moving>.5 and moving<.9,"Approach smoothly increases fabric motion")
  actor.pose_name="idle";actor._process(.8)
  assert(actor.cape_motion.drive<moving and actor.cape_motion.drive>.12,"Ready stance settles gradually")
  assert(cloth.get_shader_parameter("cloth_drive")==ink.get_shader_parameter("cloth_drive"))
  actor.pose_name="hit";actor._process(1.0);var recoil=actor.cape_motion.drive
  actor.pose_name="critical_hit";actor._process(.3)
  assert(actor.cape_motion.drive>recoil and actor.cape_motion.drive<=.9,"Critical recoil drives a stronger bounded cloth response")
  actors.append(actor)
 for material in painter.surface_cache.values():assert(material.get_shader_parameter("cloth_amount")!=1.0,"Shared body fabrics never opt into cloth deformation")
 assert(painter.Outline.material().get_shader_parameter("cloth_amount")!=1.0,"Shared armor/weapon outline never opts into cloth deformation")
 var held=actors[0];var other=actors[1];held.set_process(true);other.set_process(true)
 var hold=HitStop.new();root.add_child(hold);hold.play([held],.2);hold.motion.pause()
 var frozen=held.cape_motion.surfaces[0].get_shader_parameter("cloth_clock")
 var free_clock=other.elapsed
 for frame in range(3):await process_frame
 assert(held.cape_motion.surfaces[0].get_shader_parameter("cloth_clock")==frozen and held.cape_motion.surfaces[1].get_shader_parameter("cloth_clock")==frozen,"Local hit stop freezes both fabric passes")
 assert(other.elapsed>free_clock,"Another actor's cape clock keeps running")
 hold.queue_free();await process_frame
 for frame in range(3):await process_frame
 assert(held.cape_motion.surfaces[0].get_shader_parameter("cloth_clock")>frozen,"Cloth resumes with the restored actor")
 stage.queue_free();await process_frame
 print("PASS: 24 independently animated cape pairs, anchored geometry, bounded motion, matching fabric/outline clocks, idle settling and local hit-stop restoration")
 quit()
