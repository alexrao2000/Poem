extends SceneTree
const Batch=preload("res://scripts/static_batch.gd")
const Scenery=preload("res://scripts/scenery.gd")
const Rules=preload("res://scripts/rules.gd")
func _initialize():call_deferred("run")
func signature(node: Node3D) -> Dictionary:
 var batch=Batch.new();var list=[]
 # Collect baked meshes as well as original geometry for equivalence checks.
 var queue=[{"node":node,"transform":Transform3D.IDENTITY}]
 var triangles=0;var vertices=0;var totals=[0.0,0.0,0.0];var uv_totals=[0.0,0.0]
 while not queue.is_empty():
  var entry=queue.pop_back()
  for child in entry.node.get_children():
   if not child is Node3D or child.is_queued_for_deletion():continue
   var transform=entry.transform*child.transform
   if child is MeshInstance3D:
    for surface in range(child.mesh.get_surface_count()):
     var arrays=child.mesh.surface_get_arrays(surface);var points=arrays[Mesh.ARRAY_VERTEX]
     vertices+=points.size()
     triangles+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null else points.size())/3
     for point in points:
      var transformed=transform*point
      totals[0]+=float(transformed.x);totals[1]+=float(transformed.y);totals[2]+=float(transformed.z)
     if arrays[Mesh.ARRAY_TEX_UV]!=null:
      for uv in arrays[Mesh.ARRAY_TEX_UV]:uv_totals[0]+=float(uv.x);uv_totals[1]+=float(uv.y)
   queue.append({"node":child,"transform":transform})
 return {"triangles":triangles,"vertices":vertices,"sum":Vector3(totals[0],totals[1],totals[2]),"uv_sum":Vector2(uv_totals[0],uv_totals[1])}
func run():
 var world=Node3D.new();root.add_child(world)
 var shared=StandardMaterial3D.new();var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 surface.set_normal(Vector3.ONE.normalized());surface.add_vertex(Vector3.ZERO);surface.add_vertex(Vector3.RIGHT);surface.add_vertex(Vector3.UP)
 var parent=Node3D.new();parent.position=Vector3(3,1,2);world.add_child(parent)
 var shape=surface.commit()
 for i in range(2):
  var mesh=MeshInstance3D.new();mesh.mesh=shape;mesh.material_override=shared;mesh.scale=Vector3(2,3,4);mesh.position.x=i;parent.add_child(mesh)
 var before=signature(world);var batch=Batch.new();var stats=batch.combine(world);var after=signature(world)
 assert(stats.sources==2 and stats.batches==1)
 assert(before.triangles==after.triangles and before.vertices==after.vertices and before.sum.is_equal_approx(after.sum),"Batch preserves geometry and hierarchy transforms")
 var baked=world.get_children().filter(func(child):return child is MeshInstance3D)[0]
 var normals=baked.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
 assert(normals[0].distance_to(Vector3(.5,1.0/3,.25).normalized())<.0005,"Nonuniform scales use inverse-transpose normals")
 assert(baked.material_override==shared,"Material identity preserved")
 var dynamic=MeshInstance3D.new();dynamic.mesh=BoxMesh.new();dynamic.material_override=shared;dynamic.set_meta("dynamic",true);world.add_child(dynamic)
 assert(batch.combine(world).sources==0 and is_instance_valid(dynamic) and dynamic.get_parent()==world,"Explicitly dynamic and already-batched meshes are left intact")
 world.queue_free();await process_frame
 var scenery=Scenery.new();scenery.batching_enabled=false;var game=Rules.new();var total_sources=0;var total_batches=0
 for chapter in range(12):
  game.chapter=chapter;world=Node3D.new();root.add_child(world);scenery.landscape(world,game)
  before=signature(world);var began=Time.get_ticks_msec();stats=batch.combine(world);var elapsed=Time.get_ticks_msec()-began;after=signature(world)
  assert(before.vertices==after.vertices and before.triangles==after.triangles,"All chapter geometry is retained")
  assert(before.sum.distance_to(after.sum)<maxf(1,before.sum.length()*.000001),"Positions preserved within float accumulation error")
  assert(before.uv_sum.distance_to(after.uv_sum)<maxf(.1,before.uv_sum.length()*.00001),"Texture coordinates preserved")
  total_sources+=stats.sources;total_batches+=stats.batches
  print("BATCH chapter ",chapter+1,": ",stats.sources," meshes → ",stats.batches," batches / ",elapsed," ms")
  world.queue_free();await process_frame
 for chapter in range(12):
  game.chapter=chapter;world=Node3D.new();root.add_child(world);scenery.battle_landscape(world,Vector3(35,0,0),{"environment":game.info().environment})
  before=signature(world);stats=batch.combine(world);after=signature(world)
  assert(before.vertices==after.vertices and before.triangles==after.triangles,"Combat arenas retain all geometry")
  assert(before.sum.distance_to(after.sum)<maxf(1,before.sum.length()*.000001),"Arena transforms retained")
  world.queue_free();await process_frame
 assert(total_batches<total_sources*.6,"Static mesh submissions reduced by at least forty percent")
 print("PASS: 12 maps and 12 arenas retain vertices, triangles, UVs and transforms; correct scaled normals; ",total_sources," meshes → ",total_batches," batches")
 quit()
