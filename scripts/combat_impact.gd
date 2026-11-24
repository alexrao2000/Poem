extends Node3D
# Original local impact accents: additive glow, tapered sparks and angular
# critical forks. Split guard rings identify zero damage without damage sparks.
# Fixed geometry keeps presentation independent of game RNG.
const Spell=preload("res://scripts/combat_spell.gd")
const SpellBurst=preload("res://scripts/combat_spell_burst.gd")
const FloatingText=preload("res://scripts/combat_text.gd")
const CONTACT_FADE_DURATION=.19
var camera: Camera3D
var plane: Node3D
var burst: MeshInstance3D
var glow: MeshInstance3D
var guard: MeshInstance3D
var elemental: Node3D
var amount: FloatingText
var motion: Tween
static var glow_texture: GradientTexture2D
static var guard_geometry: ArrayMesh
static var burst_geometry={}

func configure(point: Vector3,event: Dictionary,view: Camera3D,spell="",ground=null):
 name="CombatImpact";position=point;camera=view
 var blocked=event.hit and event.damage<=0
 amount=FloatingText.new();amount.name="Damage";amount.text=("NO DAMAGE" if blocked else str(int(event.damage))) if event.hit else "MISS"
 amount.font_size=52 if blocked else 110 if event.crit else 80;amount.pixel_size=.0055;amount.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 amount.modulate=Color("ffdb73") if event.crit else Color("fff8e3") if event.hit else Color("d4e6ec")
 amount.outline_modulate=Color("302a35");amount.outline_size=14;amount.no_depth_test=true
 add_child(amount);amount.follow(view,point);amount.rise=.52
 motion=create_tween().set_parallel(true)
 motion.tween_property(amount,"rise",1.1,.62).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
 motion.tween_property(amount,"pop",1.0,.13).from(1.3)
 motion.tween_property(amount,"modulate:a",0.0,.22).set_delay(.4)
 if event.hit:
  plane=Node3D.new();add_child(plane)
  glow=MeshInstance3D.new();glow.name="ContactGlow";plane.add_child(glow)
  var quad=QuadMesh.new();quad.size=Vector2.ONE*(.5 if blocked else 1.5 if event.crit else .9);glow.mesh=quad
  var material=accent_material();material.albedo_texture=radial_texture()
  material.albedo_color=Color("9caab5") if blocked else Color("ffca76") if spell.is_empty() else Spell.palette(spell).accent
  glow.material_override=material
  if blocked:
   guard=MeshInstance3D.new();guard.name="GuardRings";plane.add_child(guard)
   guard.mesh=guard_mesh();guard.material_override=accent_material();guard.position.z=.01
   guard.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   motion.tween_property(guard,"scale",Vector3.ONE*1.25,.24).from(Vector3.ONE*.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
   motion.tween_property(guard.material_override,"albedo_color:a",0.0,.18).set_delay(.06)
  if not blocked:
   burst=MeshInstance3D.new();burst.name="CriticalForks" if event.crit else "Sparks";plane.add_child(burst)
   burst.mesh=burst_mesh(event.crit,spell);burst.material_override=accent_material();burst.position.z=.01
   motion.tween_property(burst,"scale",Vector3.ONE*1.18,.23).from(Vector3.ONE*.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
   motion.tween_property(burst.material_override,"albedo_color:a",0.0,.2).set_delay(.08)
  if not blocked and spell in ["ember","gale","thunder"]:
   var floor_point=point-Vector3.UP*1.1 if ground==null else ground
   elemental=SpellBurst.new();add_child(elemental)
   elemental.begin(spell,floor_point,point.y-floor_point.y,event.crit,accent_material())
  if not blocked and (event.crit or elemental!=null):
   cast_contact_light(glow.material_override.albedo_color,event.crit)
  motion.tween_property(glow,"scale",Vector3.ONE*1.3,.2).from(Vector3.ONE*.4)
  motion.tween_property(glow.material_override,"albedo_color:a",0.0,.18).set_delay(.035)
 _process(0)
 motion.chain().tween_callback(queue_free)

func cast_contact_light(color: Color,critical: bool):
 var light=OmniLight3D.new();light.name="ContactLight"
 light.light_color=color.lerp(Color.WHITE,.3)
 light.light_energy=.76 if critical else .46
 light.omni_range=2.55 if critical else 2.2
 light.light_specular=0.0;light.light_volumetric_fog_energy=0.0
 light.light_bake_mode=Light3D.BAKE_DISABLED;light.shadow_enabled=false
 add_child(light)
 light.global_position=global_position+Vector3.UP*.1
 if is_instance_valid(camera):
  light.global_position+=global_position.direction_to(camera.global_position)*.30
 motion.tween_property(light,"light_energy",0.0,CONTACT_FADE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
 motion.tween_callback(light.queue_free).set_delay(CONTACT_FADE_DURATION)

static func accent_material() -> StandardMaterial3D:
 var material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
 material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.vertex_color_use_as_albedo=true
 material.disable_fog=true
 material.render_priority=2;return material

static func radial_texture() -> GradientTexture2D:
 if glow_texture!=null:return glow_texture
 var gradient=Gradient.new();gradient.offsets=PackedFloat32Array([0,.15,.42,1])
 gradient.colors=PackedColorArray([Color(1,1,1,.85),Color(1,1,1,.65),Color(1,1,1,.25),Color(1,1,1,0)])
 glow_texture=GradientTexture2D.new();glow_texture.width=128;glow_texture.height=128
 glow_texture.gradient=gradient;glow_texture.fill=GradientTexture2D.FILL_RADIAL
 glow_texture.fill_from=Vector2(.5,.5);glow_texture.fill_to=Vector2(1,.5)
 return glow_texture

static func ribbon(surface: SurfaceTool,start: Vector2,end: Vector2,width: float,color: Color):
 var normal=(end-start).orthogonal().normalized()*width
 var points=[start-normal,start+normal,end]
 for p in points:surface.set_color(color);surface.add_vertex(Vector3(p.x,p.y,0))

static func guard_mesh() -> ArrayMesh:
 if guard_geometry!=null:return guard_geometry
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for ring in [[.34,.025,12,1.12],[.24,.014,8,.80]]:
  for side in [-1,1]:
   for index in range(ring[2]):
    var a=lerpf(-ring[3],ring[3],float(index)/ring[2])
    var b=lerpf(-ring[3],ring[3],float(index+1)/ring[2])
    var inner_a=Vector2(cos(a)*side,sin(a))*(ring[0]-ring[1])
    var outer_a=Vector2(cos(a)*side,sin(a))*ring[0]
    var inner_b=Vector2(cos(b)*side,sin(b))*(ring[0]-ring[1])
    var outer_b=Vector2(cos(b)*side,sin(b))*ring[0]
    for point in [inner_a,outer_a,outer_b,inner_a,outer_b,inner_b]:
     surface.set_color(Color("d9edf2") if ring[2]==12 else Color("91bdcc"));surface.add_vertex(Vector3(point.x,point.y,0))
 guard_geometry=surface.commit()
 return guard_geometry

static func burst_mesh(critical: bool,spell="") -> ArrayMesh:
 var colors={"core":Color("ffe1a0"),"accent":Color("ffab3f")} if spell.is_empty() else Spell.palette(spell)
 var forks=int(critical)*2+int(spell=="thunder")
 var key=Vector3i(colors.core.to_rgba32(),colors.accent.to_rgba32(),forks)
 if burst_geometry.has(key):return burst_geometry[key]
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(14 if critical else 9):
  var angle=i*2.39996
  var direction=Vector2(cos(angle),sin(angle))
  var length=.45+float(i%4)*.13
  ribbon(surface,direction*.12,direction*length*(1.3 if critical else 1.0),.022 if i%2 else .038,colors.core if i%2 else colors.accent)
 if critical or spell=="thunder":
  for i in range(5 if critical else 3):
   var direction=Vector2.from_angle(i*TAU/5+.2);var side=direction.orthogonal();var previous=direction*.14
   for j in range(1,6):
    var next=direction*(.14+j*.21)+side*sin(j*4.3+i)*.11
    ribbon(surface,previous,next,.018,colors.core);previous=next
    if j==3:ribbon(surface,previous,previous+direction*.22+side*.18,.012,colors.accent)
 var mesh=surface.commit()
 burst_geometry[key]=mesh
 return mesh

func _process(_dt):
 if is_instance_valid(plane) and is_instance_valid(camera) and plane.global_position.distance_to(camera.global_position)>.01:
  plane.look_at(camera.global_position,Vector3.UP)
