extends RefCounted
# A shared wooden wheel with open spoke gaps and a narrow iron tire.

const SEGMENTS=16
static var cached_mesh: ArrayMesh
static var cached_material: StandardMaterial3D

static func triangle(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,normal: Vector3,color: Color):
 var points=[a,b,c] if (b-a).cross(c-a).dot(normal)<0 else [a,c,b]
 for point in points:
  surface.set_normal(normal);surface.set_color(color);surface.set_uv(Vector2(point.x,point.z)*2+Vector2.ONE*.5);surface.add_vertex(point)

static func quad(surface: SurfaceTool,points: Array,normal: Vector3,color: Color):
 triangle(surface,points[0],points[1],points[2],normal,color)
 triangle(surface,points[0],points[2],points[3],normal,color)

static func point(angle: float,radius: float,height: float) -> Vector3:
 return Vector3(cos(angle)*radius,height,sin(angle)*radius)

static func mesh() -> ArrayMesh:
 if cached_mesh!=null:return cached_mesh
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var wood=Color("786344");var iron=Color("515a57")
 for i in range(SEGMENTS):
  var a=i*TAU/SEGMENTS;var b=(i+1)*TAU/SEGMENTS
  var outward=Vector3(cos((a+b)*.5),0,sin((a+b)*.5))
  var color=wood.lightened((i%3)*.025)
  quad(surface,[point(a,.25,-.03),point(a,.25,.03),point(b,.25,.03),point(b,.25,-.03)],outward,color)
  quad(surface,[point(b,.195,-.03),point(b,.195,.03),point(a,.195,.03),point(a,.195,-.03)],-outward,color.darkened(.08))
  quad(surface,[point(a,.195,.03),point(b,.195,.03),point(b,.25,.03),point(a,.25,.03)],Vector3.UP,color)
  quad(surface,[point(a,.25,-.03),point(b,.25,-.03),point(b,.195,-.03),point(a,.195,-.03)],Vector3.DOWN,color)
  quad(surface,[point(a,.251,-.012),point(a,.251,.012),point(b,.251,.012),point(b,.251,-.012)],outward,iron)
 var spoke=BoxMesh.new();spoke.size=Vector3(.16,.045,.028)
 var arrays=spoke.surface_get_arrays(0);var points=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL];var indices=arrays[Mesh.ARRAY_INDEX]
 for i in range(6):
  var turn=Basis(Vector3.UP,i*TAU/6)
  for index in indices:
   var vertex=turn*(points[index]+Vector3(.13,0,0))
   surface.set_normal(turn*normals[index]);surface.set_color(wood.lightened(.08));surface.set_uv(Vector2(vertex.x,vertex.z)*2+Vector2.ONE*.5);surface.add_vertex(vertex)
 cached_mesh=surface.commit();return cached_mesh

static func material() -> StandardMaterial3D:
 if cached_material!=null:return cached_material
 cached_material=StandardMaterial3D.new();cached_material.vertex_color_use_as_albedo=true;cached_material.vertex_color_is_srgb=true
 cached_material.roughness=.86
 return cached_material
