extends RefCounted
# A closed forged knee shell follows the rounded greave without intersecting
# its visible face. The central ridge and tapered lower tip are shared geometry.

static var cached: ArrayMesh
static func mesh() -> ArrayMesh:
 if cached!=null:return cached
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var front=[];var back=[]
 for column in range(9):
  var x=-.1+column*.025;var extent=absf(x)
  var top=.11 if extent<=.06 else lerpf(.11,.045,(extent-.06)/.04)
  var bottom=lerpf(-.11,-.078,extent/.055) if extent<=.055 else lerpf(-.078,-.015,(extent-.055)/.045)
  for row in range(3):
   var y=lerpf(bottom,top,row*.5)
   var z=.02-sqrt(.105*.105-x*x)-(.008 if row==1 else 0.0)
   front.append(Vector3(x,y,z));back.append(Vector3(x,y,z+.018))
 for column in range(8):
  for row in range(2):
   var a=column*3+row;var b=(column+1)*3+row
   quad(surface,front[a],front[b],front[b+1],front[a+1],Vector3.FORWARD)
   quad(surface,back[a],back[b],back[b+1],back[a+1],Vector3.BACK)
 var rim=[]
 for column in range(9):rim.append(column*3)
 rim.append(25)
 for column in range(8,-1,-1):rim.append(column*3+2)
 rim.append(1)
 for i in range(rim.size()):
  var a=rim[i];var b=rim[(i+1)%rim.size()]
  var outward=Vector3(front[a].x+front[b].x,front[a].y+front[b].y,0).normalized()
  quad(surface,front[a],front[b],back[b],back[a],outward)
 surface.index();cached=surface.commit();return cached

static func quad(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,outward: Vector3):
 face(surface,a,b,c,outward);face(surface,a,c,d,outward)

static func face(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,outward: Vector3):
 var normal=(c-a).cross(b-a).normalized()
 if normal.dot(outward)<0:
  var temporary=b;b=c;c=temporary;normal=-normal
 for point in [a,b,c]:
  surface.set_normal(normal);surface.set_uv(Vector2(.5+point.x/.2,.5-point.y/.22));surface.add_vertex(point)
