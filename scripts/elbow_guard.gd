extends RefCounted
# A closed forged elbow cup tapers into the sleeve and bracer, with a rear
# point and lateral wings replacing the exposed round metal joint.

const SIDES=12
const SECTIONS=[[.075,.045,-.045,.045],[.032,.078,-.074,.080],[-.012,.092,-.078,.115],[-.060,.076,-.070,.085],[-.105,.054,-.052,.055]]
static var cached: ArrayMesh

static func center(row: int) -> Vector3:
 var section=SECTIONS[row];return Vector3(0,section[0],(section[2]+section[3])*.5)

static func point(row: int,side: int) -> Vector3:
 var section=SECTIONS[row];var angle=(side%SIDES)*TAU/SIDES
 return center(row)+Vector3(cos(angle)*section[1],0,sin(angle)*(section[3]-section[2])*.5)

static func triangle(surface: SurfaceTool,points: Array,uv: Array,outward: Vector3):
 var order=[0,1,2]
 if (points[2]-points[0]).cross(points[1]-points[0]).dot(outward)<0:order.reverse()
 var normal=(points[order[2]]-points[order[0]]).cross(points[order[1]]-points[order[0]]).normalized()
 for index in order:surface.set_normal(normal);surface.set_uv(uv[index]);surface.add_vertex(points[index])

static func mesh() -> ArrayMesh:
 if cached!=null:return cached
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for side in range(SIDES):
  triangle(surface,[center(0),point(0,side),point(0,side+1)],[Vector2(.5,.5),Vector2(0,0),Vector2(1,0)],Vector3.UP)
  for row in range(SECTIONS.size()-1):
   var a=point(row,side);var b=point(row,side+1);var c=point(row+1,side+1);var d=point(row+1,side)
   var u=float(side)/SIDES;var next_u=float(side+1)/SIDES;var v=row/4.0;var next_v=(row+1)/4.0
   var outward=(a+b+c+d)*.25-(center(row)+center(row+1))*.5
   triangle(surface,[a,b,c],[Vector2(u,v),Vector2(next_u,v),Vector2(next_u,next_v)],outward)
   triangle(surface,[a,c,d],[Vector2(u,v),Vector2(next_u,next_v),Vector2(u,next_v)],outward)
  triangle(surface,[center(4),point(4,side),point(4,side+1)],[Vector2(.5,.5),Vector2(0,1),Vector2(1,1)],Vector3.DOWN)
 cached=surface.commit();return cached
