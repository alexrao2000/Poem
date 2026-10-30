extends RefCounted
# Cached bowed wood, inset lid and fitted iron hoops share the existing prop size.

const SIDES=12
const HEIGHTS=[0.0,.08,.20,.32,.40]
const RADII=[.143,.162,.168,.162,.143]
static var meshes={}
static var wood_material: StandardMaterial3D
static var iron_material: StandardMaterial3D

static func triangle(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,normal: Vector3,color: Color):
 var points=[a,b,c] if (b-a).cross(c-a).dot(normal)<0 else [a,c,b]
 for point in points:
  surface.set_normal(normal);surface.set_color(color);surface.set_uv(Vector2(point.x/.336+.5,point.y/.4));surface.add_vertex(point)

static func quad(surface: SurfaceTool,points: Array,normal: Vector3,color: Color):
 triangle(surface,points[0],points[1],points[2],normal,color);triangle(surface,points[0],points[2],points[3],normal,color)

static func point(angle: float,radius: float,y: float) -> Vector3:
 return Vector3(cos(angle)*radius,y,sin(angle)*radius)

static func radius_at(y: float) -> float:
 for i in range(HEIGHTS.size()-1):
  if y<=HEIGHTS[i+1]:return lerpf(RADII[i],RADII[i+1],clampf((y-HEIGHTS[i])/(HEIGHTS[i+1]-HEIGHTS[i]),0,1))
 return RADII[-1]

static func mesh(part: String) -> ArrayMesh:
 if meshes.has(part):return meshes[part]
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var wood=Color("77634a");var lid=Color("a08a66")
 if part=="wood":
  for i in range(SIDES):
   var a=i*TAU/SIDES;var b=(i+1)*TAU/SIDES;var middle=(a+b)*.5
   var color=wood.lightened((i%4)*.018)
   for row in range(4):
    var low=HEIGHTS[row];var high=HEIGHTS[row+1];var r0=RADII[row];var r1=RADII[row+1]
    var normal=Vector3(cos(middle),-(r1-r0)/(high-low),sin(middle)).normalized()
    quad(surface,[point(a,r0,low),point(a,r1,high),point(b,r1,high),point(b,r0,low)],normal,color)
   quad(surface,[point(a,.143,.4),point(a,.133,.4),point(b,.133,.4),point(b,.143,.4)],Vector3.UP,lid.darkened(.06))
   quad(surface,[point(a,.133,.4),point(a,.133,.392),point(b,.133,.392),point(b,.133,.4)],-Vector3(cos(middle),0,sin(middle)),wood.darkened(.15))
   triangle(surface,Vector3(0,.392,0),point(a,.133,.392),point(b,.133,.392),Vector3.UP,lid)
   triangle(surface,Vector3.ZERO,point(a,.143,0),point(b,.143,0),Vector3.DOWN,wood.darkened(.1))
 elif part=="hoops":
  for y in [.06,.34]:
   var low=y-.016;var high=y+.016
   for i in range(SIDES):
    var a=i*TAU/SIDES;var b=(i+1)*TAU/SIDES
    var normal=Vector3(cos((a+b)*.5),-(radius_at(high)-radius_at(low))/(high-low),sin((a+b)*.5)).normalized()
    quad(surface,[point(a,radius_at(low)+.0025,low),point(a,radius_at(high)+.0025,high),point(b,radius_at(high)+.0025,high),point(b,radius_at(low)+.0025,low)],normal,Color.WHITE)
 elif part=="lid_marks":
  for x in [-.065,0,.065]:
   var half=.003;var extent=sqrt(.132*.132-pow(absf(x)+half,2))
   quad(surface,[Vector3(x-half,.393,-extent),Vector3(x+half,.393,-extent),Vector3(x+half,.393,extent),Vector3(x-half,.393,extent)],Vector3.UP,Color("695940"))
 meshes[part]=surface.commit();return meshes[part]

static func material(iron: bool) -> StandardMaterial3D:
 if iron:
  if iron_material==null:
   iron_material=StandardMaterial3D.new();iron_material.albedo_color=Color("515754");iron_material.roughness=.7;iron_material.metallic=.35
  return iron_material
 if wood_material==null:
  wood_material=StandardMaterial3D.new();wood_material.vertex_color_use_as_albedo=true;wood_material.vertex_color_is_srgb=true;wood_material.roughness=.95
 return wood_material

static func build(parent: Node3D,position: Vector3,scale_value: float):
 var root=Node3D.new();root.name="Barrel";parent.add_child(root);root.position=position;root.scale=Vector3.ONE*scale_value
 for part in ["wood","hoops","lid_marks"]:
  var piece=MeshInstance3D.new();piece.name=part.capitalize();piece.mesh=mesh(part);piece.material_override=material(part=="hoops");root.add_child(piece)
