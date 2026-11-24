extends RefCounted
## The furnace yard ends at a bank of iron-roofed service sheds.

const RockForms = preload("res://scripts/rock_forms.gd")
const DARK_IRON = Color("42373b")
const BAYS = [
 Vector3(-15.0,3.45,10.6), Vector3(-4.0,4.00,11.4),
 Vector3(7.55,3.25,11.7), Vector3(18.0,3.62,9.2),
]
static var glow: StandardMaterial3D
static var triangle: ArrayMesh
var shed_batches: Array[Dictionary] = []

static func ash(scenery) -> StandardMaterial3D:
 return scenery.material(Color("574841"))

func fringe(scenery, parent: Node3D, board: Vector2i):
 for site in [Vector3(-1.7,.73,1.3),Vector3(-1.22,.44,2.0),Vector3(-1.5,.54,7.5),
   Vector3(2.55,.49,10.3),Vector3(3.26,.37,10.58),Vector3(8.65,.60,11.16),
   Vector3(14.30,.66,5.5),Vector3(14.7,.48,6.27)]:
  var p = Vector3(site.x,-.15,site.z)
  var profile = RockForms.variant_at(p)
  scenery.mesh(parent, RockForms.mesh(profile), p+Vector3.UP*site.y*.23,
   Vector3(1.0,.45,.84)*site.y, ash(scenery)).name = "ReddeepSlagPile"
 for x in [-.66,board.x-.34]:
  scenery.block(parent,Vector3(x,-.045,(board.y-1)*.5),Vector3(.28,.30,board.y+.24),
   scenery.detail_material(3)).name = "ReddeepCoping"
 build(scenery,parent,Vector3((board.x-1)*.5-.35,-.14,-1.35),Vector3(.51,.48,.48))

func build(scenery, parent: Node3D, origin: Vector3, size: Vector3):
 var works = Node3D.new()
 works.name = "ReddeepServiceSheds"
 works.position = origin
 works.scale = size
 parent.add_child(works)
 if scenery.batching_enabled and not shed_batches.is_empty():
  for batch in shed_batches:
   var part = scenery.mesh(works,batch.mesh,Vector3.ZERO,Vector3.ONE,batch.paint)
   part.set_meta("static_batch",true)
  return
 var rust = Color("76615c")
 var brick = scenery.detail_material(3)
 for index in BAYS.size():
  var bay = BAYS[index]
  var x = bay.x
  var h = bay.y
  var width = bay.z
  var center = Vector3(x,h*.5,-1.02)
  scenery.block(works,center,Vector3(width,h,2.4),brick).name = "ReddeepServiceWall"
  scenery.block(works,Vector3(x,.18,.28),Vector3(width,.52,.32),DARK_IRON).name = "ReddeepServicePlinth"
  scenery.block(works,Vector3(x,h-.12,.26),Vector3(width,.22,.24),rust).name = "ReddeepServiceLintel"
  var roof_rise = [.78,1.05,.69,.90][index]
  var gable = scenery.mesh(works,gable_mesh(),Vector3(x,h,.19),Vector3(width,roof_rise,1.0),
   scenery.material(DARK_IRON.lightened(.12)))
  gable.name = "ReddeepGable"
  var rear = scenery.mesh(works,gable_mesh(),Vector3(x,h,-2.23),gable.scale,gable.material_override)
  rear.name = "ReddeepGable"
  rear.rotation.y = PI
  for side in [-1,1]:
   var half = width*.5
   var segment = Vector2(half,roof_rise)
   var eave = scenery.block(works,Vector3(x+side*half*.51,h+roof_rise*.5,-1.0),
    Vector3(segment.length()+.15,.14,2.72),rust.darkened(.18))
   eave.name = "ReddeepIronRoof"
   eave.rotation.z = -side*segment.angle()
   scenery.block(works,Vector3(x+side*(half-.22),h*.5,.27),
    Vector3(.28,h,.44),DARK_IRON).name = "ReddeepServicePier"
  scenery.block(works,Vector3(x,h+roof_rise,-1.0),Vector3(.18,.15,2.75),DARK_IRON).name = "ReddeepRidgeCap"
  for vent_center in [x-width*.24,x+width*.24]:
   vent(scenery,works,Vector3(vent_center,h*.58,.31),width*.19)
 if scenery.batching_enabled:
  scenery.batcher.combine(works,false)
  for part in works.get_children():
   shed_batches.append({"mesh":part.mesh,"paint":part.material_override})

static func gable_mesh() -> ArrayMesh:
 if triangle == null:
  var surface = SurfaceTool.new()
  surface.begin(Mesh.PRIMITIVE_TRIANGLES)
  for p in [Vector3(-.5,0,0),Vector3(0,1,0),Vector3(.5,0,0)]:
   surface.set_normal(Vector3.BACK)
   surface.add_vertex(p)
  triangle = surface.commit()
 return triangle

static func vent(scenery, parent: Node3D, center: Vector3, width: float):
 if glow == null:
  glow = StandardMaterial3D.new()
  glow.albedo_color = Color("7c3d2e")
  glow.emission_enabled = true
  glow.emission = Color("bf6432")
  glow.emission_energy_multiplier = .6
 scenery.block(parent,center,Vector3(width,1.09,.21),DARK_IRON).name = "ReddeepVentRecess"
 for y in [-.33,0.0,.33]:
  scenery.block(parent,center+Vector3(0,y,.145),Vector3(width*.82,.085,.08),glow).name = "ReddeepVentLight"
  scenery.block(parent,center+Vector3(0,y+.13,.20),Vector3(width*.86,.12,.10),Color("58474a")).name = "ReddeepVentBaffle"
