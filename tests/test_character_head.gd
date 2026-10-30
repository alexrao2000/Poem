extends SceneTree
## Validate the actual skin/decal topology, UV isolation and imported alpha.
## The overlay must reuse skin triangles rather than intersect a new curvature.
const Head=preload("res://scripts/character_head.gd")
const Fighters=preload("res://scripts/fighters.gd")
const Rules=preload("res://scripts/rules.gd")
func _initialize():call_deferred("run")
func run():
 verify_beards()
 await verify_helmets()
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
  if unit.id in ["dax","galen","hale"]:
   var expected=preload("res://scripts/character_beard.gd").mesh(painter.profiles[unit.id].appearance.beard_style)
   var beard=actor.bones.Head.get_node("Beard")
   assert(beard.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==expected.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],"Beard retains its portrait-specific shell and head attachment through outline preparation")
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
 print("PASS: four closed sculpted head profiles / 32 fitted face variants, outward jaw/crown, integrated nose, eight fitted decal UV regions, clean original alpha all 24 recruit bindings, two closed mouth-framing beards, fitted hollow knight helmets / recessed eye slits / closed nasal trim, five smoothed hair fronts, eye clearance and deterministic 21-recruit selection")
 quit()

func verify_beards():
 var Beard=preload("res://scripts/character_beard.gd")
 for style in ["full","long"]:
  var mesh=Beard.mesh(style);assert(mesh==Beard.mesh(style),"Beard source geometry is shared")
  var arrays=mesh.surface_get_arrays(0);var vertices=arrays[Mesh.ARRAY_VERTEX];var indices=arrays[Mesh.ARRAY_INDEX];var normals=arrays[Mesh.ARRAY_NORMAL];var edges={};var directions={}
  assert(indices.size()==360,"Beard relief, rear and opening walls use 120 triangles")
  for i in range(0,indices.size(),3):
   var a=vertices[indices[i]];var b=vertices[indices[i+1]];var c=vertices[indices[i+2]]
   var normal=(c-a).cross(b-a)
   assert(normal.length()>.00000001,"Closed beard faces contain no collapsed triangles")
   for corner in range(3):
    var shading=normals[indices[i+corner]]
    assert(is_equal_approx(shading.length(),1.0) and normal.normalized().dot(shading)>0,"Smooth beard normals stay in their actual triangle's outward hemisphere, including mouth-rim creases")
   for direction in [-1,1]:
    var ray=Vector3(sin(.58)*direction,0,cos(.58));var origin=Vector3(0,-.115,-.12)-ray*.4
    var hit=Geometry3D.ray_intersects_triangle(origin,ray,a,b,c)
    assert(hit==null or hit.distance_to(origin)>.4,"The mouth center remains unobstructed from both oblique combat angles")
   for j in range(3):
    var start=str(vertices[indices[i+j]].snapped(Vector3.ONE*.000001));var end=str(vertices[indices[i+(j+1)%3]].snapped(Vector3.ONE*.000001))
    var edge=start+":"+end if start<end else end+":"+start
    edges[edge]=edges.get(edge,0)+1;directions[edge]=directions.get(edge,0)+(1 if start<end else -1)
   for x in [-.02,0,.02]:
    for y in [-.105,-.115,-.125]:
     assert(Geometry3D.ray_intersects_triangle(Vector3(x,y,-.4),Vector3.BACK,a,b,c)==null,"Actual beard shell leaves the painted lips visible through its mouth opening")
   assert(Geometry3D.ray_intersects_triangle(Vector3(0,-.055,-.4),Vector3.BACK,a,b,c)==null,"Beard does not cover the integrated nose")
  for edge in edges:assert(edges[edge]==2 and directions[edge]==0,"Beard body and mouth walls form a closed consistently oriented surface")
  assert(is_equal_approx(mesh.get_aabb().position.y,-.37 if style=="long" else -.25),"Galen's longer beard has a distinct lower silhouette")
 assert(Beard.mesh("unknown")==Beard.mesh("full"),"Unspecified enemy beards use the short fitted shell")

func verify_helmets():
 var Helmet=preload("res://scripts/knight_helmet.gd")
 assert(Helmet.mesh()==Helmet.mesh() and Helmet.nasal_trim()==Helmet.nasal_trim() and Helmet.visor_lining()==Helmet.visor_lining(),"Helmet pieces are shared immutable source meshes")
 var metal=Helmet.mesh().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 for mesh in [Helmet.mesh(),Helmet.nasal_trim()]:
  var arrays=mesh.surface_get_arrays(0);var points=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL];var edges={};var directions={}
  for i in range(0,points.size(),3):
   var normal=(points[i+2]-points[i]).cross(points[i+1]-points[i])
   assert(normal.length_squared()>1e-16,"Helmet and fitted trim omit collapsed triangles")
   for j in range(3):
    assert(is_equal_approx(normals[i+j].length(),1) and normal.normalized().dot(normals[i+j])>.999,"Faceted metal has finite outward face normals")
    var a=str(points[i+j].snapped(Vector3.ONE*.000001));var b=str(points[i+(j+1)%3].snapped(Vector3.ONE*.000001));var edge=a+":"+b if a<b else b+":"+a
    edges[edge]=edges.get(edge,0)+1;directions[edge]=directions.get(edge,0)+(1 if a<b else -1)
  for count in edges.values():assert(count==2,"Helmet wall and eye-slit rims form a closed solid")
  for value in directions.values():assert(value==0,"Shared metal edges retain opposite winding")
  for point in points:assert(absf(point.x)<=.167 and point.y>=-.19 and point.y<=.243 and point.z>=-.195 and point.z<.19,"Helmet stays within its new fitted head envelope")
 for x in [-.09,-.06,.06,.09]:
  assert(helmet_ray(metal,Vector3(x,.006,-1))>.10,"Eye opening passes through the front shell to the back wall")
  var lining=Helmet.visor_lining().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  assert(helmet_ray(lining,Vector3(x,.006,-1))<-.13,"Dark lining is recessed behind the eye opening")
  assert(helmet_ray(metal,Vector3(x,-.06,-1))<-.13,"Solid cheeks remain below the opening")
 var nose=Helmet.nasal_trim().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 assert(helmet_ray(nose,Vector3(0,.006,-1))<-.18,"Nasal trim bridges the middle of the eye slit")
 for point in nose:
  if point.y>-.018 and point.y<.03:continue
  var shell_z=helmet_ray(metal,Vector3(point.x,point.y,-1))
  if shell_z>=1:continue
  assert(shell_z-point.z>.0009,"Even the back of the fitted nose strip clears the actual curved metal surface")
 var rules=Rules.new();var painter=Fighters.new();painter.batching_enabled=false;var stage=Node3D.new();root.add_child(stage)
 var unit=rules.roster.filter(func(entry):return entry.job=="Knight")[0].duplicate(true);unit.team="enemy";unit.id="helmet_test"
 for direction in [-1,1]:
  var actor=painter.build(stage,unit,Vector3.ZERO);actor.rotation.y=direction*PI/2;actor.set_process(false)
  var head=actor.bones.Head
  assert(head.get_node("HelmetShell").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==metal,"Enemy knight binds the shaped helmet before and after outline preparation")
  assert(head.get_node("HelmetLining").material_override.next_pass==null,"Recessed lining does not grow an outline across the slit")
  assert(actor.face_blink.surface==null and not head.has_node("PaintedFace"),"Closed helmet retains the anonymous armored identity")
  for pose in ["idle","windup","strike","guard","hit","down"]:
   actor.pose(pose,1).custom_step(1)
   for key in ["HelmetShell","HelmetLining","HelmetNasal"]:
    assert(head.get_node(key).transform==Transform3D.IDENTITY,"All fitted pieces follow the same animated head without floating offsets")
  actor.queue_free();await process_frame
 stage.queue_free();await process_frame

func helmet_ray(points: PackedVector3Array,origin: Vector3) -> float:
 var nearest=1.0
 for i in range(0,points.size(),3):
  var hit=Geometry3D.ray_intersects_triangle(origin,Vector3.BACK,points[i],points[i+1],points[i+2])
  if hit!=null:nearest=minf(nearest,hit.z)
 return nearest
