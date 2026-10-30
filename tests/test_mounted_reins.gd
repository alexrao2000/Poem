extends SceneTree
const Fighters=preload("res://scripts/fighters.gd")
const Rules=preload("res://scripts/rules.gd")
const Reins=preload("res://scripts/mounted_reins.gd")
const HitStop=preload("res://scripts/combat_hit_stop.gd")
func _initialize():call_deferred("run")

func inspect(actor):
 var reins=actor.reins;var head=actor.bones.HorseHead;var hand=actor.bones.LeftElbow.to_global(Vector3(0,-.29,0))
 assert(reins.get_parent()==actor and reins.paths.size()==2,"One dynamic mesh owns both straps outside the rigid joints")
 for index in range(2):
  var side=-1 if index==0 else 1;var path=reins.paths[index]
  assert(reins.to_global(path[0]).distance_to(head.to_global(Reins.BIT*Vector3(side,1,1)))<.0001,"Rein begins on the actual animated bridle fitting")
  assert(reins.to_global(path[-1]).distance_to(hand)<.013,"Both reins terminate inside the moving free-hand grip")
  for point in path:
   var local=actor.bones.Horse.to_local(reins.to_global(point))
   var neck=(local-Vector3(0,.34,-.52))/Vector3(.19,.47,.2)
   assert(neck.length_squared()>1.04,"Straps route around the solid neck with clearance for their thickness")
   assert(reins.to_global(point).y>actor.global_position.y+1.3,"Reins never sag through the horse's body or arena floor")
 var arrays=reins.mesh.surface_get_arrays(0);var points=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL];var indices=arrays[Mesh.ARRAY_INDEX];var edges={}
 assert(indices.size()==408,"Two closed eight-segment straps stay within 136 triangles")
 for index in range(0,indices.size(),3):
  var a=points[indices[index]];var b=points[indices[index+1]];var c=points[indices[index+2]]
  var outward=normals[indices[index]]+normals[indices[index+1]]+normals[indices[index+2]]
  assert((b-a).cross(c-a).length()>.0000001 and (b-a).cross(c-a).dot(outward)<0,"Curved strap faces are nondegenerate and outward-lit with Godot winding")
  for offset in range(3):
   var one=str(points[indices[index+offset]].snapped(Vector3.ONE*.000001));var two=str(points[indices[index+(offset+1)%3]].snapped(Vector3.ONE*.000001))
   var edge=one+":"+two if one<two else two+":"+one;edges[edge]=edges.get(edge,0)+1
 for count in edges.values():assert(count==2,"Both leather straps have closed sides and end caps")
 assert(reins.material_override.next_pass==null and reins.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Thin straps add no separate outline or shadow pass")
 var revision=reins.revisions;actor.apply_constraints()
 assert(reins.revisions==revision,"Repeated unchanged constraints do not rebuild the mesh")

func run():
 var stage=Node3D.new();stage.position=Vector3(35,0,0);stage.rotation.y=.4;root.add_child(stage)
 var painter=Fighters.new();var rules=Rules.new();var samples=0
 var units=rules.roster.filter(func(unit):return unit.job=="Rider").duplicate(true)
 var enemy=units[0].duplicate(true);enemy.id="enemy_rein_test";enemy.team="enemy";units.append(enemy)
 for recruit in units:
  var unit=recruit.duplicate(true)
  if not unit.has("team"):unit.team="player"
  for batched in [false,true]:
   painter.batching_enabled=batched
   var actor=painter.build(stage,unit,Vector3.ZERO);actor.set_process(false)
   for facing in [-PI/2,PI/2]:
    actor.rotation.y=facing
    for key in ["idle","advance","windup","critical_windup","strike","recover","throw_windup","critical_throw_windup","throw","guard","hit","critical_hit","evade","down","victory_flourish","victory"]:
     var motion=actor.pose(key,1)
     for step in range(4):
      motion.custom_step(.25);actor.apply_constraints();inspect(actor);samples+=1
   actor.pose("idle",1).custom_step(1);actor.set_process(true)
   var stop=HitStop.new();root.add_child(stop);stop.play([actor],1).pause()
   var mesh=actor.reins.mesh;var revision=actor.reins.revisions
   for frame in range(3):await process_frame
   assert(actor.reins.mesh==mesh and actor.reins.revisions==revision,"Hit stop freezes the attached straps with horse and rider")
   stop.restore();stop.queue_free();actor.queue_free();await process_frame
 stage.queue_free();await process_frame
 print("PASS: ",samples," mounted rein poses/transitions, three recruits and enemy, both facings/batching modes, transformed bridle/hand endpoints, neck clearance, closed bounded geometry, stable rebuilds and hit-stop ownership")
 quit()
