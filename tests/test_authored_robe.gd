extends SceneTree
const Models=preload("res://scripts/combat_models.gd")
const Rules=preload("res://scripts/rules.gd")
const Robe=preload("res://scripts/authored_robe.gd")
const Bounds=preload("res://scripts/skinned_bounds.gd")
func _initialize():call_deferred("run")
func run():
 var studies=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json"));var rules=Rules.new();var stage=Node3D.new();root.add_child(stage)
 var samples=0;var lowest=INF;var clipped=0;var worst_stretch=0.0;var worst_case=[]
 for pair in [["caster","tarin"],["caster_female","vela"]]:
  var spec=studies[pair[0]].duplicate(true);spec.appearance="Identity";var models=Models.new("");models.catalog={"characters":{pair[1]:spec}}
  var unit=rules.roster.filter(func(value):return value.id==pair[1])[0].duplicate(true);unit.team="player"
  var actor=models.build(stage,unit,Vector3(35,0,0));var other=models.build(stage,unit,Vector3(40,0,0));await process_frame
  var identity=actor.model.get_node("Identity");var robe=identity.robe;var rig=actor.model.get_node("Rig/Armature/Skeleton3D")
  assert(robe.pieces.size()==2 and Robe.fitted(rig)==Robe.fitted(rig))
  assert(other.model.get_node("Identity").robe.pieces[0].mesh==robe.pieces[0].mesh and other.model.get_node("Identity").robe.surfaces[0]!=robe.surfaces[0],"Fitted geometry is cached while visible material state remains private")
  var entries=[]
  for mesh in robe.pieces:
   assert(mesh.get_node(mesh.skeleton)==rig and mesh.skin.get_bind_count()==5)
   var bounds=Bounds.new();assert(bounds.configure(mesh),"Robe participates in animated preview bounds")
   var arrays=mesh.mesh.surface_get_arrays(0);var vertices=arrays[Mesh.ARRAY_VERTEX];var weights=arrays[Mesh.ARRAY_WEIGHTS];var bones=arrays[Mesh.ARRAY_BONES];var bind_bones=[]
   for index in range(mesh.skin.get_bind_count()):
    var bone=rig.find_bone(mesh.skin.get_bind_name(index));bind_bones.append(bone)
    assert((rig.get_bone_global_rest(bone)*mesh.skin.get_bind_pose(index)).is_equal_approx(Transform3D.IDENTITY),"Robe inverse binds preserve the fitted rest shape")
   for index in range(vertices.size()):
    var sum=0.0
    for influence in range(4):
     var at=index*4+influence;assert(weights[at]>=0 and bones[at]>=0 and bones[at]<5);sum+=weights[at]
    assert(absf(sum-1.0)<4.0/65535.0,"Normalized weights survive the mesh format’s 16-bit packing")
   entries.append({"mesh":mesh,"arrays":arrays,"bones":bind_bones,"bounds":bounds})
  var fabric=entries[0].arrays;var hem=entries[1].arrays
  for index in range(hem[Mesh.ARRAY_VERTEX].size()):
   if hem[Mesh.ARRAY_TEX_UV][index].y>.01:continue
   var edge=hem[Mesh.ARRAY_VERTEX][index]
   var nearest=-1;var distance=INF
   for candidate in range(fabric[Mesh.ARRAY_VERTEX].size()):
    var gap=edge.distance_to(fabric[Mesh.ARRAY_VERTEX][candidate])
    if gap<distance:nearest=candidate;distance=gap
   assert(distance<.00001,"Gold hem joins the final fabric row without an overlapping layer")
   for influence in range(4):
    assert(hem[Mesh.ARRAY_BONES][index*4+influence]==fabric[Mesh.ARRAY_BONES][nearest*4+influence])
    assert(absf(hem[Mesh.ARRAY_WEIGHTS][index*4+influence]-fabric[Mesh.ARRAY_WEIGHTS][nearest*4+influence])<.0001,"Trim and matching fabric vertices deform together")
  for height in [0.0,.65]:
   actor.position.y=height;actor.rotation.y=.8 if height>0 else -PI/2;robe._process(0)
   for material in robe.surfaces:
    assert(material.get_shader_parameter("cloth_floor_enabled") and is_equal_approx(material.get_shader_parameter("cloth_floor_y"),height+.018))
    assert(is_zero_approx(material.get_shader_parameter("cloth_amount")),"Skinned robe does not inherit the cape's displacement or company-mark UVs")
   for key in ["idle","advance","windup","strike","recover","hit","evade","down","victory"]:
    var mapping=actor.poses[key]
    for step in range(17):
     actor.player.stop();actor.player.play(mapping.clip,0);actor.player.seek(lerpf(mapping.from,mapping.to,float(step)/16),true,true);actor.player.pause();actor.refresh_skeleton()
     for entry in entries:
      var mesh=entry.mesh;var arrays=entry.arrays;var vertices=arrays[Mesh.ARRAY_VERTEX];var posed=[];var transforms=[]
      for index in range(entry.bones.size()):transforms.append(rig.get_bone_global_pose(entry.bones[index])*mesh.skin.get_bind_pose(index))
      var bound_points=entry.bounds.points(actor);var box=AABB(bound_points[0],Vector3.ZERO)
      for point in bound_points:box=box.expand(point)
      for index in range(vertices.size()):
       var point=Vector3.ZERO;var normal=Vector3.ZERO
       for influence in range(4):
        var at=index*4+influence;var transform=transforms[arrays[Mesh.ARRAY_BONES][at]];var weight=arrays[Mesh.ARRAY_WEIGHTS][at]
        point+=(transform*vertices[index])*weight;normal+=(transform.basis*arrays[Mesh.ARRAY_NORMAL][index])*weight
       assert(point.is_finite() and normal.is_finite() and normal.length()>.1)
       var world=rig.to_global(point);var local=actor.to_local(world)
       assert(box.grow(.001).has_point(local),"Conservative animated bounds enclose every skinned garment vertex")
       lowest=minf(lowest,world.y-height)
       if world.y<height+.018:clipped+=1
       posed.append(point)
       if arrays[Mesh.ARRAY_BONES][index*4]==0 and arrays[Mesh.ARRAY_WEIGHTS][index*4]>.999:assert(point.distance_to(transforms[0]*vertices[index])<.000001,"The waistband stays attached to the pelvis without leg drift")
      var indices=arrays[Mesh.ARRAY_INDEX]
      for triangle in range(0,indices.size(),3):
       for edge in range(3):
        var a=indices[triangle+edge];var b=indices[triangle+(edge+1)%3];var length=vertices[a].distance_to(vertices[b])
        if length>.001 and posed[a].distance_to(posed[b])/length>worst_stretch:
         worst_stretch=posed[a].distance_to(posed[b])/length;worst_case=[pair[1],key,step,str(mesh.name),str(vertices[a]),str(vertices[b])]
     samples+=1
  var fade=load("res://scripts/combat_defeat.gd").new();stage.add_child(fade);fade.begin(actor);fade.apply_visibility(.3)
  for index in range(robe.pieces.size()):
   assert(robe.surfaces[index]==robe.pieces[index].material_override and is_equal_approx(robe.surfaces[index].get_shader_parameter("defeat_visibility"),.3),"Visible robe materials remain bound after defeat creates fading copies")
  actor.position.y=1.2;robe._process(0)
  for material in robe.surfaces:assert(is_equal_approx(material.get_shader_parameter("cloth_floor_y"),1.218))
  fade.queue_free();actor.queue_free();other.queue_free();await process_frame
 print("Measured maximum edge stretch ",worst_stretch," case ",worst_case)
 assert(worst_stretch<2.5,"Original garment edges do not stretch without bound during the source poses")
 assert(Robe.cache.size()==2,"Repeated studies reuse one garment fit per source body")
 stage.queue_free();await process_frame
 print("PASS: ",samples," skinned robe poses, normalized weights, exact waistband, cached geometry/private materials, animated bounds and relocated fading floor plane; uncorrected minimum ",lowest," m, floor-constrained vertices ",clipped,", maximum edge stretch ",worst_stretch)
 quit()
