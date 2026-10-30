extends RefCounted
# Original closed shoulder plates have a capped crown and a scalloped lower
# edge. Mirrored fitted rims share the other metal fittings' indexed format.

const SIDES=12
static var plates={}
static var rims={}

static func point(row: int,column: int,side: int,heavy: bool) -> Vector3:
 var sections=[[.13 if heavy else .095,.13,-.09],[.145 if heavy else .105,.14,-.04],[.16 if heavy else .11,.15,.015],[.125 if heavy else .09,.12,.075]]
 var s=sections[row];var angle=posmod(column,SIDES)*TAU/SIDES;var outward=maxf(0,cos(angle)*side)
 var drop=.065 if row==0 else .025 if row==1 else 0.0
 return Vector3(cos(angle)*s[0],s[2]-outward*drop,sin(angle)*s[1])

static func mesh(side: int,heavy: bool) -> ArrayMesh:
 var key=str(side)+str(heavy)
 if plates.has(key):return plates[key]
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in range(3):
  for column in range(SIDES):
   var a=point(row,column,side,heavy);var b=point(row,column+1,side,heavy)
   var c=point(row+1,column+1,side,heavy);var d=point(row+1,column,side,heavy)
   triangle(surface,a,b,c);triangle(surface,a,c,d)
 for top in [false,true]:
  var center=Vector3(0,.105 if top else -.09,0);var row=3 if top else 0
  for column in range(SIDES):
   var a=point(row,column,side,heavy);var b=point(row,column+1,side,heavy)
   triangle(surface,center,a,b) if top else triangle(surface,center,b,a)
 plates[key]=surface.commit();return plates[key]

static func rim(side: int,heavy: bool) -> ArrayMesh:
 var key=str(side)+str(heavy)
 if rims.has(key):return rims[key]
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for column in range(SIDES):
  var a=point(0,column,side,heavy);var b=point(0,column+1,side,heavy)
  var c=b.lerp(point(1,column+1,side,heavy),.24);var d=a.lerp(point(1,column,side,heavy),.24)
  a=outset(a);b=outset(b);c=outset(c);d=outset(d)
  triangle(surface,a,b,c);triangle(surface,a,c,d)
 var arrays=surface.commit().surface_get_arrays(0);arrays[Mesh.ARRAY_INDEX]=PackedInt32Array(range(arrays[Mesh.ARRAY_VERTEX].size()))
 var result=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);rims[key]=result;return result

static func outset(point_value: Vector3) -> Vector3:
 return point_value+Vector3(point_value.x,0,point_value.z).normalized()*.0015

static func triangle(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3):
 var normal=(c-a).cross(b-a).normalized()
 for point_value in [a,b,c]:
  surface.set_normal(normal);surface.set_uv(Vector2(atan2(point_value.z,point_value.x)/TAU+.5,(point_value.y+.18)/.3));surface.add_vertex(point_value)
