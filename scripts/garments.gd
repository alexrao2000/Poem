extends RefCounted
## A lightweight open-front robe replaces the rigid cone with tapered folds.
## Shared geometry follows the existing body joint; it adds no physics or rig.
const SEGMENTS=32
const ROWS=[0.0,.30,.65,1.0]
static var fabric: ArrayMesh
static var border: ArrayMesh

static func point(t: float,u: float) -> Vector3:
 var gap=.58*smoothstep(.25,1.0,t)
 var angle=-PI*.5+gap+u*(TAU-gap*2)
 var fold=sin(u*TAU*8+PI*.25)*.014*t
 return Vector3(cos(angle)*(.18+.11*t+fold),-.125-.84*t+pow(t,6)*(.016+.016*cos(angle*4)),sin(angle)*(.145+.10*t+fold*.7))

static func robe() -> ArrayMesh:
 if fabric!=null:return fabric
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in range(ROWS.size()-1):
  for segment in range(SEGMENTS):
   var points=[];var uvs=[]
   for corner in [[row,segment],[row,segment+1],[row+1,segment+1],[row+1,segment]]:
    var t=ROWS[corner[0]];var u=float(corner[1])/SEGMENTS
    points.append(point(t,u));uvs.append(Vector2(u,t))
   for index in [0,2,1,0,3,2]:surface.set_uv(uvs[index]);surface.add_vertex(points[index])
 surface.generate_normals();fabric=surface.commit();return fabric

static func hem() -> ArrayMesh:
 if border!=null:return border
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for segment in range(SEGMENTS):
  var points=[];var uvs=[]
  for corner in [[.965,segment],[.965,segment+1],[1.0,segment+1],[1.0,segment]]:
   var u=float(corner[1])/SEGMENTS;var value=point(corner[0],u)
   value.x*=1.015;value.z*=1.015;points.append(value);uvs.append(Vector2(u,(corner[0]-.965)/.035))
  for index in [0,2,1,0,3,2]:surface.set_uv(uvs[index]);surface.add_vertex(points[index])
 surface.generate_normals();border=surface.commit();return border

static func build(painter,parent,color,gold):
 var cloth=painter.geo.mesh(parent,robe(),Vector3.ZERO,Vector3.ONE,painter.geo.material(color));cloth.name="TailoredRobe"
 var trim=painter.geo.mesh(parent,hem(),Vector3.ZERO,Vector3.ONE,painter.geo.material(gold));trim.name="RobeHem"
