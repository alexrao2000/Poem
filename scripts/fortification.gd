extends RefCounted
## Cached masonry courses and wedge battlements replace the plain tower drum.
static var tower_mesh: ArrayMesh
static var stone_material: StandardMaterial3D

static func material() -> StandardMaterial3D:
 if stone_material==null:
  stone_material=StandardMaterial3D.new();stone_material.vertex_color_use_as_albedo=true
  stone_material.vertex_color_is_srgb=true;stone_material.roughness=.96
 return stone_material

static func triangle(tool: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,normal: Vector3,color: Color):
 var points=[a,b,c] if (b-a).cross(c-a).dot(normal)<0 else [a,c,b]
 for point in points:
  tool.set_normal(normal);tool.set_color(color);tool.set_uv(Vector2(point.x,point.y));tool.add_vertex(point)

static func quad(tool: SurfaceTool,points: Array,normal: Vector3,color: Color):
 triangle(tool,points[0],points[1],points[2],normal,color)
 triangle(tool,points[0],points[2],points[3],normal,color)

static func wedge(tool: SurfaceTool,a: float,b: float,inner: float,outer: float,bottom: float,top: float,color: Color):
 var points=[]
 for y in [bottom,top]:
  for entry in [[a,inner],[a,outer],[b,outer],[b,inner]]:
   points.append(Vector3(cos(entry[0])*entry[1],y,sin(entry[0])*entry[1]))
 var radial=Vector3(cos((a+b)*.5),0,sin((a+b)*.5))
 for face in [[4,5,6,7,Vector3.UP],[0,1,2,3,Vector3.DOWN],[0,4,5,1,Vector3(sin(a),0,-cos(a))],[2,6,7,3,Vector3(-sin(b),0,cos(b))],[1,5,6,2,radial],[3,7,4,0,-radial]]:
  quad(tool,[points[face[0]],points[face[1]],points[face[2]],points[face[3]]],face[4],color)

static func tower() -> ArrayMesh:
 if tower_mesh!=null:return tower_mesh
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var stone=Color("969b91")
 # Narrow physical joints and staggered courses catch light at arena scale.
 for course in range(7):
  for segment in range(16):
   var a=(segment+(.5 if course%2 else 0))*TAU/16
   var base=.24+course*.25
   wedge(tool,a+.004,a+TAU/16-.004,.45,.55,base+.004,base+.246,stone.lightened(((course*11+segment*7)%7)*.012))
 for band in [[.04,.24,.70],[1.98,2.10,.61],[2.10,2.20,.66]]:
  for segment in range(16):
   var a=segment*TAU/16
   wedge(tool,a+.003,a+TAU/16-.003,.44,band[2],band[0],band[1],stone.darkened(.10) if band[0]<.3 else stone.lightened(.08))
 for segment in range(8):
  var a=segment*TAU/8
  wedge(tool,a-.19,a+.19,.46,.66,2.20,2.54,stone.lightened(.07))
 # An inset roof deck closes the well; it does not fill the battlement gaps.
 for segment in range(16):
  var a=segment*TAU/16;var b=(segment+1)*TAU/16
  var low_a=Vector3(cos(a)*.45,2.06,sin(a)*.45);var low_b=Vector3(cos(b)*.45,2.06,sin(b)*.45)
  var high_a=low_a+Vector3.UP*.06;var high_b=low_b+Vector3.UP*.06
  triangle(tool,Vector3(0,2.12,0),high_a,high_b,Vector3.UP,stone.darkened(.20))
  triangle(tool,Vector3(0,2.06,0),low_a,low_b,Vector3.DOWN,stone.darkened(.25))
  quad(tool,[low_a,high_a,high_b,low_b],Vector3(cos((a+b)*.5),0,sin((a+b)*.5)),stone.darkened(.20))
 tower_mesh=tool.commit();return tower_mesh
