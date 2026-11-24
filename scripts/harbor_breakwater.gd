extends RefCounted
## Two low stone arms leave an open approach beyond the playable harbor.

const MAP_SITE=Vector3(7,-.12,12.35)
const MAP_SCALE=.43
const ARENA_SITE=Vector3(-8.25,0,-20)
const PATHS=[
 [Vector2(-23,-4.2),Vector2(-12,-2.5),Vector2(-7,-.4),Vector2(-4,1.2)],
 [Vector2(4,1.8),Vector2(10,-.2),Vector2(16,-2.8),Vector2(23,-4.8)],
]
const PROFILE=[Vector2(-1.18,-.37),Vector2(-.74,.48),Vector2(-.43,.74),
 Vector2(.43,.74),Vector2(.74,.48),Vector2(1.18,-.37)]
const SHADES=[Color("606970"),Color("747a77"),Color("888981"),
 Color("727875"),Color("5c666c"),Color("505c64")]

static var stone_mesh: ArrayMesh

static func build(scenery,parent: Node3D,site: Vector3,size: float,heading: float):
 var wall=scenery.mesh(parent,shape(),site,Vector3.ONE*size,preload("res://scripts/trail_lanterns.gd").paint())
 wall.name="HarborBreakwater";wall.rotation.y=heading
 wall.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 wall.set_meta("static_batch",true)

static func shape() -> ArrayMesh:
 if stone_mesh!=null:return stone_mesh
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for shore in PATHS:
  var path=sample(shore)
  var rings=[]
  for index in path.size():
   var before=path[maxi(0,index-1)];var after=path[mini(path.size()-1,index+1)]
   var forward=(after-before).normalized()
   var across=Vector3(-forward.y,0,forward.x)
   var point=Vector3(path[index].x,0,path[index].y)
   var end=index==0 or index==path.size()-1
   var width=.86+sin(index*2.73)*.075 if not end else .68
   var lift=sin(index*1.66)*.085 if not end else -.10
   var ring=[]
   for vertex in PROFILE:
    ring.append(point+across*vertex.x*width+Vector3.UP*(vertex.y+lift))
   rings.append(ring)
  for index in range(rings.size()-1):
   var first=rings[index];var next=rings[index+1]
   var middle=Vector3((path[index].x+path[index+1].x)*.5,.22,(path[index].y+path[index+1].y)*.5)
   for band in PROFILE.size():
    var edge=(band+1)%PROFILE.size()
    var paint=SHADES[band].lightened(float((index*5+band*3)%9)*.013)
    face(tool,first[band],next[band],next[edge],middle,paint)
    face(tool,first[band],next[edge],first[edge],middle,paint)
  for end in [0,rings.size()-1]:
   var ring=rings[end]
   var inward=path[1] if end==0 else path[end-1]
   var middle=Vector3(inward.x,.2,inward.y)
   for band in range(1,PROFILE.size()-1):face(tool,ring[0],ring[band],ring[band+1],middle,SHADES[1])
 stone_mesh=tool.commit()
 return stone_mesh

static func sample(shore: Array) -> PackedVector2Array:
 var path=PackedVector2Array()
 for step in range(shore.size()-1):
  var first: Vector2=shore[step];var last: Vector2=shore[step+1]
  var count=ceili(first.distance_to(last)/1.6)
  for segment in count:path.append(first.lerp(last,float(segment)/count))
 path.append(shore[-1])
 return path

static func face(tool: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,inside: Vector3,paint: Color):
 var normal=(c-a).cross(b-a).normalized()
 var reverse=normal.dot((a+b+c)/3.0-inside)<0
 for point in ([a,c,b] if reverse else [a,b,c]):
  tool.set_normal(-normal if reverse else normal)
  tool.set_color(paint)
  tool.add_vertex(point)
