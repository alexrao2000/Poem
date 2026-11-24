extends RefCounted

const CELL_SITE=Vector3(4.32,0,2.34)
const CELL_HEIGHT=.78
static var collar: CylinderMesh

static func build(scenery,chamber: Node3D,light: StandardMaterial3D):
 var assembly=Node3D.new()
 assembly.name="SunEngineConduits"
 chamber.add_child(assembly)
 var stone=scenery.detail_material(3)
 var iron=scenery.material(Color("46565a"))
 var bronze=scenery.material(Color("ae865a"))
 for side in [-1,1]:
  var site=Vector3(CELL_SITE.x*side,0,CELL_SITE.z)
  scenery.block(assembly,site+Vector3.UP*-.015,Vector3(.88,.45,.83),stone).name="ConduitFooting"
  sleeve(scenery,assembly,site+Vector3.UP*.278,.21,.361,iron).name="ConduitFitting"
  sleeve(scenery,assembly,site+Vector3.UP*.450,.15,.323,bronze).name="ConduitLowerCollar"
  sleeve(scenery,assembly,site+Vector3.UP*CELL_HEIGHT,.540,.206,light).name="ConduitCell"
  sleeve(scenery,assembly,site+Vector3.UP*1.10,.15,.311,bronze).name="ConduitUpperCollar"
  sleeve(scenery,assembly,site+Vector3.UP*1.20,.12,.246,iron).name="ConduitCap"
  for x in [-1,1]:
   for z in [-1,1]:
    scenery.block(assembly,site+Vector3(x*.186,.776,z*.186),Vector3(.060,.67,.060),iron).name="ConduitCage"
  var elbow=Vector3(side*3.42,.245,2.34)
  var socket=Vector3(side*1.98,.245,1.91)
  var start=site+Vector3.UP*.245
  scenery.block(assembly,elbow,Vector3(.315,.31,.322),bronze).name="ConduitElbow"
  scenery.timber_span(assembly,start,elbow,Vector2(.232,.214),iron).name="ConduitDuct"
  scenery.timber_span(assembly,elbow,socket,Vector2(.232,.214),iron).name="ConduitDuct"
  scenery.timber_span(assembly,start.lerp(elbow,.30)+Vector3.UP*.116,elbow+Vector3.UP*.116,Vector2(.079,.031),bronze).name="ConduitSeam"
  scenery.timber_span(assembly,elbow+Vector3.UP*.116,socket+Vector3.UP*.116,Vector2(.079,.031),bronze).name="ConduitSeam"

static func sleeve(scenery,assembly: Node3D,site: Vector3,height: float,radius: float,paint: Material) -> MeshInstance3D:
 if collar==null:
  collar=CylinderMesh.new()
  collar.height=1.0;collar.top_radius=1.0;collar.bottom_radius=1.0
  collar.radial_segments=8;collar.rings=0
 return scenery.mesh(assembly,collar,site,Vector3(radius,height,radius),paint)
