extends RefCounted
const GateCloth=preload("res://scripts/wind_cloth.gd")
const MAP_GATE_SITE=Vector3(7.92,0,4.5)
const STONE_ATLAS=preload("res://assets/art/environment-atlas.png")
## Cached masonry courses and wedge battlements replace the plain tower drum.
static var tower_mesh: ArrayMesh
static var stone_material: StandardMaterial3D
static var castle_paints: Dictionary={}

static func material() -> StandardMaterial3D:
 if stone_material==null:
  stone_material=StandardMaterial3D.new();stone_material.vertex_color_use_as_albedo=true
  stone_material.vertex_color_is_srgb=true;stone_material.roughness=.96
 return stone_material

static func wall_paint(tint: Color) -> ShaderMaterial:
 if not castle_paints.has(tint):
  var stone=ShaderMaterial.new()
  stone.shader=preload("res://assets/shaders/castle-stone.gdshader")
  stone.set_shader_parameter("atlas_texture",STONE_ATLAS)
  stone.set_shader_parameter("tint",tint)
  castle_paints[tint]=stone
 return castle_paints[tint]

static func triangle(tool: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,normal: Vector3,color: Color):
 var points=[a,b,c] if (b-a).cross(c-a).dot(normal)<0 else [a,c,b]
 for point in points:
  tool.set_normal(normal);tool.set_color(color);tool.set_uv(Vector2(point.x,point.y));tool.add_vertex(point)

static func quad(tool: SurfaceTool,points: Array,normal: Vector3,color: Color):
 triangle(tool,points[0],points[1],points[2],normal,color)
 triangle(tool,points[0],points[2],points[3],normal,color)

static func wedge(tool: SurfaceTool,a: float,b: float,inner: float,outer: float,bottom: float,top: float,color: Color):
 var points=[]
 for y in [bottom,top]:
  for entry in [[a,inner],[a,outer],[b,outer],[b,inner]]:
   points.append(Vector3(cos(entry[0])*entry[1],y,sin(entry[0])*entry[1]))
 var radial=Vector3(cos((a+b)*.5),0,sin((a+b)*.5))
 for face in [[4,5,6,7,Vector3.UP],[0,1,2,3,Vector3.DOWN],[0,4,5,1,Vector3(sin(a),0,-cos(a))],[2,6,7,3,Vector3(-sin(b),0,cos(b))],[1,5,6,2,radial],[3,7,4,0,-radial]]:
  quad(tool,[points[face[0]],points[face[1]],points[face[2]],points[face[3]]],face[4],color)

static func tower() -> ArrayMesh:
 if tower_mesh!=null:return tower_mesh
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var stone=Color("969b91")
 # Narrow physical joints and staggered courses catch light at arena scale.
 for course in range(7):
  for segment in range(16):
   var a=(segment+(.5 if course%2 else 0))*TAU/16
   var base=.24+course*.25
   wedge(tool,a+.004,a+TAU/16-.004,.45,.55,base+.004,base+.246,stone.lightened(((course*11+segment*7)%7)*.012))
 for band in [[.04,.24,.70],[1.98,2.10,.61],[2.10,2.20,.66]]:
  for segment in range(16):
   var a=segment*TAU/16
   wedge(tool,a+.003,a+TAU/16-.003,.44,band[2],band[0],band[1],stone.darkened(.10) if band[0]<.3 else stone.lightened(.08))
 for segment in range(8):
  var a=segment*TAU/8
  wedge(tool,a-.19,a+.19,.46,.66,2.20,2.54,stone.lightened(.07))
 # An inset roof deck closes the well; it does not fill the battlement gaps.
 for segment in range(16):
  var a=segment*TAU/16;var b=(segment+1)*TAU/16
  var low_a=Vector3(cos(a)*.45,2.06,sin(a)*.45);var low_b=Vector3(cos(b)*.45,2.06,sin(b)*.45)
  var high_a=low_a+Vector3.UP*.06;var high_b=low_b+Vector3.UP*.06
  triangle(tool,Vector3(0,2.12,0),high_a,high_b,Vector3.UP,stone.darkened(.20))
  triangle(tool,Vector3(0,2.06,0),low_a,low_b,Vector3.DOWN,stone.darkened(.25))
  quad(tool,[low_a,high_a,high_b,low_b],Vector3(cos((a+b)*.5),0,sin((a+b)*.5)),stone.darkened(.20))
 tower_mesh=tool.commit();return tower_mesh

static var gate_mesh: ArrayMesh
static func gate_wall() -> ArrayMesh:
 if gate_mesh!=null:return gate_mesh
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var spans=[[Vector2(-2.2,0),Vector2(-1.4,0)],[Vector2(1.4,0),Vector2(2.2,0)]]
 for segment in range(16):
  var a=segment*PI/16;var b=(segment+1)*PI/16
  spans.append([Vector2(-cos(a)*1.4,2+sin(a)*1.4),Vector2(-cos(b)*1.4,2+sin(b)*1.4)])
 for span in spans:
  var contour=[span[0],span[1],Vector2(span[1].x,4.5),Vector2(span[0].x,4.5)]
  var front=[];var back=[]
  for point in contour:front.append(Vector3(point.x,point.y,.4));back.append(Vector3(point.x,point.y,-.4))
  quad(tool,front,Vector3.BACK,Color("9ca295"));quad(tool,back,Vector3.FORWARD,Color("92998d"))
  for edge in range(4):
   var next=(edge+1)%4;var direction=contour[next]-contour[edge]
   var normal=Vector3(direction.y,-direction.x,0).normalized()
   quad(tool,[front[edge],back[edge],back[next],front[next]],normal,Color("939b8e"))
 gate_mesh=tool.commit();return gate_mesh

static func build_castle_wall(painter,parent: Node3D,point: Vector3,raised=false):
 var group=Node3D.new();group.name="CastleGate";group.position=point;parent.add_child(group)
 for side in [-1,1]:
  painter.block(group,Vector3(side*9.85,2,0),Vector3(15.3,4,.7),wall_paint(Color("858b88"))).name="CastleWallWing"
  painter.block(group,Vector3(side*9.85,3.92,0),Vector3(15.3,.18,.82),Color("a2a699"))
 # Engaged square buttresses leave the approach to the gate unobstructed.
 for x in [-12,-8,-4,4,8,12]:
  var support=painter.block(group,Vector3(x,1.8,.48),Vector3(.6,3.6,.62),wall_paint(Color("989e92")));support.name="Buttress"
  painter.block(group,Vector3(x,.16,.48),Vector3(.82,.32,.8),Color("777f77"))
  painter.block(group,Vector3(x,3.64,.48),Vector3(.78,.22,.77),Color("b0b3a2"))
 for x in range(-16,17,2):
  if absi(x)>=4:painter.block(group,Vector3(x,4.2,0),Vector3(.8,.8,.9),Color("9a9d91"))
 build_portal(painter,group,raised)
 hang_gate_standards(painter,group)
 return group

static func build_map_gate(painter,parent: Node3D):
 var gate=Node3D.new();gate.name="CastleGate";gate.position=MAP_GATE_SITE
 gate.rotation.y=PI*.5;gate.scale=Vector3(.72,.59,.70);parent.add_child(gate)
 for x in [-2.12,2.12]:
  painter.block(gate,Vector3(x,.18,0),Vector3(.66,.38,1.04),Color("777f77")).name="GateFooting"
  painter.block(gate,Vector3(x,2.23,0),Vector3(.60,4.40,.82),wall_paint(Color("989e92"))).name="GateReturn"
  painter.block(gate,Vector3(x,4.44,0),Vector3(.70,.22,.93),Color("b0b3a2")).name="GateReturnCap"
 build_portal(painter,gate,true)
 hang_gate_standards(painter,gate,1.9)
 return gate

static func build_portal(painter,group: Node3D,raised: bool):
 var front=painter.mesh(group,gate_wall(),Vector3.ZERO,Vector3.ONE,wall_paint(Color("9ca295")));front.name="GateMasonry"
 painter.arch_span(group,Vector3(0,2,0),1.4,.3,.88)
 painter.block(group,Vector3(0,4.52,0),Vector3(4.6,.2,.95),Color("b4b7a5"))
 for x in [-1.5,0,1.5]:painter.block(group,Vector3(x,4.85,0),Vector3(.65,.5,.9),Color("a4aa9a"))
 var base=3.20 if raised else 0.0
 for index in range(-5,6):
  var x=index*.24
  var height=.77 if raised else 2+sqrt(1.4*1.4-x*x)-.09
  var bar=painter.block(group,Vector3(x,base+height*.5,-.12),Vector3(.045,height,.06),Color("4d585b"));bar.name="PortcullisBar"
 var heights=[3.38,3.79] if raised else [.8,1.8,2.8]
 for y in heights:
  var width=2.51 if raised else (2.7 if y<2 else 2*sqrt(1.4*1.4-pow(y-2,2))-.1)
  painter.block(group,Vector3(0,y,-.11),Vector3(width,.06,.07),Color("637073"))

static func hang_gate_standards(painter,gate: Node3D,lateral=3.03):
 var iron=Color("62646a")
 var brass=Color("a58b52")
 for side in [-1,1]:
  var x=side*lateral
  for offset in [-.43,.43]:
   painter.block(gate,Vector3(x+offset,3.68,.49),Vector3(.082,.082,.28),iron).name="StandardBracket"
  painter.block(gate,Vector3(x,3.68,.63),Vector3(1.12,.08,.08),brass).name="StandardRail"
  for offset in [-.56,.56]:
   painter.block(gate,Vector3(x+offset,3.68,.63),Vector3(.082,.12,.12),brass).name="StandardFinial"
  var cloth=GateCloth.new()
  gate.add_child(cloth,true)
  cloth.position=Vector3(x,3.68,.67)
  cloth.rotation.z=-PI*.5
  cloth.configure(Vector2(2.12,.95),Color("8c414b"),true,1.8 if side<0 else 5.3)
  cloth.name="WindStandardLeft" if side<0 else "WindStandardRight"
  cloth.material.set_shader_parameter("trim",Color("bda370"))
