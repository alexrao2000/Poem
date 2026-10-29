extends Node3D
# Original local impact accents: additive glow, tapered sparks and angular
# critical forks. Fixed geometry keeps presentation independent of game RNG.
var camera: Camera3D
var plane: Node3D
var burst: MeshInstance3D
var glow: MeshInstance3D
var amount: Label3D
var motion: Tween
static var glow_texture: GradientTexture2D

func configure(point: Vector3,event: Dictionary,view: Camera3D):
 name="CombatImpact";position=point;camera=view
 amount=Label3D.new();amount.name="Damage";amount.text=str(int(event.damage)) if event.hit else "MISS"
 amount.font_size=110 if event.crit else 80;amount.pixel_size=.0055;amount.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 amount.modulate=Color("ffdb73") if event.crit else Color("fff8e3") if event.hit else Color("d4e6ec")
 amount.outline_modulate=Color("302a35");amount.outline_size=14;amount.position.y=.52;amount.no_depth_test=true
 add_child(amount)
 motion=create_tween().set_parallel(true)
 motion.tween_property(amount,"position:y",1.1,.62).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
 motion.tween_property(amount,"scale",Vector3.ONE,.13).from(Vector3.ONE*1.3)
 motion.tween_property(amount,"modulate:a",0.0,.22).set_delay(.4)
 if event.hit:
  plane=Node3D.new();add_child(plane)
  glow=MeshInstance3D.new();glow.name="ContactGlow";plane.add_child(glow)
  var quad=QuadMesh.new();quad.size=Vector2.ONE*(1.5 if event.crit else .9);glow.mesh=quad
  var material=accent_material();material.albedo_texture=radial_texture();glow.material_override=material
  burst=MeshInstance3D.new();burst.name="CriticalForks" if event.crit else "Sparks";plane.add_child(burst)
  burst.mesh=burst_mesh(event.crit);burst.material_override=accent_material();burst.position.z=.01
  motion.tween_property(glow,"scale",Vector3.ONE*1.3,.2).from(Vector3.ONE*.4)
  motion.tween_property(glow.material_override,"albedo_color:a",0.0,.18).set_delay(.035)
  motion.tween_property(burst,"scale",Vector3.ONE*1.18,.23).from(Vector3.ONE*.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
  motion.tween_property(burst.material_override,"albedo_color:a",0.0,.2).set_delay(.08)
 _process(0)
 motion.chain().tween_callback(queue_free)

static func accent_material() -> StandardMaterial3D:
 var material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
 material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.vertex_color_use_as_albedo=true
 material.render_priority=2;return material

static func radial_texture() -> GradientTexture2D:
 if glow_texture!=null:return glow_texture
 var gradient=Gradient.new();gradient.offsets=PackedFloat32Array([0,.15,.42,1])
 gradient.colors=PackedColorArray([Color(1,1,.9,.85),Color(1,.9,.5,.65),Color(1,.56,.18,.25),Color(1,.35,.08,0)])
 glow_texture=GradientTexture2D.new();glow_texture.width=128;glow_texture.height=128
 glow_texture.gradient=gradient;glow_texture.fill=GradientTexture2D.FILL_RADIAL
 glow_texture.fill_from=Vector2(.5,.5);glow_texture.fill_to=Vector2(1,.5)
 return glow_texture

static func ribbon(surface: SurfaceTool,start: Vector2,end: Vector2,width: float,color: Color):
 var normal=(end-start).orthogonal().normalized()*width
 var points=[start-normal,start+normal,end]
 for p in points:surface.set_color(color);surface.add_vertex(Vector3(p.x,p.y,0))

static func burst_mesh(critical: bool) -> ArrayMesh:
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(14 if critical else 9):
  var angle=i*2.39996
  var direction=Vector2(cos(angle),sin(angle))
  var length=.45+float(i%4)*.13
  ribbon(surface,direction*.12,direction*length*(1.3 if critical else 1.0),.022 if i%2 else .038,Color("ffe1a0") if i%2 else Color("ffab3f"))
 if critical:
  for i in range(5):
   var direction=Vector2.from_angle(i*TAU/5+.2);var side=direction.orthogonal();var previous=direction*.14
   for j in range(1,6):
    var next=direction*(.14+j*.21)+side*sin(j*4.3+i)*.11
    ribbon(surface,previous,next,.018,Color("fff2c7"));previous=next
    if j==3:ribbon(surface,previous,previous+direction*.22+side*.18,.012,Color("ffd37c"))
 return surface.commit()

func _process(_dt):
 if is_instance_valid(plane) and is_instance_valid(camera) and plane.global_position.distance_to(camera.global_position)>.01:
  plane.look_at(camera.global_position,Vector3.UP)
