extends Node3D

const MAP_SITE=Vector3(6.22,-.07,6.46)
const MAP_SCALE=.67
const AXLE_HEIGHT=.96
const OUTER_RADIUS=1.12
const TURN_RATE=.46
static var rim_mesh: TorusMesh
var phase=0.0
var rotor: Node3D

func build(scenery,parent: Node3D,site: Vector3,size: float,yaw: float):
 name="AqueductWaterwheel";position=site;scale=Vector3.ONE*size;rotation.y=yaw
 parent.add_child(self)
 var wood=scenery.building_material(scenery.BuildingFinish.DECK_WOOD)
 var stone=scenery.detail_material(3)
 var metal=Color("635747")
 var pivot=Vector3.UP*AXLE_HEIGHT
 for side in [-1,1]:
  var x=.78*side
  scenery.block(self,Vector3(x,-.18,0),Vector3(.40,.42,.78),stone).name="WheelFooting"
  scenery.block(self,Vector3(x,.46,0),Vector3(.27,1.05,.40),stone).name="WheelPier"
  scenery.block(self,Vector3(x,.93,0),Vector3(.36,.21,.52),metal).name="WheelBearing"
 rotor=Node3D.new();rotor.name="WheelRotor";rotor.position=pivot
 rotor.set_meta("dynamic",true);add_child(rotor)
 var axle=scenery.cylinder(rotor,Vector3.ZERO,1.8,.10,metal)
 axle.name="WheelAxle";axle.rotation.z=PI*.5
 for side in [-1,1]:
  var x=.45*side
  var rim=scenery.mesh(rotor,rim(),Vector3(x,0,0),Vector3.ONE,wood)
  rim.name="WheelRim";rim.rotation.z=PI*.5
  for spoke in 6:
   var angle=spoke*TAU/6
   var end=Vector3(x,cos(angle),sin(angle))*Vector3(1,1.035,1.035)
   scenery.timber_span(rotor,Vector3(x,0,0),end,Vector2(.084,.102),wood).name="WheelSpoke"
 for slot in 10:
  var angle=slot*TAU/10
  var paddle=scenery.block(rotor,Vector3(0,cos(angle),sin(angle))*.99,Vector3(1.08,.13,.27),wood)
  paddle.name="WheelPaddle";paddle.rotation.x=angle
 if scenery.batching_enabled:
  scenery.batcher.combine(rotor,false)
  scenery.batcher.combine(self,false)
 seek_phase(0.0)

static func rim() -> TorusMesh:
 if rim_mesh==null:
  rim_mesh=TorusMesh.new();rim_mesh.inner_radius=.941;rim_mesh.outer_radius=OUTER_RADIUS
  rim_mesh.rings=24;rim_mesh.ring_segments=6
 return rim_mesh

func seek_phase(value: float):
 phase=fposmod(value,TAU)
 rotor.rotation.x=phase

func _process(delta):
 if not is_visible_in_tree():return
 seek_phase(phase+TURN_RATE*delta)
