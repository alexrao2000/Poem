extends RefCounted

const Masonry=preload("res://scripts/architecture.gd")
const MAP_SITE=Vector3(7.15,0,5.5)
const MAP_SCALE=.46
const ARENA_SITE=Vector3(-9.4,-.06,-5.35)
const ARENA_SCALE=1.59
const ARENA_YAW=1.09
const RAIL_GAUGE=.386
const RAIL_TOP=.128
const AXLE_HEIGHT=.344
const WHEEL_RADIUS=.216

static var body: ArrayMesh
static var slag: ArrayMesh
static var axle_shape: CylinderMesh

static func build(scenery,parent: Node3D,site: Vector3,size: float,yaw=0.0) -> Node3D:
 var cart=Node3D.new()
 cart.name="ReddeepSlagCart"
 cart.position=site
 cart.scale=Vector3.ONE*size
 cart.rotation.y=yaw
 parent.add_child(cart)
 var sleepers=scenery.building_material(scenery.BuildingFinish.DECK_WOOD)
 var dark_iron=scenery.material(Color("403f44"))
 var worn=scenery.material(Color("87675b"))
 for index in range(-3,4):
  scenery.block(cart,Vector3(0,.024,index*.42),Vector3(1.06,.076,.164),sleepers).name="CartSleeper"
 for side in [-1,1]:
  var rail_x=side*RAIL_GAUGE
  scenery.block(cart,Vector3(rail_x,.080,0),Vector3(.105,.064,2.83),dark_iron).name="CartRailBase"
  scenery.block(cart,Vector3(rail_x,RAIL_TOP-.014,0),Vector3(.066,.028,2.83),worn).name="CartRailHead"
  scenery.block(cart,Vector3(side*.235,.504,0),Vector3(.104,.147,1.52),dark_iron).name="CartChassis"
  for z in [-.55,.55]:
   axle_part(scenery,cart,Vector3(rail_x,AXLE_HEIGHT,z),.106,WHEEL_RADIUS,Color("5b5150")).name="CartWheel"
   axle_part(scenery,cart,Vector3(side*.326,AXLE_HEIGHT,z),.030,.234,Color("484348")).name="CartWheelFlange"
   axle_part(scenery,cart,Vector3(side*.445,AXLE_HEIGHT,z),.058,.082,Color("a18166")).name="CartHub"
  for z in [-.62,.62]:
   scenery.timber_span(cart,Vector3(side*.337,.548,z),Vector3(side*.488,1.013,z),Vector2(.035,.104),worn).name="CartSideBand"
   for rivet in [Vector2(.364,.63),Vector2(.451,.90)]:
    axle_part(scenery,cart,Vector3(side*rivet.x,rivet.y,z),.039,.027,Color("ad8c70")).name="CartRivet"
 for z in [-.55,.55]:
  axle_part(scenery,cart,Vector3(0,AXLE_HEIGHT,z),.864,.047,Color("403f44")).name="CartAxle"
  scenery.block(cart,Vector3(0,.499,z),Vector3(.61,.119,.15),dark_iron).name="CartCrossbeam"
 for side in [-1,1]:
  scenery.block(cart,Vector3(0,.593,side*.793),Vector3(.207,.14,.204),dark_iron).name="CartTowBracket"
  for link_side in [-1,1]:
   scenery.block(cart,Vector3(link_side*.064,.593,side*.941),Vector3(.044,.050,.183),worn).name="CartTowEye"
  scenery.block(cart,Vector3(0,.593,side*1.027),Vector3(.166,.050,.042),worn).name="CartTowEye"
 scenery.mesh(cart,hopper(),Vector3.ZERO,Vector3.ONE,Masonry.material()).name="CartHopper"
 scenery.mesh(cart,residue(),Vector3.ZERO,Vector3.ONE,Masonry.material()).name="CartSlag"
 return cart

static func axle_part(scenery,parent: Node3D,site: Vector3,depth: float,radius: float,paint: Color) -> MeshInstance3D:
 if axle_shape==null:
  axle_shape=CylinderMesh.new()
  axle_shape.height=1.0;axle_shape.top_radius=1.0;axle_shape.bottom_radius=1.0
  axle_shape.radial_segments=8;axle_shape.rings=0
 var part=scenery.mesh(parent,axle_shape,site,Vector3(radius,depth,radius),scenery.material(paint))
 part.rotation.z=PI*.5
 return part

static func hopper() -> ArrayMesh:
 if body!=null:return body
 var tool=SurfaceTool.new()
 tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var lower=ring(.323,.728,.545)
 var shoulder=ring(.479,.878,.987)
 var rim=ring(.503,.902,1.037)
 var interior=ring(.436,.833,1.037)
 var floor=ring(.273,.665,.630)
 wall(tool,lower,shoulder,Color("695451"))
 wall(tool,shoulder,rim,Color("937366"))
 wall(tool,rim,interior,Color("aa8871"))
 wall(tool,interior,floor,Color("463c40"))
 cap(tool,lower,Vector3.DOWN,Color("3c363a"))
 cap(tool,floor,Vector3.UP,Color("544643"))
 body=tool.commit()
 return body

static func ring(width: float,depth: float,elevation: float) -> PackedVector3Array:
 const CORNER=.104
 return PackedVector3Array([
  Vector3(-width+CORNER,elevation,-depth),Vector3(width-CORNER,elevation,-depth),
  Vector3(width,elevation,-depth+CORNER),Vector3(width,elevation,depth-CORNER),
  Vector3(width-CORNER,elevation,depth),Vector3(-width+CORNER,elevation,depth),
  Vector3(-width,elevation,depth-CORNER),Vector3(-width,elevation,-depth+CORNER)
 ])

static func wall(tool: SurfaceTool,first: PackedVector3Array,second: PackedVector3Array,paint: Color):
 for index in first.size():
  var next=(index+1)%first.size()
  var normal=(second[next]-first[index]).cross(first[next]-first[index])
  Masonry.quad(tool,[first[index],first[next],second[next],second[index]],normal,paint.darkened(.045*(index%3)))

static func cap(tool: SurfaceTool,edge: PackedVector3Array,normal: Vector3,paint: Color):
 var center=Vector3(0,edge[0].y,0)
 for index in edge.size():
  triangle(tool,center,edge[index],edge[(index+1)%edge.size()],normal,paint)

static func residue() -> ArrayMesh:
 if slag!=null:return slag
 var tool=SurfaceTool.new()
 tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for lump in [
  Vector3(-.076,.116,-.55),Vector3(.13,.091,-.36),Vector3(-.14,.086,-.36),
  Vector3(.009,.137,-.16),Vector3(.145,.072,.04),Vector3(-.11,.090,.21),
  Vector3(.046,.116,.40),Vector3(-.111,.063,.54)
 ]:
  var base=Vector3(lump.x,.629,lump.z)
  var peak=base+Vector3(.011,lump.y,-.024)
  var extent=.111+lump.y*.14
  for index in 5:
   var first=Vector2.from_angle(float(index)*TAU/5)*extent
   var second=Vector2.from_angle(float(index+1)*TAU/5)*extent
   var a=base+Vector3(first.x,0,first.y)
   var b=base+Vector3(second.x,0,second.y)
   var normal=(b-peak).cross(a-peak).normalized()
   triangle(tool,peak,a,b,normal,Color("906356").darkened(float(index)*.07))
 slag=tool.commit()
 return slag

static func triangle(tool: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,normal: Vector3,paint: Color):
 var points=[a,c,b] if (b-a).cross(c-a).dot(normal)>0 else [a,b,c]
 for point in points:
  tool.set_normal(normal.normalized())
  tool.set_color(paint)
  tool.set_uv(Vector2(point.x,point.z))
  tool.add_vertex(point)
