extends RefCounted
# Original tapered leather boot with a defined sole and ankle collar.
# Support uses the same cached vertices as the visible mesh, including under
# tilted combat poses; no collision bodies or additional rendering materials.

const FOOTPRINT=[Vector2(0,-.145),Vector2(.055,-.13),Vector2(.09,-.06),Vector2(.075,.08),Vector2(.05,.145),Vector2(0,.145),Vector2(-.05,.145),Vector2(-.075,.08),Vector2(-.09,-.06),Vector2(-.055,-.13)]
static var shape: ArrayMesh
static var corners=PackedVector3Array()

static func triangle(surface: SurfaceTool,points: Array,uvs: Array,outward: Vector3):
 var order=[0,1,2]
 if (points[2]-points[0]).cross(points[1]-points[0]).dot(outward)<0:order=[0,2,1]
 for index in order:surface.set_uv(uvs[index]);surface.add_vertex(points[index])

static func mesh() -> ArrayMesh:
 if shape!=null:return shape
 var rings=[]
 for row in range(4):
  var ring=[]
  for point in FOOTPRINT:
   var vertex=Vector3(point.x,-.075,point.y)
   if row==1:vertex=Vector3(point.x*.98,-.05,point.y*.98)
   elif row==2:vertex=Vector3(point.x*.85,.015,point.y*.85+.015)
   elif row==3:vertex=Vector3(point.x*.61,.075,point.y*.4+.028)
   ring.append(vertex);corners.append(vertex)
  rings.append(ring)
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in range(3):
  surface.set_smooth_group(1 if row==0 else 0)
  for i in range(FOOTPRINT.size()):
   var j=(i+1)%FOOTPRINT.size();var a=rings[row][i];var b=rings[row][j];var c=rings[row+1][j];var d=rings[row+1][i]
   var center=(a+b+c+d)*.25;center.y=0
   triangle(surface,[a,b,c],[Vector2.ZERO,Vector2.RIGHT,Vector2.ONE],center)
   triangle(surface,[a,c,d],[Vector2.ZERO,Vector2.ONE,Vector2.DOWN],center)
 for row in [0,3]:
  surface.set_smooth_group(row+2)
  var center=Vector3(0,-.075,0) if row==0 else Vector3(0,.075,.028)
  for i in range(FOOTPRINT.size()):
   var a=rings[row][i];var b=rings[row][(i+1)%FOOTPRINT.size()]
   triangle(surface,[center,a,b],[Vector2(.5,.5),Vector2(a.x/.18+.5,a.z/.29+.5),Vector2(b.x/.18+.5,b.z/.29+.5)],Vector3.DOWN if row==0 else Vector3.UP)
 surface.generate_normals();surface.generate_tangents();surface.index();shape=surface.commit();return shape

static func support(rotation: Basis) -> Vector3:
 mesh()
 var lowest=Vector3(0,INF,0)
 for corner in corners:
  var point=rotation*corner
  if point.y<lowest.y:lowest=point
 return lowest
