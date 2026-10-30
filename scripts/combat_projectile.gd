extends Node3D
# Original arrow, thrown spear and spell presentations follow an explicit arc.
# Physical flights track the leading tip to contact, with the shaft behind it.
# Launch advances the tip from the hand so the shaft begins near the grip.
# Missed physical shots continue along their arrival tangent beyond the target.

const Spell=preload("res://scripts/combat_spell.gd")
const WeaponBlades=preload("res://scripts/weapon_blades.gd")
const ARROW_LENGTH=.72
var origin=Vector3.ZERO
var destination=Vector3.ZERO
var arc=0.0
var progress=0.0
var travel_end=1.0
var kind="bow"
var spell=""
var body: Node3D
var wake: MeshInstance3D
var wake_color=Color.WHITE
var motion: Tween

func launch(from: Vector3,to: Vector3,weapon: String,duration=.23,spell_id="",appearance={},miss=false) -> Tween:
 name="CombatProjectile";origin=from;destination=to;kind=weapon;spell=spell_id
 global_basis=Basis.IDENTITY
 arc=.14 if kind=="bow" else .08 if kind=="lance" else .04
 body=Node3D.new();body.name="FlightBody";add_child(body)
 if kind in ["bow","lance"]:
  var reach=physical_geometry(body,kind,appearance)
  for part in body.get_children():part.position.z+=reach
  origin=from+from.direction_to(to)*minf(reach,from.distance_to(to)*.5)
 else:
  var colors=Spell.palette(spell)
  var orb=SphereMesh.new();orb.radius=.14;orb.height=.28;orb.radial_segments=12;orb.rings=6
  if spell=="gale":
   for i in range(3):
    var ring=piece(body,Spell.crescent(),colors.accent,true);ring.name="WindCrescent"+str(i)
    ring.rotation=Vector3(.5,0,i*TAU/3);ring.position.z=(i-1)*.08
  elif spell=="thunder":
   for i in range(2):
    var bolt=piece(body,Spell.bolt(),colors.core if i==0 else colors.accent,true);bolt.name="ThunderBolt"+str(i);bolt.rotation.z=i*PI/2
  else:
   var core=piece(body,orb,colors.core,true);core.name="EmberCore" if spell=="ember" else "SpellCore"
   core.scale=Vector3(.85,.85,1.45) if spell=="ember" else Vector3.ONE
  var halo_shape=QuadMesh.new();halo_shape.size=Vector2.ONE*.6
  var halo=piece(body,halo_shape,colors.accent,true);halo.name="SpellGlow"
  halo.material_override.albedo_texture=preload("res://scripts/combat_impact.gd").radial_texture()
  halo.material_override.albedo_color.a=.35;halo.material_override.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;halo.material_override.billboard_keep_scale=true
  wake=MeshInstance3D.new();wake.name="SpellWake";wake_color=colors.wake
  var surface=StandardMaterial3D.new();surface.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  surface.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;surface.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
  surface.cull_mode=BaseMaterial3D.CULL_DISABLED;surface.vertex_color_use_as_albedo=true;surface.vertex_color_is_srgb=true;surface.disable_fog=true
  wake.material_override=surface;wake.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(wake)
 var tangent=destination-origin-Vector3.UP*PI*arc
 travel_end=1.0+minf(.35,.9/maxf(tangent.length(),.001)) if miss and kind in ["bow","lance"] else 1.0
 _process(0)
 motion=create_tween();motion.tween_property(self,"progress",travel_end,duration*travel_end).set_trans(Tween.TRANS_LINEAR)
 motion.tween_callback(func():_process(0);queue_free())
 return motion

static func physical_geometry(parent: Node3D,weapon: String,appearance={}) -> float:
 var length=ARROW_LENGTH if weapon=="bow" else 1.3
 var shaft=CylinderMesh.new();shaft.height=length;shaft.top_radius=.012 if weapon=="bow" else .021;shaft.bottom_radius=shaft.top_radius;shaft.radial_segments=8
 var pole=piece(parent,shaft,Color(appearance.get("grip","78604a")) if weapon=="lance" else Color("78604a"));pole.name="Shaft";pole.rotation.x=PI/2
 var width=.04 if weapon=="bow" else float(appearance.get("width",.065))
 var tip=piece(parent,WeaponBlades.spear(-length*.5+.10,-length*.5,-length*.5-(.075 if weapon=="bow" else .12),width),Color(appearance.get("steel","d5dce1")) if weapon=="lance" else Color("d5dce1"));tip.name="Tip"
 if weapon=="bow":
  var feather_material: Material
  for angle in [0,TAU/3,TAU*2/3]:
   var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
   for p in [Vector3(0,0,.20),Vector3(.075,0,.34),Vector3(0,0,.34)]:surface.add_vertex(p)
   surface.generate_normals()
   var feather=piece(parent,surface.commit(),Color("c5d1c9"));feather.rotation.z=angle
   if feather_material==null:feather_material=feather.material_override
   else:feather.material_override=feather_material
 return -tip.mesh.get_aabb().position.z

func point_at(t: float) -> Vector3:
 t=clampf(t,0,travel_end)
 if t>1:return destination+(destination-origin-Vector3.UP*PI*arc)*(t-1)
 return origin.lerp(destination,t)+Vector3.UP*sin(t*PI)*arc

func _process(_dt):
 if body==null:return
 global_position=point_at(progress)
 var direction=destination-origin+Vector3.UP*cos(minf(progress,1.0)*PI)*PI*arc
 if direction.length_squared()>.0001:
  body.look_at(global_position+direction,Vector3.FORWARD if direction.normalized().cross(Vector3.UP).length_squared()<.001 else Vector3.UP)
 if kind=="magic" and spell=="gale":body.rotate_object_local(Vector3.FORWARD,progress*TAU*2)
 if wake!=null:update_wake(direction.normalized())

func update_wake(direction: Vector3):
 var span=minf(progress,.28)
 if span<.0001:wake.hide();return
 var up=Vector3.UP-direction*direction.dot(Vector3.UP)
 if up.length_squared()<.001:up=Vector3.RIGHT-direction*direction.dot(Vector3.RIGHT)
 up=up.normalized();var axes=[up,direction.cross(up).normalized()]
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);var count=0
 for step in range(8):
  var t0=step/8.0;var t1=(step+1)/8.0
  var a=point_at(progress-span*t0);var b=point_at(progress-span*t1)
  var width0=.11*(1-t0);var width1=.11*(1-t1)
  for axis in axes:
   for side in [-1,1]:
    var points=[to_local(a),to_local(a+axis*width0*side),to_local(b+axis*width1*side),to_local(b)]
    var alpha=[.45*pow(1-t0,1.3),0.0,0.0,.45*pow(1-t1,1.3)]
    for triangle in [[0,1,2],[0,2,3]]:
     if (points[triangle[1]]-points[triangle[0]]).cross(points[triangle[2]]-points[triangle[0]]).length_squared()<1e-15:continue
     for index in triangle:
      var color=wake_color;color.a=alpha[index];surface.set_color(color);surface.add_vertex(points[index])
     count+=1
 if count>0:wake.mesh=surface.commit();wake.show()
 else:wake.hide()

static func piece(parent: Node3D,mesh: Mesh,color: Color,unlit=false) -> MeshInstance3D:
 var node=MeshInstance3D.new();node.mesh=mesh
 var material=StandardMaterial3D.new();material.albedo_color=color;material.roughness=.65
 material.cull_mode=BaseMaterial3D.CULL_DISABLED
 if unlit:
  material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
  material.albedo_color.a=.75;material.disable_fog=true
  if mesh is SphereMesh:material.cull_mode=BaseMaterial3D.CULL_BACK
  node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 node.material_override=material;parent.add_child(node);return node
