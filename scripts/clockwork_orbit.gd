extends Node3D
## Slow, bounded mechanism motion is shared by tactical landmarks and arenas.
## Each ring shares baked geometry with matching dimensions. The scripted
## parent keeps its independent transforms outside scenery baking. Hidden
## scenes stop their clocks. No lights or RNG.
const PERIOD=TAU*20.0
const MAX_RING_SHAPES=12
const MAX_CORE_SHAPES=6
static var rings={}
static var cores={}
static var gold: StandardMaterial3D
static var pale: StandardMaterial3D
var theme="observatory"
var elapsed=0.0
var outer: Node3D
var inner: Node3D
var core: MeshInstance3D
var core_material: StandardMaterial3D
var conduit_light: StandardMaterial3D
var core_color=Color.WHITE

func configure(kind: String,radius=1.1,core_radius=.55):
 theme=kind;name="ClockworkOrbit"
 if gold==null:
  gold=StandardMaterial3D.new();gold.albedo_color=Color("bba16b");gold.roughness=.75
  pale=StandardMaterial3D.new();pale.albedo_color=Color("d5c79e");pale.roughness=.8
 outer=ring(radius,radius*.055,8 if theme=="engine" else 4)
 inner=ring(radius*.79,radius*.025,0)
 var globe=cores.get(core_radius) as SphereMesh
 if globe==null:
  globe=SphereMesh.new();globe.radius=core_radius;globe.height=core_radius*2
  globe.radial_segments=24;globe.rings=12
  if cores.size()<MAX_CORE_SHAPES:cores[core_radius]=globe
 core_material=StandardMaterial3D.new();core_color=Color("ffe3a0") if theme=="engine" else Color("5b859c")
 core_material.albedo_color=core_color;core_material.roughness=.65
 if theme=="engine":
  core_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  conduit_light=StandardMaterial3D.new()
  conduit_light.albedo_color=Color("cba16c")
  conduit_light.emission_enabled=true
  conduit_light.emission=Color("ffcb79")
 core=piece(self,globe,Vector3.ZERO,core_material)
 update_motion()

func ring(radius: float,half_width: float,count: int) -> Node3D:
 var pivot=Node3D.new();add_child(pivot)
 var key=Vector3(radius,half_width,count)
 if rings.has(key):
  var baked=rings[key]
  for shape in baked.meshes:
   var node=piece(pivot,shape,Vector3.ZERO,shape.surface_get_material(0))
   node.name="StaticScenery";node.set_meta("static_batch",true)
  pivot.set_meta("batch_stats",baked.stats.duplicate())
  return pivot
 var torus=TorusMesh.new();torus.inner_radius=radius-half_width;torus.outer_radius=radius+half_width;torus.rings=48;torus.ring_segments=12
 var hoop=piece(pivot,torus,Vector3.ZERO,pale if count==0 else gold);hoop.rotation.x=PI/2
 for index in count:
  var angle=TAU*index/count
  var marker=BoxMesh.new();marker.size=Vector3(half_width*1.2,half_width*4,half_width*2.4)
  var tick=piece(pivot,marker,Vector3(sin(angle)*radius,cos(angle)*radius,0),pale);tick.rotation.z=-angle
 var stats=preload("res://scripts/static_batch.gd").new().combine(pivot,false)
 if rings.size()<MAX_RING_SHAPES:
  rings[key]={"meshes":pivot.get_children().map(func(node):return node.mesh),"stats":stats.duplicate()}
 return pivot

func piece(parent: Node3D,shape: Mesh,point: Vector3,surface: Material) -> MeshInstance3D:
 var mesh=MeshInstance3D.new();mesh.mesh=shape;mesh.position=point;mesh.material_override=surface
 mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(mesh)
 return mesh

func update_motion():
 var angle=elapsed/20.0
 outer.rotation=Vector3(.12,0,angle*2) if theme=="engine" else Vector3(.15,angle,.7)
 inner.rotation=Vector3(.65,-angle*2+.4,-.35)
 if theme=="engine":
  var breath=sin(angle*24)
  core.scale=Vector3.ONE*(1+breath*.02)
  core_material.albedo_color=core_color.lerp(Color.WHITE,.04+breath*.04)
  conduit_light.emission_energy_multiplier=.48+breath*.20

func _process(dt):
 if core==null or not is_visible_in_tree():return
 elapsed=fposmod(elapsed+dt,PERIOD);update_motion()
