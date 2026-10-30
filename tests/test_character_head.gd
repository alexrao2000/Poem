extends SceneTree
## Validate the actual skin/decal topology, UV isolation and imported alpha.
## The overlay must reuse skin triangles rather than intersect a new curvature.
const Head=preload("res://scripts/character_head.gd")
const Fighters=preload("res://scripts/fighters.gd")
const Rules=preload("res://scripts/rules.gd")
func _initialize():call_deferred("run")
func run():
 var mesh=Head.mesh();assert(mesh==Head.mesh(),"Head geometry is shared")
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
 assert(Head.RINGS[1][1]<Head.RINGS[4][1]*.65,"Jaw narrows beneath the cheekbone")
 assert(Head.point(3,24).z<-.15,"Nose is integrated into the skin rather than a floating primitive")
 for index in range(8):
  var decal=Head.features(index);assert(decal==Head.features(index),"Feature mesh is cached per atlas variant")
  var data=decal.surface_get_arrays(0);var points=data[Mesh.ARRAY_VERTEX];var uv=data[Mesh.ARRAY_TEX_UV]
  for i in range(points.size()):
   assert(skin_points.has((points[i]+Vector3(0,0,.003)).snapped(Vector3.ONE*.000001)),"Every decal vertex lies exactly 3 mm in front of a skin vertex")
   assert(uv[i].x>=index%4*.25-.00001 and uv[i].x<=(index%4+1)*.25+.00001 and uv[i].y>=index/4*.5-.00001 and uv[i].y<=(index/4+1)*.5+.00001,"Feature UVs stay within their assigned face cell")
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
 for source in game.roster:
  var unit=source.duplicate(true);unit.team="player"
  var actor=painter.build(stage,unit,Vector3.ZERO)
  assert(actor.bone("Head").find_child("SculptedHead",false,false)!=null)
  var face=actor.find_child("PaintedFace",true,false)
  assert(face!=null and face.material_override.get_shader_parameter("open_face")==painter.face_atlas,"Every recruit uses the fitted original feature atlas")
  actor.queue_free();await process_frame
 stage.queue_free();await process_frame
 print("PASS: closed sculpted head topology, outward jaw/crown, integrated nose, eight fitted decal UV regions, clean original alpha and all 24 recruit bindings")
 quit()
