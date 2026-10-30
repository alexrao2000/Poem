extends RefCounted
# Original closed plate armor: a narrow waist, broad chest and raised central
# ridge. Four eight-point sections share one 64-triangle mesh and painted steel.
# Indexed gold bands follow the plate and share the other fittings’ batch format.

const SECTIONS=[
 [.015,.175,-.135,-.125,-.055,.050],
 [.100,.200,-.175,-.150,-.055,.055],
 [.230,.232,-.190,-.165,-.060,.060],
 [.360,.202,-.170,-.145,-.050,.040]
]
static var cached: ArrayMesh
static var cached_trim: ArrayMesh

static func ring(index: int) -> PackedVector3Array:
 var s=SECTIONS[index];var y=s[0];var w=s[1]
 return PackedVector3Array([
  Vector3(-w,y,s[4]),Vector3(-w*.65,y,s[3]),Vector3(0,y,s[2]),Vector3(w*.65,y,s[3]),
  Vector3(w,y,s[4]),Vector3(w*.8,y,s[5]),Vector3(0,y,s[5]+.015),Vector3(-w*.8,y,s[5])
 ])

static func triangle(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,uvs: Array):
 var normal=(b-a).cross(c-a).normalized();var points=[a,b,c]
 for i in [0,2,1]:
  surface.set_normal(normal);surface.set_uv(uvs[i]);surface.add_vertex(points[i])

static func mesh() -> ArrayMesh:
 if cached!=null:return cached
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in range(SECTIONS.size()-1):
  var lower=ring(row);var upper=ring(row+1)
  for side in range(8):
   var next=(side+1)%8;var u=side/8.0;var v=row/3.0;var un=(side+1)/8.0;var vn=(row+1)/3.0
   triangle(surface,lower[side],upper[next],lower[next],[Vector2(u,v),Vector2(un,vn),Vector2(un,v)])
   triangle(surface,lower[side],upper[side],upper[next],[Vector2(u,v),Vector2(u,vn),Vector2(un,vn)])
 for row in [0,3]:
  var outline=ring(row);var center=Vector3(0,SECTIONS[row][0],-.015)
  for side in range(8):
   var a=outline[side];var b=outline[(side+1)%8]
   if row==3:
    var swap=a;a=b;b=swap
   triangle(surface,center,a,b,[Vector2(.5,.5),Vector2(a.x+.5,a.z+.5),Vector2(b.x+.5,b.z+.5)])
 cached=surface.commit();return cached

static func front_point(x: float,y: float) -> Vector3:
 var points=mesh().surface_get_arrays(0)[Mesh.ARRAY_VERTEX];var nearest=INF
 for i in range(0,points.size(),3):
  var hit=Geometry3D.ray_intersects_triangle(Vector3(x,y,-1),Vector3.BACK,points[i],points[i+1],points[i+2])
  if hit!=null:nearest=minf(nearest,hit.z)
 assert(is_finite(nearest),"Authored chest ornament must remain inside the plate")
 return Vector3(x,y,nearest-.0015)

static func trim_mesh() -> ArrayMesh:
 if cached_trim!=null:return cached_trim
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var heights=[.08,.10,.15,.23,.30,.32]
 for side in [-1,1]:
  for row in range(heights.size()-1):
   var lower_y=heights[row];var upper_y=heights[row+1]
   var lower_x=side*lerpf(.066,.114,(lower_y-.08)/.24);var upper_x=side*lerpf(.066,.114,(upper_y-.08)/.24)
   var a=front_point(lower_x-.009,lower_y);var b=front_point(lower_x+.009,lower_y)
   var c=front_point(upper_x+.009,upper_y);var d=front_point(upper_x-.009,upper_y)
   triangle(surface,a,c,b,[Vector2(0,0),Vector2(1,1),Vector2(1,0)])
   triangle(surface,a,d,c,[Vector2(0,0),Vector2(0,1),Vector2(1,1)])
 var arrays=surface.commit().surface_get_arrays(0)
 arrays[Mesh.ARRAY_INDEX]=PackedInt32Array(range(arrays[Mesh.ARRAY_VERTEX].size()))
 cached_trim=ArrayMesh.new();cached_trim.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return cached_trim
