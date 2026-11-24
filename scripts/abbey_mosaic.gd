extends RefCounted

const Architecture=preload("res://scripts/architecture.gd")
const MAP_SITE=Vector3(5.5,.004,4.5)
const ARENA_SITE=Vector3(-1.25,.004,-1.5)
const ARENA_SCALE=1.65
const BLUE=Color("63727a")
const OCHRE=Color("8e785b")
const LIMESTONE=Color("a39e8e")
static var floor_inlay: ArrayMesh

static func build(scenery,parent: Node3D,site: Vector3,size: float,yaw=0.0):
 var mosaic=scenery.mesh(parent,shape(),site,Vector3.ONE*size,Architecture.material())
 mosaic.name="AbbeyFloorMosaic";mosaic.rotation.y=yaw
 mosaic.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func shape() -> ArrayMesh:
 if floor_inlay!=null:return floor_inlay
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for tile in 32:
  if tile in [6,7]:continue
  var start=tile*TAU/32+.009
  var finish=(tile+1)*TAU/32-.009
  var seam=.76+float((tile*7)%5-2)*.006
  var color=LIMESTONE.darkened(float((tile*11)%5)*.019)
  ring_tile(tool,start,finish,seam,.86,color)
  if tile!=8:ring_tile(tool,start,finish,.69,seam-.011,OCHRE.darkened(float(tile%3)*.036))
 for petal in 8:
  var bearing=petal*TAU/8
  var tip=point(.55 if petal==2 else .64,bearing)
  var inner=point(.154,bearing)
  var first=point(.28,bearing-.28);var last=point(.28,bearing+.28)
  var color=BLUE if petal%2==0 else OCHRE
  triangle(tool,inner,first,tip,color)
  triangle(tool,inner,tip,last,color.darkened(.18))
  triangle(tool,Vector3.ZERO,point(.122,bearing),point(.122,bearing+TAU/8),
   LIMESTONE.darkened(.16 if petal%2==0 else .26))
 floor_inlay=tool.commit()
 return floor_inlay

static func point(radius: float,angle: float) -> Vector3:
 return Vector3(cos(angle)*radius,0,sin(angle)*radius)

static func ring_tile(tool: SurfaceTool,start: float,finish: float,inner: float,outer: float,paint: Color):
 Architecture.quad(tool,[point(inner,start),point(outer,start),point(outer,finish),point(inner,finish)],Vector3.UP,paint)

static func triangle(tool: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,paint: Color):
 for vertex in ([a,b,c] if (b-a).cross(c-a).y<0 else [a,c,b]):
  tool.set_color(paint);tool.set_normal(Vector3.UP);tool.set_uv(Vector2(vertex.x,vertex.z)*.5+Vector2.ONE*.5)
  tool.add_vertex(vertex)
