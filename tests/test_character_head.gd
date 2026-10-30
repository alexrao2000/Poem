extends SceneTree
## Validate the actual skin/decal topology, UV isolation and imported alpha.
## The overlay must reuse skin triangles rather than intersect a new curvature.
const Head=preload("res://scripts/character_head.gd")
const Fighters=preload("res://scripts/fighters.gd")
const Rules=preload("res://scripts/rules.gd")
func _initialize():call_deferred("run")
func run():
 var shape_signatures={}
 for shape in Head.SHAPES:
  var mesh=Head.mesh(shape);assert(mesh==Head.mesh(shape),"Head geometry is shared")
  var arrays=mesh.surface_get_arrays(0);var vertices=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL];var indices=arrays[Mesh.ARRAY_INDEX]
  if indices==null or indices.is_empty():indices=range(vertices.size())
  var edges={};var skin_points={}
  for vertex in vertices:skin_points[vertex.snapped(Vector3.ONE*.000001)]=true
  for i in range(0,indices.size(),3):
   var a=vertices[indices[i]];var b=vertices[indices[i+1]];var c=vertices[indices[i+2]]
   var normal=(c-a).cross(b-a)
   assert(normal.length()>.0000001,"No collapsed head triangles")
   assert(normal.normalized().dot((a+b+c)/3)>0,"Skin triangles point outward, including jaw and crown caps")
   for j in range(3):
    var x=str(vertices[indices[i+j]].snapped(Vector3.ONE*.000001));var y=str(vertices[indices[i+(j+1)%3]].snapped(Vector3.ONE*.000001))
    var edge=x+":"+y if x<y else y+":"+x;edges[edge]=edges.get(edge,0)+1
  for count in edges.values():assert(count==2,"Head is closed with no open jaw or scalp edges")
  assert(mesh.get_aabb().size.is_equal_approx(Vector3(.29,.38,mesh.get_aabb().size.z)),"Head keeps its original hair/ear attachment envelope")
  assert(Head.width(1,shape)<Head.RINGS[4][1]*.8,"Jaw narrows beneath the cheekbone")
  assert(Head.point(3,24,shape).z<-.15,"Nose is integrated into the skin rather than a floating primitive")
  for index in range(8):
   var decal=Head.features(index,shape);assert(decal==Head.features(index,shape),"Feature mesh is cached per atlas variant")
   var data=decal.surface_get_arrays(0);var points=data[Mesh.ARRAY_VERTEX];var uv=data[Mesh.ARRAY_TEX_UV]
   for i in range(points.size()):
    assert(skin_points.has((points[i]+Vector3(0,0,.003)).snapped(Vector3.ONE*.000001)),"Every decal vertex lies exactly 3 mm in front of a skin vertex")
    assert(uv[i].x>=index%4*.25-.00001 and uv[i].x<=(index%4+1)*.25+.00001 and uv[i].y>=index/4*.5-.00001 and uv[i].y<=(index/4+1)*.5+.00001,"Feature UVs stay within their assigned face cell")
  shape_signatures[str(vertices).sha256_text()]=true
 assert(shape_signatures.size()==4,"Each jaw/nose profile has different actual skin geometry")
 assert(Head.mesh("unknown")==Head.mesh("tapered") and Head.features(0,"unknown")==Head.features(0,"tapered"),"Unknown art profiles retain the existing fitted fallback")
 var painter=Fighters.new();var image=painter.face_atlas.get_image();assert(image.get_width()==image.get_height()*2)
 var coverage=[0,0,0,0,0,0,0,0]
 for y in range(image.get_height()):
  for x in range(image.get_width()):
   var color=image.get_pixel(x,y)
   if color.a<.22:continue
   var u=float(x)/image.get_width()*4;var v=float(y)/image.get_height()*2
   assert(fposmod(u,1)>.03 and fposmod(u,1)<.97 and fposmod(v,1)>.03 and fposmod(v,1)<.97,"Painted features never touch an adjacent atlas cell")
   assert(not (color.r>.70 and color.g<.24 and color.b<.24) and not (color.r>.78 and color.g>.66 and color.b<.20),"No visible red/yellow alpha-mask fringes")
   coverage[int(v)*4+int(u)]+=1
 for count in coverage:assert(count>1000,"Every feature variant contains visible artwork")
 var game=Rules.new();var stage=Node3D.new();root.add_child(stage);painter.batching_enabled=false
 var fringes={};var shapes={};var fringe_actors=0
 for source in game.roster:
  var unit=source.duplicate(true);unit.team="player"
  var actor=painter.build(stage,unit,Vector3.ZERO)
  var head_shape=painter.profiles[unit.id].appearance.face_shape
  assert(actor.bones.Head.get_meta("face_shape")==head_shape and actor.bones.Head.get_node("SculptedHead").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==Head.mesh(head_shape).surface_get_arrays(0)[Mesh.ARRAY_VERTEX],"Recruit binds its selected sculpted jaw and nose")
  var face=actor.find_child("PaintedFace",true,false)
  assert(face.mesh==Head.features(actor.bones.Head.get_meta("face_variant"),head_shape),"Recruit expression surface matches its personal head mesh")
  assert(face!=null and face.material_override.get_shader_parameter("open_face")==painter.face_atlas,"Every recruit uses the fitted original feature atlas")
  var head=actor.bones.Head;var locks=head.get_children().filter(func(child):return str(child.name).begins_with("Fringe"))
  if not locks.is_empty():
   fringe_actors+=1;var signature="";var style=head.get_meta("hair_fringe");fringes[style]=true
   assert(locks.size()==7,"Each front retains seven material-batched locks")
   assert(style==painter.profiles[unit.id].appearance.hair_fringe,"Recruit portrait profile chooses its own hair front")
   for lock in locks:
    var points=lock.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    for point in points:
     assert(absf(point.x)<.21 and point.y>-.1 and point.y<.25 and absf(point.z)<.20,"Front strands remain in their tested head envelope")
     signature+=str(point.snapped(Vector3.ONE*.00001))
    for i in range(0,points.size(),3):
     assert((points[i+1]-points[i]).cross(points[i+2]-points[i]).length()>.000000001,"Smoothed hair tubes contain no collapsed triangles")
     for x in [-.085,-.055,-.025,.025,.055,.085]:
      var hit=Geometry3D.ray_intersects_triangle(Vector3(x,.025,-.3),Vector3.BACK,points[i],points[i+1],points[i+2])
      assert(hit==null or hit.z>-.14,"Front locks leave both eyes visible from the front")
   if not shapes.has(style):shapes[style]=signature.sha256_text()
   else:assert(shapes[style]==signature.sha256_text(),"Matching styles retain deterministic geometry independent of recruit color")
  else:assert(head.get_meta("hair_style") in ["bald","curls"],"Bald and curly silhouettes retain their distinct builders")
  actor.queue_free();await process_frame
 assert(fringe_actors==21 and fringes.size()==5,"All eligible recruits use five distinct front silhouettes")
 var distinct={}
 for signature in shapes.values():distinct[signature]=true
 assert(distinct.size()==5,"Front styles differ in actual geometry rather than names or colors")
 stage.queue_free();await process_frame
 print("PASS: four closed sculpted head profiles / 32 fitted face variants, outward jaw/crown, integrated nose, eight fitted decal UV regions, clean original alpha all 24 recruit bindings, five smoothed hair fronts, eye clearance and deterministic 21-recruit selection")
 quit()
