extends RefCounted
## The receiving wall frames the basin's rear edge and leaves the core afloat.

const Fortification=preload("res://scripts/fortification.gd")
const SPANS=10
const RADIUS=7.7
const DEPTH=2.65
const MAP_SCALE=Vector3(.81,.66,.43)

static func build(scenery,parent: Node3D,anchor: Vector3,size: Vector3):
 var vault=Node3D.new();vault.name="SunEngineVault";vault.position=anchor;vault.scale=size
 parent.add_child(vault)
 var slate=Fortification.wall_paint(Color("565b60"))
 var edge=Fortification.wall_paint(Color("73716a"))
 var bronze=scenery.material(Color("a18560"))
 for index in SPANS:
  var start=point(index)
  var finish=point(index+1)
  var shoulder=absf(float(index)-(SPANS-1)*.5)/((SPANS-1)*.5)
  var height=.78+shoulder*.96
  wall_piece(scenery,vault,start,finish,.13,.26,1.04,edge).name="VaultFooting"
  wall_piece(scenery,vault,start,finish,height*.5,height,.82,slate).name="VaultWall"
  wall_piece(scenery,vault,start,finish,height+.04,.15,.96,edge).name="VaultCoping"
  if index%2!=0:continue
  # Bronze joints pick out the face toward the basin.
  var span=finish-start
  var opening=(start+finish)*.5
  var face=Vector3(-span.z,0,span.x).normalized()
  var rib=scenery.block(vault,opening+face*.463+Vector3.UP*.58,Vector3(.10,.76,.10),bronze)
  rib.name="VaultBronzeJoint";rib.rotation.y=atan2(-span.z,span.x)
 for slot in [0,2,8,SPANS]:
  var site=point(slot)
  var facing=Vector3(cos(float(slot)/SPANS*PI)*.24,0,-.25)
  var footing=scenery.block(vault,site+facing+Vector3.UP*.12,Vector3(1.22,.26,1.1),edge)
  footing.name="VaultButtressFoot"
  var shaft=scenery.block(vault,site+facing+Vector3.UP*1.09,Vector3(.66,1.86,.84),slate)
  shaft.name="VaultButtress"
  var crown=scenery.block(vault,site+facing+Vector3.UP*2.02,Vector3(.85,.19,.96),edge)
  crown.name="VaultButtressCap"

static func point(index: int) -> Vector3:
 var angle=PI*(1.0-float(index)/SPANS)
 return Vector3(cos(angle)*RADIUS,0,-sin(angle)*DEPTH)

static func wall_piece(scenery,parent: Node3D,start: Vector3,finish: Vector3,y: float,height: float,depth: float,paint: Material) -> MeshInstance3D:
 var span=finish-start
 var piece=scenery.block(parent,(start+finish)*.5+Vector3.UP*y,Vector3(span.length()+.035,height,depth),paint)
 piece.rotation.y=atan2(-span.z,span.x)
 return piece
