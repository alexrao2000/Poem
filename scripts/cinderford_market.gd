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
static var striped_canvas: ArrayMesh
static var canvas_material: StandardMaterial3D

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
