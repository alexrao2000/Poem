extends RefCounted

const RoofPaint=preload("res://scripts/architecture.gd")
const COLUMNS=10
const ROWS=6
const MAP_SITE=Vector3(6.32,0,4.24)
const ARENA_SITE=Vector3(1.55,0,-4.42)
const MAP_SCALE=.56
const ARENA_SCALE=1.24
static var net_shape: ArrayMesh
static var cord_paint: StandardMaterial3D

static func build(scenery,parent: Node3D,site: Vector3,size: float):
 var rack=Node3D.new();rack.name="HarborNetRack";rack.position=site;rack.scale=Vector3.ONE*size
 parent.add_child(rack)
 var oak=scenery.building_material(scenery.BuildingFinish.DECK_WOOD)
 var stone=scenery.detail_material(3)
 var tie=Color("50473a")
 for side in [-1,1]:
  var x=side*1.21
  scenery.block(rack,Vector3(x,.04,-.03),Vector3(.27,.11,.39),stone).name="NetRackFoot"
  scenery.block(rack,Vector3(x,.756,-.04),Vector3(.14,1.49,.16),oak).name="NetRackUpright"
  scenery.block(rack,Vector3(x,1.406,-.04),Vector3(.17,.16,.175),tie).name="NetRackCollar"
 scenery.block(rack,Vector3(0,1.43,0),Vector3(2.68,.12,.15),oak).name="NetRackBeam"
 var net=scenery.mesh(rack,shape(),Vector3.ZERO,Vector3.ONE,material())
 net.name="HangingNet"
 for index in [1,3,6,8]:
  var peg=site_at(float(index)/COLUMNS,1.0/ROWS)
  var float_mesh=scenery.cylinder(rack,peg+Vector3.BACK*.018,.075,.034,Color("ae8c53"),.029)
  float_mesh.rotation.z=.37 if index%2 else -.23
  float_mesh.name="CorkFloat"

static func material() -> StandardMaterial3D:
 if cord_paint==null:
  cord_paint=RoofPaint.material().duplicate()
  cord_paint.cull_mode=BaseMaterial3D.CULL_DISABLED
 return cord_paint

static func site_at(u: float,v: float) -> Vector3:
 var side=2*u-1
 var slack=1-side*side
 return Vector3(side*(1.1-v*.18),lerpf(1.365-.061*slack,.34-.145*slack,v),
  .070+.236*slack*sin(v*PI*.86))

static func shape() -> ArrayMesh:
 if net_shape!=null:return net_shape
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in ROWS:
  var from=float(row)/ROWS;var to=float(row+1)/ROWS
  for column in COLUMNS:
   var left=float(column)/COLUMNS;var right=float(column+1)/COLUMNS
   strand(tool,site_at(left,from),site_at(right,to),.014,Color("9b885f").darkened(float((row+column)%4)*.045))
   strand(tool,site_at(right,from)+Vector3.BACK*.0025,site_at(left,to)+Vector3.BACK*.0025,.012,Color("796a4e").lightened(float((row*3+column)%5)*.030))
 for side in [0.0,1.0]:
  for index in COLUMNS:
   strand(tool,site_at(float(index)/COLUMNS,side),site_at(float(index+1)/COLUMNS,side),.021,Color("756348"))
  for row in ROWS:
   strand(tool,site_at(side,float(row)/ROWS),site_at(side,float(row+1)/ROWS),.018,Color("796449"))
 for x in [0.0,.2,.4,.6,.8,1.0]:
  var knot=site_at(x,0.0)
  strand(tool,knot,Vector3(knot.x,1.48,.064),.022,Color("856b4b"))
 net_shape=tool.commit()
 return net_shape

static func strand(tool: SurfaceTool,first: Vector3,last: Vector3,width: float,paint: Color):
 var direction=last-first
 var edge=direction.cross(Vector3.BACK).normalized()*width*.5
 var normal=edge.cross(direction).normalized()
 RoofPaint.quad(tool,[first-edge,last-edge,last+edge,first+edge],normal,paint)
