extends RefCounted
# Closed original beard shells frame the painted mouth. Two jaw silhouettes
# share cheek attachments and a real opening instead of covering the lips.

const OUTER=[Vector2(0,-.078),Vector2(.065,-.06),Vector2(.115,-.035),Vector2(.14,-.095),Vector2(.12,-.165),Vector2(.07,-.215),Vector2(0,-.25),Vector2(-.07,-.215),Vector2(-.12,-.165),Vector2(-.14,-.095),Vector2(-.115,-.035),Vector2(-.065,-.06)]
const INNER=[Vector2(0,-.097),Vector2(.025,-.098),Vector2(.045,-.103),Vector2(.05,-.115),Vector2(.042,-.128),Vector2(.024,-.134),Vector2(0,-.136),Vector2(-.024,-.134),Vector2(-.042,-.128),Vector2(-.05,-.115),Vector2(-.045,-.103),Vector2(-.025,-.098)]
static var shapes={}

static func surface_point(point: Vector2) -> Vector3:
 return Vector3(point.x,point.y,-.166+2.2*point.x*point.x-maxf(0,-point.y-.17)*.10)

static func quad(surface: SurfaceTool,points: Array,normal: Vector3):
 var indices=[0,1,2,0,2,3]
 if (points[2]-points[0]).cross(points[1]-points[0]).dot(normal)<0:indices=[0,2,1,0,3,2]
 for index in indices:
  var point=points[index];surface.set_uv(Vector2(point.x/.32+.5,(-point.y-.02)/.4));surface.add_vertex(point)

static func mesh(style="full") -> ArrayMesh:
 style="long" if style=="long" else "full"
 if shapes.has(style):return shapes[style]
 var outer=[];var inner=[];var middle=[]
 for i in range(OUTER.size()):
  var point=OUTER[i]
  if style=="long" and point.y<-.14:point.y-=(-point.y-.14)/.11*.12
  outer.append(surface_point(point));inner.append(surface_point(INNER[i]))
  middle.append(outer[-1].lerp(inner[-1],.5)+Vector3(0,0,-.012))
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(outer.size()):
  var j=(i+1)%outer.size();var depth=Vector3(0,0,.04)
  surface.set_smooth_group(0)
  quad(surface,[outer[i],outer[j],middle[j],middle[i]],Vector3.FORWARD)
  quad(surface,[middle[i],middle[j],inner[j],inner[i]],Vector3.FORWARD)
  surface.set_smooth_group(1)
  quad(surface,[outer[i]+depth,outer[j]+depth,inner[j]+depth,inner[i]+depth],Vector3.BACK)
  var center=(outer[i]+outer[j])*.5-Vector3(0,-.115,0);center.z=0
  surface.set_smooth_group(2)
  quad(surface,[outer[i],outer[j],outer[j]+depth,outer[i]+depth],center)
  center=Vector3(0,-.115,0)-(inner[i]+inner[j])*.5;center.z=0
  surface.set_smooth_group(3)
  quad(surface,[inner[i],inner[j],inner[j]+depth,inner[i]+depth],center)
 surface.generate_normals();surface.generate_tangents();surface.index();shapes[style]=surface.commit();return shapes[style]
