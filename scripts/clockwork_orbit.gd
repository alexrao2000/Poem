extends Node3D
## Slow, bounded mechanism motion is shared by tactical landmarks and arenas.
## Each ring batches its fixed markings locally; the scripted parent keeps it
## out of scenery baking. Hidden scenes stop their clocks. No lights or RNG.
const PERIOD=TAU*20.0
var theme="observatory"
var elapsed=0.0
var outer: Node3D
var inner: Node3D
var core: MeshInstance3D
var core_material: StandardMaterial3D
var core_color=Color.WHITE

func configure(kind: String,radius=1.1,core_radius=.55):
 theme=kind;name="ClockworkOrbit"
 var gold=StandardMaterial3D.new();gold.albedo_color=Color("bba16b");gold.roughness=.75
 var pale=StandardMaterial3D.new();pale.albedo_color=Color("d5c79e");pale.roughness=.8
 outer=ring(radius,radius*.055,gold,pale,8 if theme=="engine" else 4)
 inner=ring(radius*.79,radius*.025,pale,gold,0)
 var globe=SphereMesh.new();globe.radius=core_radius;globe.height=core_radius*2;globe.radial_segments=24;globe.rings=12
 core_material=StandardMaterial3D.new();core_color=Color("ffe3a0") if theme=="engine" else Color("5b859c")
 core_material.albedo_color=core_color;core_material.roughness=.65
 if theme=="engine":core_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 core=piece(self,globe,Vector3.ZERO,core_material)
 update_motion()

func ring(radius: float,half_width: float,surface: Material,marking: Material,count: int) -> Node3D:
 var pivot=Node3D.new();add_child(pivot)
 var torus=TorusMesh.new();torus.inner_radius=radius-half_width;torus.outer_radius=radius+half_width;torus.rings=48;torus.ring_segments=12
 var hoop=piece(pivot,torus,Vector3.ZERO,surface);hoop.rotation.x=PI/2
 for index in count:
  var angle=TAU*index/count
  var marker=BoxMesh.new();marker.size=Vector3(half_width*1.2,half_width*4,half_width*2.4)
  var tick=piece(pivot,marker,Vector3(sin(angle)*radius,cos(angle)*radius,0),marking);tick.rotation.z=-angle
 preload("res://scripts/static_batch.gd").new().combine(pivot,false)
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

func _process(dt):
 if core==null or not is_visible_in_tree():return
 elapsed=fposmod(elapsed+dt,PERIOD);update_motion()
