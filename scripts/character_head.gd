extends RefCounted
# Four original jaw/nose profiles share the scalp, ears and atlas layout.
# Feature decals reuse each shape's exact front triangles, keeping expressions
# fitted to the skin instead of intersecting a different facial surface.

const SIDES=32
const RINGS=[[-.178,.042,.042,-.025],[-.15,.085,.078,-.012],[-.105,.119,.112,-.004],[-.045,.141,.135,0.0],[.02,.145,.143,0.0],[.085,.140,.144,.005],[.145,.113,.113,.010],[.18,.055,.058,.010]]
const SHAPES={
 "tapered":{"jaw":[.042,.085,.119],"nose":.025},
 "soft":{"jaw":[.048,.090,.122],"nose":.019},
 "angular":{"jaw":[.055,.103,.125],"nose":.027},
 "broad":{"jaw":[.065,.113,.135],"nose":.027}
}
static var skins={}
static var decals={}
static var front_triangles={}

static func shape_key(shape: String) -> String:
 return shape if SHAPES.has(shape) else "tapered"

static func width(row: int,shape: String) -> float:
 return SHAPES[shape_key(shape)].jaw[row] if row<3 else RINGS[row][1]

static func point(row: int,side: int,shape="tapered") -> Vector3:
 shape=shape_key(shape)
 var ring=RINGS[row];var angle=float(side)*TAU/SIDES
 var x=cos(angle)*width(row,shape);var z=sin(angle)*ring[2]+ring[3]
 if side>SIDES/2 and side<SIDES:
  z=-ring[2]*sqrt(maxf(0,1-pow(absf(cos(angle)),2.6)))+ring[3]
  z-=SHAPES[shape].nose*exp(-pow(x/.024,2)-pow((ring[0]+.035)/.045,2))
 return Vector3(x,ring[0],z)

static func uv(point_value: Vector3,shape="tapered") -> Vector2:
 var extent=0.0
 for row in range(RINGS.size()):
  if is_equal_approx(point_value.y,RINGS[row][0]):extent=width(row,shape);break
 return Vector2(.5 if extent==0 else .5+point_value.x/extent*.5,(.19-point_value.y)/.38)

static func triangle(surface: SurfaceTool,points: Array,is_front: bool,shape: String):
 for vertex in points:surface.set_uv(uv(vertex,shape));surface.add_vertex(vertex)
 if is_front:front_triangles[shape].append(points)

static func mesh(shape="tapered") -> ArrayMesh:
 shape=shape_key(shape)
 if skins.has(shape):return skins[shape]
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 front_triangles[shape]=[]
 for side in range(SIDES):
  var front=side>=SIDES/2
  triangle(surface,[Vector3(0,-.19,-.025),point(0,side+1,shape),point(0,side,shape)],front,shape)
  for row in range(RINGS.size()-1):
   var a=point(row,side,shape);var b=point(row,side+1,shape);var c=point(row+1,side+1,shape);var d=point(row+1,side,shape)
   triangle(surface,[a,b,c],front,shape);triangle(surface,[a,c,d],front,shape)
  triangle(surface,[Vector3(0,.19,.01),point(RINGS.size()-1,side,shape),point(RINGS.size()-1,side+1,shape)],front,shape)
 surface.generate_normals();surface.generate_tangents();surface.index();skins[shape]=surface.commit();return skins[shape]

static func features(index: int,shape="tapered") -> ArrayMesh:
 shape=shape_key(shape);var key=shape+":"+str(index)
 if decals.has(key):return decals[key]
 mesh(shape)
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for points in front_triangles[shape]:
  for vertex in points:
   var local_uv=uv(vertex,shape)
   surface.set_uv(Vector2((index%4+local_uv.x)*.25,(index/4+local_uv.y)*.5))
   surface.add_vertex(vertex+Vector3(0,0,-.003))
 surface.generate_normals();decals[key]=surface.commit();return decals[key]
