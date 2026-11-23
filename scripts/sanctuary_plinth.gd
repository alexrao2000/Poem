extends RefCounted
## A beveled stone tile with a brass ring and the sanctuary's blue diamond.

const MapSurface=preload("res://scripts/map_surface.gd")
const SIDES=12
const RINGS=[
 Vector2(.355,0),Vector2(.405,.016),Vector2(.388,.072),
 Vector2(.353,MapSurface.SANCTUARY_HEIGHT),Vector2(.316,MapSurface.SANCTUARY_HEIGHT),
 Vector2(.172,MapSurface.SANCTUARY_HEIGHT),
]
const STONE=Color("77786b")
const BANDS=[
 STONE,Color("9b9c8c"),Color("b5b49d"),Color("cfb977"),Color("4c5f62"),
]
const INLAY=[Color("85c5c2"),Color("69a7b0"),Color("508e9f"),Color("70b4ba")]
static var shape: ArrayMesh
static var paint: StandardMaterial3D

static func mesh() -> ArrayMesh:
 if shape!=null:return shape
 var surface=SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for side in SIDES:
  var next=(side+1)%SIDES
  for ring in BANDS.size():
   var a=point(ring,side);var b=point(ring,next)
   var c=point(ring+1,next);var d=point(ring+1,side)
   triangle(surface,a,b,c,BANDS[ring])
   triangle(surface,a,c,d,BANDS[ring])
  var top=RINGS.size()-1
  triangle(surface,Vector3.UP*MapSurface.SANCTUARY_HEIGHT,point(top,side),point(top,next),INLAY[floori(side/3.0)])
  triangle(surface,Vector3.ZERO,point(0,next),point(0,side),STONE)
 shape=surface.commit()
 return shape

static func point(ring: int,side: int) -> Vector3:
 var angle=side*TAU/SIDES
 var direction=Vector2(cos(angle),sin(angle))
 var radius: float=RINGS[ring].x
 if ring==RINGS.size()-1:radius/=absf(direction.x)+absf(direction.y)
 return Vector3(direction.x*radius,RINGS[ring].y,direction.y*radius)

static func triangle(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,color: Color):
 var normal=(c-a).cross(b-a).normalized()
 for vertex in [a,b,c]:
  surface.set_normal(normal)
  surface.set_color(color)
  surface.add_vertex(vertex)

static func material() -> StandardMaterial3D:
 if paint==null:
  paint=StandardMaterial3D.new()
  paint.vertex_color_use_as_albedo=true
  paint.vertex_color_is_srgb=true
  paint.roughness=.9
 return paint
