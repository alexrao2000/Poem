extends SceneTree
# Compare rigid geometry before/after batching, then exercise every animated
# joint on both representations. Normal totals allow 0.00002 per triangle
# vertex for mesh normal packing and float accumulation, not visible rotation.
# Measurements concern geometry, not browser FPS.
const Fighters=preload("res://scripts/fighters.gd")
const Rules=preload("res://scripts/rules.gd")

func _initialize():call_deferred("run")

func signature(actor):
 var count=0;var sum=Vector3.ZERO;var uv_sum=Vector2.ZERO;var normal_sum=Vector3.ZERO
 var inverse=actor.global_transform.affine_inverse()
 for node in actor.find_children("*","MeshInstance3D",true,false):
  var transform=inverse*node.global_transform
  var normals_basis=transform.basis.inverse().transposed()
  for surface in range(node.mesh.get_surface_count()):
   var arrays=node.mesh.surface_get_arrays(surface)
   var points=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL];var uvs=arrays[Mesh.ARRAY_TEX_UV]
   var indices=arrays[Mesh.ARRAY_INDEX]
   if indices==null or indices.is_empty():indices=range(points.size())
   for i in indices:
    count+=1;sum+=transform*points[i]
    if uvs!=null:uv_sum+=uvs[i]
    if normals!=null:normal_sum+=(normals_basis*normals[i]).normalized()
 return {"count":count,"sum":sum,"uv":uv_sum,"normal":normal_sum}

func equivalent(a,b):
 assert(a.count==b.count,"Triangle vertices retained")
 assert(a.sum.distance_to(b.sum)<maxf(.15,a.sum.length()*.00003),"Joint-relative geometry retained")
 assert(a.uv.distance_to(b.uv)<maxf(.05,a.uv.length()*.00003),"Texture UVs retained")
 assert(a.normal.distance_to(b.normal)/a.count<.00002,"Articulated lighting normals retained within mesh packing precision")

func run():
 var fighters=Fighters.new();fighters.batching_enabled=false;var rules=Rules.new()
 var stage=Node3D.new();root.add_child(stage)
 var sources=0;var batches=0;var elapsed=0
 for entry in rules.roster:
  var unit=entry.duplicate(true);unit.team="player"
  var original=fighters.build(stage,unit,Vector3.ZERO);original.set_process(false)
  var baked=fighters.build(stage,unit,Vector3.ZERO);baked.set_process(false)
  original.pose_tween.kill();baked.pose_tween.kill()
  var bones=baked.bones.duplicate();var before=signature(baked)
  var started=Time.get_ticks_msec();fighters.batch_rig(baked);elapsed+=Time.get_ticks_msec()-started
  var stats=baked.get_meta("rig_batch_stats");sources+=stats.sources;batches+=stats.batches
  equivalent(before,signature(baked))
  for key in bones:assert(baked.bone(key)==bones[key] and bones[key].is_inside_tree(),"Animation joints survive batching")
  assert(baked.find_children("PaintedFace","MeshInstance3D",true,false).size()==1,"Face stays separately addressable")
  for pose in ["idle","advance","windup","strike","hit","evade","down"]:
   original.pose(pose,.001);var motion=baked.pose(pose,.001);await motion.finished
   original.elapsed=.2;baked.elapsed=.2;original._process(0);baked._process(0)
   equivalent(signature(original),signature(baked))
  print("RIG ",unit.id,": ",stats.sources," meshes → ",stats.batches," joint batches")
  original.queue_free();baked.queue_free();await process_frame
 assert(batches<sources*.7,"Reduce rigid mesh submissions by at least thirty percent")
 stage.queue_free();await process_frame
 print("PASS: 24 rigs preserve animated positions, normals, UVs, faces and joints; ",sources," meshes → ",batches," batches; total bake ",elapsed," ms")
 quit()
