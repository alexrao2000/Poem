extends MultiMeshInstance3D
## Three gulls share one wing mesh and follow the harbor atmosphere clock.

const COUNT=3
static var wing_mesh: ArrayMesh
static var wing_material: StandardMaterial3D
var pose_buffer=PackedFloat32Array()

func configure():
 name="HarborGulls"
 cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 if wing_mesh==null:
  wing_mesh=make_wing()
  wing_material=StandardMaterial3D.new()
  wing_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  wing_material.cull_mode=BaseMaterial3D.CULL_DISABLED
  wing_material.vertex_color_use_as_albedo=true;wing_material.vertex_color_is_srgb=true
 material_override=wing_material
 var batch=MultiMesh.new()
 batch.transform_format=MultiMesh.TRANSFORM_3D
 batch.mesh=wing_mesh;batch.instance_count=COUNT*2
 batch.custom_aabb=AABB(Vector3(-15,1.4,-6),Vector3(30,3.1,12))
 multimesh=batch
 pose_buffer.resize(COUNT*24)
 update_from_clock()

static func make_wing() -> ArrayMesh:
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var root=Vector3(0,0,-.075)
 var shoulder=Vector3(.24,.045,-.12)
 var tip=Vector3(.74,.04,.07)
 var tip_edge=Vector3(.61,.025,.115)
 var trailing=Vector3(.25,-.015,.21)
 var tail=Vector3(0,0,.23)
 var back=Vector3(.064,.067,.025)
 var front=Vector3(0,0,-.19)
 for face in [[root,shoulder,back],[shoulder,tip,tip_edge],[shoulder,tip_edge,trailing],
  [shoulder,trailing,back],[back,trailing,tail],[back,tail,root],[back,root,front]]:
  var color=Color("66727d") if tip in face else Color("dedaca") if front in face or root in face else Color("b8bec0")
  for point in face:
   tool.set_color(color);tool.add_vertex(point)
 return tool.commit()

func update_from_clock():
 var elapsed: float=get_parent().elapsed
 for bird in COUNT:
  var angle=TAU*(elapsed/(13.0+bird*1.72)+.145+bird*.19)
  var radius=7.4+bird*1.35
  var point=Vector3(cos(angle)*radius-bird*.91,2.48+bird*.25+sin(angle*2.0)*.31,sin(angle)*3.25-bird*.6)
  var forward=Vector3(-sin(angle)*radius,0,cos(angle)*3.25).normalized()
  var facing=Basis.looking_at(forward).rotated(forward,.14*cos(angle))
  var flutter=pow(maxf(0.0,sin(elapsed*1.9+bird*.68)),2)
  var flap=.11+sin(elapsed*TAU*1.7+bird*.85)*flutter*.42
  var size=.80-bird*.055
  for half in 2:
   var side=-1.0 if half==0 else 1.0
   var wing=facing*Basis(Vector3.BACK,side*flap)*Basis.from_scale(Vector3(side,1,1)*size)
   for row in 3:
    var offset=(bird*2+half)*12+row*4
    pose_buffer[offset]=wing.x[row]
    pose_buffer[offset+1]=wing.y[row]
    pose_buffer[offset+2]=wing.z[row]
    pose_buffer[offset+3]=point[row]
 multimesh.buffer=pose_buffer

func _process(_dt):
 if is_visible_in_tree():update_from_clock()
