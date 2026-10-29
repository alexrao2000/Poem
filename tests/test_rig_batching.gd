extends SceneTree
# Compare rigid geometry before/after batching, then exercise every animated
# joint on both representations. Sum in 64-bit scalars so batch ordering does
# not create 32-bit accumulation drift. Normal totals allow 0.00002 per triangle
# vertex for mesh normal packing and float accumulation, not visible rotation.
# Measurements concern geometry, not browser FPS.
const Fighters=preload("res://scripts/fighters.gd")
const Rules=preload("res://scripts/rules.gd")

func _initialize():call_deferred("run")

func signature(actor):
 var count=0;var px=0.0;var py=0.0;var pz=0.0;var u=0.0;var v=0.0;var nx=0.0;var ny=0.0;var nz=0.0
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
    count+=1;var point=transform*points[i];px+=point.x;py+=point.y;pz+=point.z
    if uvs!=null:u+=uvs[i].x;v+=uvs[i].y
    if normals!=null:
     var normal=(normals_basis*normals[i]).normalized();nx+=normal.x;ny+=normal.y;nz+=normal.z
 return {"count":count,"sum":Vector3(px,py,pz),"uv":Vector2(u,v),"normal":Vector3(nx,ny,nz)}

func equivalent(a,b):
 assert(a.count==b.count,"Triangle vertices retained")
 assert(a.sum.distance_to(b.sum)<maxf(.02,a.sum.length()*.000001),"Joint-relative geometry retained")
 assert(a.uv.distance_to(b.uv)<maxf(.01,a.uv.length()*.000001),"Texture UVs retained")
 assert(a.normal.distance_to(b.normal)/a.count<.00002,"Articulated lighting normals retained within mesh packing precision")

func run():
 var fighters=Fighters.new();fighters.batching_enabled=false;var rules=Rules.new()
 var stage=Node3D.new();root.add_child(stage)
 for style in ["ponytail","braid","side_braid","bun","curls"]:
  var head=Node3D.new();stage.add_child(head);fighters.Hair.build(fighters,head,{"hair":"623c31","hair_style":style},Color("bca26b"))
  var bounds=AABB();var first=true
  for mesh in head.find_children("*","MeshInstance3D",true,false):
   var part=mesh.transform*mesh.get_aabb();bounds=part if first else bounds.merge(part);first=false
  if style=="ponytail":assert(bounds.end.z>.3 and bounds.position.y<-.45,"Ponytail extends behind the crown and below the neck")
  elif style in ["braid","side_braid"]:assert(bounds.position.y<-.5,"Plait has a distinct long silhouette")
  elif style=="bun":assert(bounds.end.z>.25 and bounds.position.y>-.2,"Bun stays compact behind the head")
  elif style=="curls":assert(bounds.size.x>.35,"Curls break the smooth cap silhouette")
  head.queue_free();await process_frame
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
  for mesh in baked.find_children("*","MeshInstance3D",true,false):
   var surface=mesh.material_override
   if mesh.name=="PaintedFace":assert(surface.next_pass==null,"Painted features cannot grow into an opaque face rectangle")
   elif surface is ShaderMaterial:
    var ink=surface.next_pass
    assert(ink==fighters.Outline.material() and "cull_front" in ink.shader.code and "unshaded" in ink.shader.code,"Batched clothing and steel retain the shared silhouette pass")
    assert(ink.get_shader_parameter("width")<=.006 and not "depth_test_disabled" in ink.shader.code,"Outline stays thin and respects foreground geometry")
   if surface.next_pass==fighters.Outline.material():
    assert(mesh.extra_cull_margin>=fighters.Outline.WIDTH,"Expanded silhouette remains inside the culling margin after batching")
    var arrays=mesh.mesh.surface_get_arrays(0);var directions={};var points=arrays[Mesh.ARRAY_VERTEX];var colors=arrays[Mesh.ARRAY_COLOR]
    for i in range(points.size()):
     var key=points[i].snapped(Vector3.ONE*.00001)
     var direction=Vector3(colors[i].r,colors[i].g,colors[i].b)*2.0-Vector3.ONE
     assert(absf(direction.length()-1.0)<.015,"Encoded silhouette directions remain normalized within color packing precision")
     if directions.has(key):assert(directions[key].distance_to(direction)<.0001,"Coincident edges expand together, including faceted blades")
     directions[key]=direction
  var appearance=fighters.profiles[unit.id].appearance
  var cape=baked.bone("Cape").find_children("*","MeshInstance3D",true,false)[0]
  assert(cape.material_override is ShaderMaterial and cape.material_override.get_shader_parameter("tint")==Color(appearance.cape),"Batched cape keeps the recruit's individual costume palette")
  assert(baked.bone("Head").get_meta("hair_style")==appearance.hair_style,"Recruit hair selection survives batching")
  for pose in ["idle","advance","windup","strike","guard","hit","evade","down"]:
   original.pose(pose,.001);var motion=baked.pose(pose,.001);await motion.finished
   original.elapsed=.2;baked.elapsed=.2;original._process(0);baked._process(0)
   equivalent(signature(original),signature(baked))
  print("RIG ",unit.id,": ",stats.sources," meshes → ",stats.batches," joint batches")
  original.queue_free();baked.queue_free();await process_frame
 assert(batches<sources*.7,"Reduce rigid mesh submissions by at least thirty percent")
 for surface in fighters.surface_cache.values():assert(surface.next_pass==null,"Actor outlines do not mutate shared painted materials")
 for surface in fighters.geo.materials.values():assert(surface.next_pass==null,"Shared geometry materials remain free of character-only passes")
 for job in ["Vanguard","Knight","Ranger","Arcanist","Warden","Rider","Corsair","Duelist"]:
  var unit=rules.roster.filter(func(value):return value.job==job)[0].duplicate(true);unit.id="enemy_qa_"+job;unit.team="enemy";unit.color="#b96466"
  var actor=fighters.build(stage,unit,Vector3.ZERO);actor.set_process(false);actor.pose_tween.kill()
  var head=actor.bone("Head");assert(head.get_meta("enemy_headgear")==job,"All enemy classes select their matching head silhouette")
  var before=signature(actor);fighters.batch_rig(actor);equivalent(before,signature(actor))
  assert(head==actor.bone("Head") and not actor.get_meta("costume_colors").cloth.is_equal_approx(Color("354c77")),"Enemy head and faction color remain independent of recruit identity")
  actor.queue_free();await process_frame
 stage.queue_free();await process_frame
 print("PASS: 24 rigs preserve animated positions, normals, UVs, faces and joints; ",sources," meshes → ",batches," batches; total bake ",elapsed," ms")
 quit()
