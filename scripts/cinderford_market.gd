extends RefCounted
## The stall shares its striped canvas and open timber frame between views.
## The canopy drapes between two rails and overhangs the counter.
const Architecture=preload("res://scripts/architecture.gd")
const HALF_WIDTH=.86
const ROWS=[-.50,-.40,-.15,.15,.42,.54]
const FRAME_DEPTH=[-.40,.42]
const STRIPES=9
const LINEN=Color("d2be93")
const RUST=Color("a05841")
const OAK=Color("786449")
const COUNTER_TOP=.624
const WARE_SIDES=12
const JUG=[
 Vector2(0,0),Vector2(.088,0),Vector2(.122,.044),Vector2(.126,.126),Vector2(.103,.198),
 Vector2(.059,.245),Vector2(.049,.294),Vector2(.063,.306),Vector2(.062,.323),
 Vector2(.045,.323),Vector2(.043,.28),Vector2(.068,.225),Vector2(0,.2),
]
const BOWL=[
 Vector2(0,0),Vector2(.067,0),Vector2(.091,.024),Vector2(.126,.073),Vector2(.137,.115),
 Vector2(.129,.128),Vector2(.116,.124),Vector2(.108,.087),Vector2(.062,.044),Vector2(0,.039),
]
const WARES=[
 {"spot":Vector2(-.55,.13),"scale":.9,"handle":0,"body":Color("a06641"),"rim":Color("d3a479")},
 {"spot":Vector2(-.23,-.10),"scale":1.0,"handle":-1,"body":Color("ae7850"),"rim":Color("e5c294")},
 {"spot":Vector2(.12,.125),"scale":1.0,"handle":0,"body":Color("809078"),"rim":Color("c7bf88")},
 {"spot":Vector2(.49,-.085),"scale":.96,"handle":1,"body":Color("436e6a"),"rim":Color("99ada0")},
]
static var striped_canvas: ArrayMesh
static var canvas_material: StandardMaterial3D
static var earthenware_mesh: ArrayMesh
static var earthenware_material: StandardMaterial3D

static func build(scenery,parent: Node3D,position: Vector3,extent: float) -> void:
 var stall=Node3D.new()
 stall.name="CinderfordMarketStall"
 stall.position=position
 stall.scale=Vector3.ONE*extent
 parent.add_child(stall)
 scenery.mesh(stall,canvas_mesh(),Vector3.ZERO,Vector3.ONE,paint()).name="StripedAwning"
 for depth in FRAME_DEPTH:
  var rear=roof_height(depth-.05);var front=roof_height(depth+.05)
  var inclination=atan2(rear-front,.10)
  var rail_height=(rear+front)*.5-.04/cos(inclination)-.002
  var post_height=rail_height-.033
  var rail=scenery.block(stall,Vector3(0,rail_height,depth),Vector3(1.64,.08,.10),OAK)
  rail.name="CanopyRail";rail.rotation.x=inclination
  for side in [-1,1]:
   var x=side*.73
   scenery.block(stall,Vector3(x,post_height*.5,depth),Vector3(.10,post_height,.10),OAK).name="AwningPost"
 for row in range(4):
  var wood=OAK.lightened(.12+float(row%2)*.045)
  scenery.block(stall,Vector3(0,.59,-.25+row*.17),Vector3(1.53,.068,.167),wood).name="CounterBoard"
 for side in [-1,1]:
  scenery.block(stall,Vector3(side*.73,.53,.01),Vector3(.085,.064,.93),OAK).name="CounterRail"
 scenery.block(stall,Vector3(0,.513,.35),Vector3(1.48,.105,.08),OAK.darkened(.12)).name="CounterApron"
 scenery.mesh(stall,pottery_mesh(),Vector3.ZERO,Vector3.ONE,pottery_paint()).name="Earthenware"

static func pottery_paint() -> StandardMaterial3D:
 if earthenware_material==null:
  earthenware_material=StandardMaterial3D.new()
  earthenware_material.vertex_color_use_as_albedo=true
  earthenware_material.vertex_color_is_srgb=true
  earthenware_material.roughness=.70
 return earthenware_material

static func pottery_mesh() -> ArrayMesh:
 if earthenware_mesh!=null:return earthenware_mesh
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for ware in WARES:
  var origin=Vector3(ware.spot.x,COUNTER_TOP,ware.spot.y)
  var profile=JUG if ware.handle!=0 else BOWL
  for row in range(profile.size()-1):
   var low=profile[row];var high=profile[row+1];var along=high-low
   var color=ware.rim if row in [profile.size()-5,profile.size()-4] else ware.body
   if along.y<0:color=color.darkened(.23)
   for segment in WARE_SIDES:
    var a=TAU*segment/WARE_SIDES;var b=TAU*(segment+1)/WARE_SIDES
    var normal=Vector3(cos((a+b)*.5)*along.y,-along.x,sin((a+b)*.5)*along.y).normalized()
    var ring=PackedVector3Array([
     Vector3(cos(a)*low.x,low.y,sin(a)*low.x),Vector3(cos(a)*high.x,high.y,sin(a)*high.x),
     Vector3(cos(b)*high.x,high.y,sin(b)*high.x),Vector3(cos(b)*low.x,low.y,sin(b)*low.x),
    ])
    var points=[]
    for point in ring:points.append(origin+point*ware.scale)
    var glaze=color.lightened((segment%4)*.014)
    if is_zero_approx(low.x):pottery_cap(tool,[points[0],points[1],points[2]],normal,glaze)
    elif is_zero_approx(high.x):pottery_cap(tool,[points[0],points[1],points[3]],normal,glaze)
    else:Architecture.quad(tool,points,normal,glaze)
  if ware.handle!=0:pottery_handle(tool,origin,ware.scale,ware.handle,ware.body)
 earthenware_mesh=tool.commit()
 return earthenware_mesh

static func pottery_cap(tool: SurfaceTool,points: Array,normal: Vector3,color: Color):
 var indices=[0,1,2] if (points[1]-points[0]).cross(points[2]-points[0]).dot(normal)<0 else [0,2,1]
 for index in indices:
  tool.set_normal(normal);tool.set_color(color);tool.set_uv(Vector2.ZERO);tool.add_vertex(points[index])

static func pottery_handle(tool: SurfaceTool,origin: Vector3,extent: float,side: int,color: Color):
 var rings=[]
 for index in range(9):
  var angle=lerpf(-PI*.5,PI*.5,index/8.0)
  var up=(sin(angle)+1.0)*.5
  var center=Vector3(side*(lerpf(.091,.041,up)+.128*cos(angle)),.158+.083*sin(angle),0)
  var outside=Vector3(side*cos(angle),sin(angle),0)
  var ring=[]
  for corner in range(6):
   var turn=TAU*corner/6.0
   ring.append(origin+(center+.018*(outside*cos(turn)+Vector3.BACK*sin(turn)))*extent)
  rings.append(ring)
 for row in range(rings.size()-1):
  for face in range(6):
   var next=(face+1)%6
   var outer=Vector3(side*cos(lerpf(-PI*.5,PI*.5,(row+.5)/8.0)),sin(lerpf(-PI*.5,PI*.5,(row+.5)/8.0)),0)
   var azimuth=TAU*(face+.5)/6.0
   var normal=outer*cos(azimuth)+Vector3.BACK*sin(azimuth)
   Architecture.quad(tool,[rings[row][face],rings[row+1][face],rings[row+1][next],rings[row][next]],normal,color)

static func roof_height(z: float) -> float:
 var t=inverse_lerp(ROWS[0],ROWS[-1],z)
 return lerpf(1.68,1.38,t)-sin(t*PI)*.080

static func canvas_mesh() -> ArrayMesh:
 if striped_canvas!=null:return striped_canvas
 var tool=SurfaceTool.new()
 tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for stripe in range(STRIPES):
  var a=lerpf(-HALF_WIDTH,HALF_WIDTH,float(stripe)/STRIPES)
  var b=lerpf(-HALF_WIDTH,HALF_WIDTH,float(stripe+1)/STRIPES)
  var color=RUST if stripe%2==0 else LINEN
  for row in range(1,ROWS.size()):
   var back=ROWS[row-1];var front=ROWS[row]
   var high=roof_height(back);var low=roof_height(front)
   var normal=Vector3(0,front-back,high-low).normalized()
   var corners=[Vector3(a,high,back),Vector3(b,high,back),Vector3(b,low,front),Vector3(a,low,front)]
   Architecture.quad(tool,corners,normal,color.darkened(.035*float((row+stripe)%3)))
  var edge=ROWS[-1]
  var hem=[Vector3(a,1.38,edge),Vector3(b,1.38,edge),
   Vector3(b-.013,1.245,edge+.013),Vector3(a+.013,1.245,edge+.013)]
  Architecture.quad(tool,hem,Vector3(0,.013,.135),color.darkened(.13))
 striped_canvas=tool.commit()
 return striped_canvas

static func paint() -> StandardMaterial3D:
 if canvas_material==null:
  canvas_material=StandardMaterial3D.new()
  canvas_material.vertex_color_use_as_albedo=true
  canvas_material.vertex_color_is_srgb=true
  canvas_material.cull_mode=BaseMaterial3D.CULL_DISABLED
  canvas_material.roughness=.93
 return canvas_material
