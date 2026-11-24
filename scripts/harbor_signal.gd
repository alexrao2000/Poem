extends RefCounted
## The quay signal is built from one baked frame and one warm lantern insert.

const LanternParts=preload("res://scripts/trail_lanterns.gd")
const MAP_SITE=Vector3(9.35,0,4.17)
const ARENA_SITE=Vector3(-3.40,0,-4.35)
const MAP_SCALE=.64
const ARENA_SCALE=1.32
const LENS_CENTER=Vector3(0,1.54,0)
const OAK=Color("67503a")
const IRON=Color("424644")
const COPPER=Color("61776c")
const BRASS=Color("b18b59")

static var frame_mesh: ArrayMesh
static var lens_mesh: BoxMesh
static var lens_material: StandardMaterial3D

static func build(scenery,parent: Node3D,point: Vector3,size: float):
 var beacon=Node3D.new()
 beacon.name="HarborSignal";beacon.position=point;beacon.scale=Vector3.ONE*size
 beacon.set_meta("static_batch",true)
 parent.add_child(beacon)
 scenery.mesh(beacon,frame_shape(),Vector3.ZERO,Vector3.ONE,LanternParts.paint()).name="SignalFrame"
 if lens_mesh==null:
  lens_mesh=BoxMesh.new();lens_mesh.size=Vector3(.30,.32,.30)
  lens_material=StandardMaterial3D.new()
  lens_material.albedo_color=Color("ffd88d");lens_material.roughness=.78
  lens_material.emission_enabled=true;lens_material.emission=Color("f3ad5d");lens_material.emission_energy_multiplier=.54
 var lens=scenery.mesh(beacon,lens_mesh,LENS_CENTER,Vector3.ONE,lens_material)
 lens.name="SignalLens";lens.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func frame_shape() -> ArrayMesh:
 if frame_mesh!=null:return frame_mesh
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var cube=BoxMesh.new()
 LanternParts.add_part(tool,cube,Vector3(0,.035,0),Vector3(.55,.12,.48),Color("7c7b6b"))
 LanternParts.add_part(tool,cube,Vector3(0,.73,0),Vector3(.138,1.27,.14),OAK)
 for direction in [-1,1]:
  LanternParts.add_part(tool,cube,Vector3(direction*.16,.53,0),Vector3(.088,.91,.10),OAK.darkened(.12),direction*.20)
  for depth in [-1,1]:
   LanternParts.add_part(tool,cube,Vector3(direction*.146,1.54,depth*.146),Vector3(.041,.36,.041),IRON)
  LanternParts.add_part(tool,cube,Vector3(direction*.169,1.49,0),Vector3(.023,.042,.315),BRASS)
  LanternParts.add_part(tool,cube,Vector3(0,1.49,direction*.169),Vector3(.315,.042,.023),BRASS)
 LanternParts.add_part(tool,cube,Vector3(0,1.22,0),Vector3(.24,.15,.24),IRON)
 LanternParts.add_part(tool,cube,Vector3(0,1.351,0),Vector3(.399,.065,.399),IRON)
 LanternParts.add_part(tool,cube,Vector3(0,1.715,0),Vector3(.417,.059,.417),BRASS)
 var roof=CylinderMesh.new()
 roof.bottom_radius=.30;roof.top_radius=.08;roof.height=.205
 roof.radial_segments=8;roof.rings=0
 LanternParts.add_part(tool,roof,Vector3(0,1.844,0),Vector3.ONE,COPPER)
 LanternParts.add_part(tool,cube,Vector3(0,1.97,0),Vector3(.105,.08,.105),IRON)
 frame_mesh=tool.commit()
 return frame_mesh
