extends RefCounted
## Broken courses leave a low foundation and two chipped piers.
const Masonry=preload("res://scripts/fortification.gd")
const OUTLINE=[
 Vector2(-.70,-1),Vector2(.73,-1),Vector2(1,-.70),Vector2(1,.70),
 Vector2(.72,1),Vector2(-.75,1),Vector2(-1,.68),Vector2(-1,-.73),
]
const COURSES=[
 {"position":Vector3(.59,0,0),"size":Vector2(.82,.26),"height":.13,"chips":.014},
 {"position":Vector3(0,.11,.02),"size":Vector2(.22,.22),"height":.20,"chips":.012},
 {"position":Vector3(-.014,.29,.012),"size":Vector2(.19,.19),"height":.20,"chips":.014},
 {"position":Vector3(.004,.47,0),"size":Vector2(.18,.18),"height":.18,"chips":.011},
 {"position":Vector3(-.01,.63,.012),"size":Vector2(.17,.17),"height":.19,"chips":.06},
 {"position":Vector3(.61,.11,0),"size":Vector2(.21,.21),"height":.17,"chips":.015},
 {"position":Vector3(.64,.26,.016),"size":Vector2(.18,.165),"height":.18,"chips":.065},
 {"position":Vector3(1.17,.11,.013),"size":Vector2(.24,.23),"height":.21,"chips":.014},
 {"position":Vector3(1.16,.30,.012),"size":Vector2(.19,.19),"height":.20,"chips":.015},
 {"position":Vector3(1.18,.48,.002),"size":Vector2(.19,.18),"height":.19,"chips":.018},
 {"position":Vector3(1.17,.65,.012),"size":Vector2(.18,.17),"height":.19,"chips":.024},
 {"position":Vector3(1.16,.82,.004),"size":Vector2(.16,.175),"height":.22,"chips":.079},
 {"position":Vector3(.36,.10,.09),"size":Vector2(.105,.145),"height":.135,"chips":.040},
 {"position":Vector3(.88,.11,-.098),"size":Vector2(.095,.145),"height":.13,"chips":.055},
]
static var geometry: ArrayMesh

static func mesh() -> ArrayMesh:
 if geometry!=null:return geometry
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for index in COURSES.size():
  var course=COURSES[index]
  var stone=Color("96998c").lerp(Color("b3ae9c"),float((index*3)%7)/6.0)
  add_course(tool,course.position,course.size,course.height,course.chips,stone,index)
 geometry=tool.commit();return geometry

static func add_course(tool: SurfaceTool,position: Vector3,half: Vector2,height: float,chips: float,paint: Color,index: int):
 var lower: Array[Vector3]=[];var upper: Array[Vector3]=[]
 for vertex in OUTLINE.size():
  var offset=OUTLINE[vertex]*half
  var foot=position+Vector3(offset.x,0,offset.y)
  var chip=float((vertex*3+index*5)%8)/7.0
  lower.append(foot);upper.append(foot+Vector3.UP*(height-chips*chip))
 var crown=position+Vector3.UP*(height-chips*.5)
 for edge in OUTLINE.size():
  var next=(edge+1)%OUTLINE.size()
  var length=lower[next]-lower[edge]
  var side=Vector3(length.z,0,-length.x).normalized()
  Masonry.quad(tool,[lower[edge],lower[next],upper[next],upper[edge]],side,paint.darkened(.06 if edge%2 else .13))
  var facet=(upper[edge]-crown).cross(upper[next]-crown).normalized()
  if facet.y<0:facet=-facet
  Masonry.triangle(tool,crown,upper[edge],upper[next],facet,paint.lightened(float(edge%3)*.036))
  Masonry.triangle(tool,position,lower[edge],lower[next],Vector3.DOWN,paint.darkened(.22))
