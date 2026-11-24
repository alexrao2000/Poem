extends RefCounted

const MAP_SITE=Vector3(9.26,0,2.75)
const MAP_SCALE=.65
const BOOM_TIP=Vector3(0,2.06,-1.16)
const BRASS=Color("937142")
static var ring: TorusMesh

static func build(scenery,parent: Node3D,site: Vector3,size: float,yaw: float):
 var hoist=Node3D.new();hoist.name="KingsroadCargoHoist"
 hoist.position=site;hoist.scale=Vector3.ONE*size;hoist.rotation.y=yaw
 parent.add_child(hoist)
 var stone=scenery.detail_material(3)
 var oak=scenery.building_material(scenery.BuildingFinish.DECK_WOOD)
 var iron=scenery.material(Color("494a43"))
 var brass=scenery.material(BRASS)
 scenery.block(hoist,Vector3(0,.076,0),Vector3(.60,.18,.62),stone).name="HoistFooting"
 scenery.block(hoist,Vector3(0,.196,0),Vector3(.51,.09,.53),Color("a6a392")).name="HoistCap"
 scenery.block(hoist,Vector3(0,1.093,0),Vector3(.27,1.72,.26),oak).name="HoistMast"
 for y in [.31,1.72]:
  scenery.block(hoist,Vector3(0,y,0),Vector3(.29,.095,.28),iron).name="HoistCollar"
 beam(scenery,hoist,"HoistArm",Vector3(0,1.88,.12),BOOM_TIP,.183,.177,oak)
 beam(scenery,hoist,"HoistBrace",Vector3(0,.87,-.09),Vector3(0,2.00,-.94),.106,.10,oak)
 var wheel_center=Vector3(-.224,1.255,.040)
 var axle=scenery.cylinder(hoist,Vector3(-.156,wheel_center.y,wheel_center.z),.17,.082,Color("494a43"))
 axle.rotation.z=PI*.5;axle.name="HoistAxle"
 var rim=scenery.mesh(hoist,ring_shape(),wheel_center,Vector3(.295,.105,.295),brass)
 rim.rotation.z=PI*.5;rim.name="HoistHandwheel"
 for direction in [Vector3.UP,Vector3.BACK]:
  beam(scenery,hoist,"HoistSpoke",wheel_center-direction*.249,wheel_center+direction*.249,.050,.049,oak)
 var grip=scenery.cylinder(hoist,wheel_center+Vector3(-.078,.189,.174),.16,.047,Color("654934"),.043)
 grip.rotation.z=PI*.5;grip.name="HoistGrip"
 var pulley_center=BOOM_TIP-Vector3.UP*.114
 var pulley=scenery.cylinder(hoist,pulley_center,.232,.103,Color("494a43"))
 pulley.rotation.z=PI*.5;pulley.name="HoistPulley"
 for index in 9:
  var link=scenery.mesh(hoist,ring_shape(),pulley_center-Vector3.UP*(.119+index*.091),Vector3(.040,.031,.067),iron)
  link.rotation=Vector3(PI*.5,0.0 if index%2==0 else PI*.5,0)
  link.name="HoistChainLink"
 var eye=scenery.mesh(hoist,ring_shape(),pulley_center-Vector3.UP*.916,Vector3(.079,.055,.107),brass)
 eye.rotation.x=PI*.5;eye.name="HoistEye"

static func beam(scenery,parent: Node3D,label: String,first: Vector3,last: Vector3,width: float,depth: float,paint: Material):
 var timber=scenery.block(parent,(first+last)*.5,Vector3(width,first.distance_to(last),depth),paint)
 timber.quaternion=Quaternion(Vector3.UP,(last-first).normalized())
 timber.name=label

static func ring_shape() -> TorusMesh:
 if ring==null:
  ring=TorusMesh.new();ring.inner_radius=.74;ring.outer_radius=1.0;ring.rings=16;ring.ring_segments=6
 return ring
