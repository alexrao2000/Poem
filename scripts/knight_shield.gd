extends RefCounted
## Original bowed heater shield, with a separate metal rim and river crest.
const OUTLINE=[Vector2(-.19,.36),Vector2(.19,.36),Vector2(.232,.30),Vector2(.228,.03),Vector2(.18,-.19),Vector2(0,-.377),Vector2(-.18,-.19),Vector2(-.228,.03),Vector2(-.232,.30)]
static var cached_body: ArrayMesh
static var cached_trim: ArrayMesh

static func triangle(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3):
 var normal=(b-a).cross(c-a).normalized()
 for point in [a,c,b]:
  surface.set_normal(normal);surface.set_uv(Vector2(point.x+.25,.4-point.y));surface.add_vertex(point)

static func front(point: Vector2,radius=1.0,offset=0.0) -> Vector3:
 return Vector3(point.x*radius,point.y*radius,-.05+.032*radius-offset)

static func body_mesh() -> ArrayMesh:
 if cached_body!=null:return cached_body
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(OUTLINE.size()):
  var a=front(OUTLINE[i]);var b=front(OUTLINE[(i+1)%OUTLINE.size()])
  var back_a=Vector3(a.x,a.y,.025);var back_b=Vector3(b.x,b.y,.025)
  triangle(surface,Vector3(0,0,-.05),a,b)
  triangle(surface,Vector3(0,0,.025),back_b,back_a)
  triangle(surface,a,back_a,back_b);triangle(surface,a,back_b,b)
 cached_body=surface.commit();return cached_body

static func trim_mesh() -> ArrayMesh:
 if cached_trim!=null:return cached_trim
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(OUTLINE.size()):
  var a=OUTLINE[i];var b=OUTLINE[(i+1)%OUTLINE.size()]
  var outer_a=front(a,.985,.0015);var outer_b=front(b,.985,.0015)
  var inner_a=front(a,.87,.0015);var inner_b=front(b,.87,.0015)
  triangle(surface,outer_a,outer_b,inner_b);triangle(surface,outer_a,inner_b,inner_a)
 # A diamond above paired flowing chevrons: Poem's river standard.
 polygon(surface,[Vector2(0,.20),Vector2(.045,.145),Vector2(0,.09),Vector2(-.045,.145)])
 for y in [.02,-.085]:
  polygon(surface,[Vector2(-.12,y+.045),Vector2(0,y-.015),Vector2(.12,y+.045),Vector2(.10,y-.005),Vector2(0,y-.055),Vector2(-.10,y-.005)])
 cached_trim=surface.commit();return cached_trim

static func polygon(surface: SurfaceTool,points: PackedVector2Array):
 var indices=Geometry2D.triangulate_polygon(points)
 for i in range(0,indices.size(),3):
  var a=points[indices[i]];var b=points[indices[i+1]];var c=points[indices[i+2]]
  if (b-a).cross(c-a)>0:
   var swap=b;b=c;c=swap
  triangle(surface,Vector3(a.x,a.y,-.053),Vector3(b.x,b.y,-.053),Vector3(c.x,c.y,-.053))
