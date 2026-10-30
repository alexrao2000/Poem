extends SceneTree
# Inspect the original skull/muzzle topology and actual bridle clearance, then
# keep mounted head posture and attachment positions through live rig updates.

const Head=preload("res://scripts/mount_head.gd")
const Mount=preload("res://scripts/mount_visuals.gd")
const Fighters=preload("res://scripts/fighters.gd")
const Rules=preload("res://scripts/rules.gd")
var triangles=[]
func _initialize():call_deferred("run")

func verify_closed(mesh: ArrayMesh):
 var arrays=mesh.surface_get_arrays(0);var points=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL];var indices=arrays[Mesh.ARRAY_INDEX];var edges={};var volume=0.0
 for index in range(0,indices.size(),3):
  var a=points[indices[index]];var b=points[indices[index+1]];var c=points[indices[index+2]]
  volume+=a.dot(b.cross(c))/6.0
  var normal=normals[indices[index]]+normals[indices[index+1]]+normals[indices[index+2]]
  assert((b-a).cross(c-a).length()>.0000001 and (b-a).cross(c-a).dot(normal)<0,"Closed mounted detail has nondegenerate outward-lit triangles")
  for offset in range(3):
   var one=str(points[indices[index+offset]].snapped(Vector3.ONE*.000001));var two=str(points[indices[index+(offset+1)%3]].snapped(Vector3.ONE*.000001))
   var edge=one+":"+two if one<two else two+":"+one;edges[edge]=edges.get(edge,0)+1
 for count in edges.values():assert(count==2,"Every skull, muzzle and leather-strap edge belongs to two faces")
 assert(volume<-.00000001,"Closed components use outward Godot winding rather than inside-out shells")

func intersect(origin: Vector3,direction: Vector3):
 var closest=null;var distance=INF
 for triangle in triangles:
  var hit=Geometry3D.ray_intersects_triangle(origin,direction,triangle[0],triangle[1],triangle[2])
  if hit!=null and origin.distance_to(hit)<distance:distance=origin.distance_to(hit);closest=hit
 return closest

func run():
 for muzzle in [false,true]:
  var mesh=Head.mesh(muzzle);verify_closed(mesh)
  var arrays=mesh.surface_get_arrays(0);var points=arrays[Mesh.ARRAY_VERTEX];var indices=arrays[Mesh.ARRAY_INDEX]
  for index in range(0,indices.size(),3):triangles.append([points[indices[index]],points[indices[index+1]],points[indices[index+2]]])
  assert(mesh.get_aabb().position.x>=-.16 and mesh.get_aabb().end.x<=.16,"Tapered silhouette retains the bridle/eye attachment envelope")
 verify_closed(Head.bridle())
 var samples=0
 for vertex in Head.bridle().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
  var center=(Head.surface_point(vertex.z,0)+Head.surface_point(vertex.z,PI))*.5
  var direction=(vertex-center).normalized();var hit=intersect(vertex+direction*.1,-direction)
  assert(hit!=null,"Every leather strap vertex lies over actual skull/muzzle geometry")
  var gap=vertex.distance_to(hit)
  assert(gap>.001 and gap<.009,"Bridle follows the head with bounded 1–9 mm skin clearance: "+str(gap))
  assert((vertex-hit).dot(direction)>0,"Leather never sinks through the head")
  samples+=1
 for side in [-1,1]:
  var eye=intersect(Vector3(side*.25,.045,-.11),Vector3(-side,0,0))
  assert(eye!=null and absf(eye.x)<.148 and absf(eye.x)>.12,"The retained eye overlaps the skull while its visible surface stays outside")
 var stage=Node3D.new();root.add_child(stage);stage.rotation.y=.7
 var painter=Fighters.new();painter.batching_enabled=false;var rules=Rules.new()
 var units=rules.roster.filter(func(unit):return unit.job=="Rider").duplicate(true)
 var enemy=units[0].duplicate(true);enemy.id="enemy_mount";enemy.team="enemy";units.append(enemy)
 var poses=0
 for unit in units:
  if not unit.has("team"):unit.team="player"
  var actor=painter.build(stage,unit,Vector3(35,0,0));actor.set_process(false)
  var head=actor.bones.HorseHead
  assert(head.has_node("HorseSkull") and head.has_node("HorseMuzzle") and head.has_node("FittedBridle"),"All rider identities use the fitted head assembly")
  for key in ["idle","advance","windup","strike","critical_hit","down","victory"]:
   actor.pose(key,1).custom_step(1)
   for step in range(8):
    if key=="advance":actor.position.z-=.1
    actor._process(.1)
    assert(absf(head.rotation.x-Mount.HEAD_PITCH)<=.0401,"Head breathing/travel stays relative to its lowered anatomical rest pose")
    assert(head.to_global(Vector3(0,-.075,-.35)).y<head.to_global(Vector3(0,.045,-.11)).y-.18,"Muzzle remains below the eye line through all live poses")
    assert(actor.reins.paths.size()==2,"Reins remain attached as the fitted head moves")
    poses+=1
  actor.queue_free();await process_frame
 stage.queue_free();await process_frame
 print("PASS: closed tapered skull/muzzle and fitted bridle, %d actual strap clearance rays, retained eyes and %d mounted posture samples across four identities"%[samples,poses])
 quit()
