extends RefCounted
## Shared original head topology: a tapered chin, cheek plane, brow and small
## integrated nose. Feature decals reuse its exact front triangles, preventing
## the texture from intersecting a differently curved skin surface.
const SIDES=32
const RINGS=[[-.178,.042,.042,-.025],[-.15,.085,.078,-.012],[-.105,.119,.112,-.004],[-.045,.141,.135,0.0],[.02,.145,.143,0.0],[.085,.140,.144,.005],[.145,.113,.113,.010],[.18,.055,.058,.010]]
static var skin: ArrayMesh
static var decals={}
static var front_triangles=[]

static func point(row: int,side: int) -> Vector3:
 var ring=RINGS[row];var angle=float(side)*TAU/SIDES
 var x=cos(angle)*ring[1];var z=sin(angle)*ring[2]+ring[3]
 if side>SIDES/2 and side<SIDES:
  z=-ring[2]*sqrt(maxf(0,1-pow(absf(cos(angle)),2.6)))+ring[3]
  z-=.025*exp(-pow(x/.024,2)-pow((ring[0]+.035)/.045,2))
 return Vector3(x,ring[0],z)

static func uv(point_value: Vector3) -> Vector2:
 var width=0.0
 for ring in RINGS:
  if is_equal_approx(point_value.y,ring[0]):width=ring[1];break
 return Vector2(.5 if width==0 else .5+point_value.x/width*.5,(.19-point_value.y)/.38)

static func triangle(surface: SurfaceTool,points: Array,is_front: bool):
 for vertex in points:surface.set_uv(uv(vertex));surface.add_vertex(vertex)
 if is_front:front_triangles.append(points)

static func mesh() -> ArrayMesh:
 if skin!=null:return skin
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 front_triangles.clear()
 for side in range(SIDES):
  var front=side>=SIDES/2
  triangle(surface,[Vector3(0,-.19,-.025),point(0,side+1),point(0,side)],front)
  for row in range(RINGS.size()-1):
   var a=point(row,side);var b=point(row,side+1);var c=point(row+1,side+1);var d=point(row+1,side)
   triangle(surface,[a,b,c],front);triangle(surface,[a,c,d],front)
  triangle(surface,[Vector3(0,.19,.01),point(RINGS.size()-1,side),point(RINGS.size()-1,side+1)],front)
 surface.generate_normals();surface.generate_tangents();surface.index();skin=surface.commit();return skin

static func features(index: int) -> ArrayMesh:
 if decals.has(index):return decals[index]
 mesh()
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for points in front_triangles:
  for vertex in points:
   var local_uv=uv(vertex)
   surface.set_uv(Vector2((index%4+local_uv.x)*.25,(index/4+local_uv.y)*.5))
   surface.add_vertex(vertex+Vector3(0,0,-.003))
 surface.generate_normals();decals[index]=surface.commit();return decals[index]
