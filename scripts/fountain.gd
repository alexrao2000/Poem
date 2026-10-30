extends RefCounted
## A small tiered basin shares cached stone, water and four narrow falling jets.
const Masonry=preload("res://scripts/fortification.gd")
static var stone_mesh: ArrayMesh
static var pool_mesh: ArrayMesh
static var flow_mesh: ArrayMesh
static var flow_material: ShaderMaterial

static func stone() -> ArrayMesh:
 if stone_mesh!=null:return stone_mesh
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var profiles=[
  [Vector2(.48,.04),Vector2(.49,.10),Vector2(.45,.14),Vector2(.45,.26),Vector2(.37,.26),Vector2(.34,.18),Vector2(.34,.12),Vector2(.12,.12),Vector2(.12,.04)],
  [Vector2(.11,.10),Vector2(.12,.19),Vector2(.07,.24),Vector2(.065,.61),Vector2(.11,.64),Vector2(.11,.68),Vector2(.02,.68),Vector2(.02,.10)],
  [Vector2(.08,.63),Vector2(.13,.64),Vector2(.23,.70),Vector2(.25,.76),Vector2(.19,.78),Vector2(.17,.73),Vector2(.07,.70),Vector2(.07,.63)]
 ]
 for profile in profiles:
  for ring in range(profile.size()):
   var low=profile[ring];var high=profile[(ring+1)%profile.size()]
   for sector in range(16):
    var a=sector*TAU/16;var b=(sector+1)*TAU/16;var points=[]
    for sample in [[low,a],[low,b],[high,b],[high,a]]:
     points.append(Vector3(sample[0].x*cos(sample[1]),sample[0].y,sample[0].x*sin(sample[1])))
    var edge=high-low;var mid=(a+b)*.5
    var normal=Vector3(edge.y*cos(mid),-edge.x*cos((b-a)*.5),edge.y*sin(mid)).normalized()
    Masonry.quad(tool,points,normal,Color("a5a99d").lightened((ring+sector)%3*.025))
 stone_mesh=tool.commit();return stone_mesh

static func pools() -> ArrayMesh:
 if pool_mesh!=null:return pool_mesh
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for basin in [Vector2(.335,.175),Vector2(.165,.735)]:
  for sector in range(32):
   var a=sector*TAU/32;var b=(sector+1)*TAU/32
   for point in [Vector3(0,basin.y,0),Vector3(cos(a)*basin.x,basin.y,sin(a)*basin.x),Vector3(cos(b)*basin.x,basin.y,sin(b)*basin.x)]:
    tool.set_normal(Vector3.UP);tool.set_uv(Vector2(point.x,point.z));tool.add_vertex(point)
 tool.generate_tangents()
 pool_mesh=tool.commit();return pool_mesh

static func jet_point(t: float,angle: float) -> Vector3:
 var radius=lerpf(.237,.31,t)+sin(t*PI)*.045
 return Vector3(cos(angle)*radius,.72-.54*pow(t,1.35),sin(angle)*radius)

static func flows() -> ArrayMesh:
 if flow_mesh!=null:return flow_mesh
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for jet in range(4):
  var angle=jet*PI*.5
  for ribbon in range(2):
   var width=(Vector3(-sin(angle),0,cos(angle)) if ribbon==0 else Vector3(cos(angle),0,sin(angle)))*.009
   for segment in range(12):
    var a=segment/12.0;var b=(segment+1)/12.0
    var points=[jet_point(a,angle)-width,jet_point(a,angle)+width,jet_point(b,angle)+width,jet_point(b,angle)-width]
    var coordinates=[Vector2(0,a),Vector2(1,a),Vector2(1,b),Vector2(0,b)]
    var normal=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
    for index in [0,1,2,0,2,3]:
     tool.set_normal(normal);tool.set_uv(coordinates[index]);tool.add_vertex(points[index])
 flow_mesh=tool.commit();return flow_mesh

static func stream_material() -> ShaderMaterial:
 if flow_material==null:
  flow_material=ShaderMaterial.new();flow_material.shader=preload("res://assets/shaders/fountain-flow.gdshader")
 return flow_material

static func build(parent: Node3D,point: Vector3,water: Material):
 var group=Node3D.new();group.name="TieredFountain";group.position=point;parent.add_child(group)
 for entry in [["CarvedStone",stone(),Masonry.material()],["BasinWater",pools(),water],["FallingWater",flows(),stream_material()]]:
  var mesh=MeshInstance3D.new();mesh.name=entry[0];mesh.mesh=entry[1];mesh.material_override=entry[2];group.add_child(mesh)
  if entry[0]!="CarvedStone":mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 return group
