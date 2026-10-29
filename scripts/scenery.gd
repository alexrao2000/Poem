extends RefCounted
# Shared landscape construction for the tactical board and battle stage.
var materials: Dictionary = {}
var atlas: Texture2D

func _init():
 atlas=load("res://assets/art/terrain-atlas.png")

func material(color: Color) -> StandardMaterial3D:
 var key=color.to_html()
 if materials.has(key):return materials[key]
 var m=StandardMaterial3D.new();m.albedo_color=color;m.roughness=.95
 materials[key]=m
 return m

func ground_material(tile: int) -> ShaderMaterial:
 var key="ground"+str(tile)
 if materials.has(key):return materials[key]
 var shader=Shader.new()
 shader.code="""shader_type spatial;
 uniform sampler2D atlas_texture : source_color, filter_linear_mipmap;
 uniform vec2 quadrant;
 varying vec3 world_position;
 void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
 void fragment() {
  vec2 uv=fract(world_position.xz*0.5)*0.496+0.002+quadrant;
  vec3 paint=texture(atlas_texture,uv).rgb;
  float gray=dot(paint,vec3(0.299,0.587,0.114));
  ALBEDO=mix(vec3(gray),paint,0.72)*vec3(0.88,0.94,0.94);
  ROUGHNESS=1.0;
 }
 """
 var m=ShaderMaterial.new();m.shader=shader;m.set_shader_parameter("atlas_texture",atlas)
 m.set_shader_parameter("quadrant",Vector2((tile%2)*.5,(tile/2)*.5))
 materials[key]=m
 return m

func mesh(parent: Node3D,shape: Mesh,p: Vector3,scale_value: Vector3,m: Material) -> MeshInstance3D:
 var n=MeshInstance3D.new();n.mesh=shape;n.position=p;n.scale=scale_value;n.material_override=m;parent.add_child(n);return n

func block(parent,p,size,color):
 return mesh(parent,BoxMesh.new(),p,size,material(color))

func ground(parent,p,size,tile):
 var shape=PlaneMesh.new();shape.size=size
 return mesh(parent,shape,p,Vector3.ONE,ground_material(tile))

func cylinder(parent,p,height,radius,color,top=-1.0):
 var shape=CylinderMesh.new();shape.height=height;shape.bottom_radius=radius;shape.top_radius=radius if top<0 else top;shape.radial_segments=8
 return mesh(parent,shape,p,Vector3.ONE,material(color))

func boulder(parent,p,radius):
 var shape=SphereMesh.new();shape.radius=1;shape.height=2;shape.radial_segments=7;shape.rings=4
 return mesh(parent,shape,p,Vector3(radius,radius*.6,radius*.8),ground_material(1))

func tree(parent,p,seed_value=0):
 var rng=RandomNumberGenerator.new();rng.seed=seed_value+997
 var h=rng.randf_range(1.1,1.6)
 cylinder(parent,p+Vector3(0,h*.3,0),h*.65,.065,Color("675444"),.035)
 for i in range(6):
  var shape=SphereMesh.new();shape.radius=1;shape.height=2;shape.radial_segments=8;shape.rings=5
  var angle=i*2.399
  var center=p+Vector3(cos(angle)*.27,h*.65+float(i%3)*.13,sin(angle)*.26)
  var n=mesh(parent,shape,center,Vector3(.38,.42,.36),material(Color("536e41").lightened(i*.016)))
  n.rotation.y=angle

func bridge(parent,p,vertical=false):
 var root=Node3D.new();parent.add_child(root);root.position=p
 if vertical:root.rotation.y=PI/2
 for i in range(7):
  block(root,Vector3((i-3)*.145,.035,0),Vector3(.135,.09,.98),Color("978367").lightened((i%3)*.025))
 for z in [-.43,.43]:
  block(root,Vector3(0,.25,z),Vector3(1,.07,.055),Color("665747"))
  for x in [-.4,.4]:block(root,Vector3(x,.16,z),Vector3(.065,.4,.065),Color("655444"))

func house(parent,p,scale_value=1.0):
 var root=Node3D.new();parent.add_child(root);root.position=p;root.scale=Vector3.ONE*scale_value
 block(root,Vector3(0,.6,0),Vector3(1.6,1.2,1.25),Color("c5bca4"))
 # Stone foundation, half-timber braces, door and windows.
 block(root,Vector3(0,.08,0),Vector3(1.7,.16,1.34),Color("8b8a79"))
 for x in [-.76,0,.76]:block(root,Vector3(x,.6,.64),Vector3(.06,1.2,.06),Color("695543"))
 for y in [.2,.95]:block(root,Vector3(0,y,.64),Vector3(1.6,.055,.055),Color("695543"))
 block(root,Vector3(-.3,.39,.67),Vector3(.28,.65,.025),Color("584c42"))
 block(root,Vector3(.4,.7,.67),Vector3(.27,.3,.025),Color("49616b"))
 for side in [-1,1]:
  var roof=block(root,Vector3(side*.45,1.38,0),Vector3(1.1,.09,1.5),Color("626c70"))
  roof.material_override=ground_material(3)
  roof.rotation.z=-side*.48
  for i in range(8):
   var seam=block(root,Vector3(side*.45,1.4,(i-3.5)*.18),Vector3(1.1,.025,.025),Color("7b8280"))
   seam.rotation.z=-side*.48
 block(root,Vector3(.5,1.6,-.3),Vector3(.23,.7,.25),Color("8d8271"))

func landscape(parent,game):
 # Surrounding land continues beyond the playable cells instead of exposing a board edge.
 ground(parent,Vector3(7,-.15,5),Vector2(64,64),0)
 if int(game.chapter)%4==0:
  var water=StandardMaterial3D.new();water.albedo_color=Color("274f61");water.roughness=.3
  var river=PlaneMesh.new();river.size=Vector2(1,64)
  mesh(parent,river,Vector3(6,-.07,5),Vector3.ONE,water)
 for y in range(10):
  for x in range(14):
   var t=game.terrain(Vector2i(x,y));var p=Vector3(x,0,y)
   var theme=int(game.chapter)%4
   var surface=1 if game.chapter==0 and x<6 and y>0 and y<8 else 0
   if t in ["o","+"] or (y==3 and t=="."):surface=1
   elif theme==3:surface=3
   elif theme==1 or t=="h":surface=2
   if t=="~":
    var water=StandardMaterial3D.new();water.albedo_color=Color("274f61");water.roughness=.25;water.metallic=.15
    var plane=PlaneMesh.new();plane.size=Vector2.ONE
    mesh(parent,plane,p-Vector3(0,.07,0),Vector3.ONE,water)
    for i in range(3):block(parent,p+Vector3((i-1)*.24,-.055,sin(x+y+i)*.3),Vector3(.18,.005,.014),Color("71979c"))
    for dx in [-.46,.46]:block(parent,p+Vector3(dx,.015,0),Vector3(.08,.18,1),Color("9d9e8e"))
   else:ground(parent,p,Vector2.ONE,surface)
   if t=="=":bridge(parent,p,theme==1)
   elif t=="f":tree(parent,p+Vector3(.22,0,-.22),x+y*17)
   elif t=="h":boulder(parent,p+Vector3(.22,0,-.2),.32)
   elif t=="#":
    for row in range(3):
     for col in range(3):block(parent,p+Vector3((col-1)*.32+(.04 if row%2 else 0),.17+row*.28,0),Vector3(.3,.26,.7),Color("9b9988").lightened((row+col)%2*.06))
   elif t=="o":
    cylinder(parent,p+Vector3(.3,.65,-.3),1.3,.025,Color("a99463"))
    block(parent,p+Vector3(.5,1.05,-.3),Vector3(.4,.32,.015),Color("a54c47"))
   elif t=="+":
    cylinder(parent,p+Vector3(0,.04,0),.08,.36,Color("b8b8a0"))
    block(parent,p+Vector3(0,.09,0),Vector3(.35,.02,.08),Color("f5e4ac"))
    block(parent,p+Vector3(0,.09,0),Vector3(.08,.02,.35),Color("f5e4ac"))
 # Framing village, wooded banks and far ridge; all outside playable coordinates.
 for p in [Vector3(-2,0,1),Vector3(-2.5,0,5),Vector3(3,0,-2),Vector3(10,0,-2),Vector3(15.5,0,5)]:house(parent,p,1.2)
 for i in range(26):
  var p=Vector3(-4+(i*7)%23,0,-3-(i%3)*1.3)
  tree(parent,p,i*23)
 for i in range(12):tree(parent,Vector3(-3+(i*13)%21,0,12+i%3),i*11)

func battle_landscape(parent,center,context={}):
 var theme=context.get("environment","village")
 parent.set_meta("environment",theme)
 var stone=theme in ["abbey","aqueduct","observatory","castle","engine","furnace"]
 ground(parent,center-Vector3(0,.06,0),Vector2(70,70),3 if stone else 0)
 ground(parent,center,Vector2(24,6),3 if stone else (1 if theme=="village" else 2))
 if theme in ["river","harbor","aqueduct"] or context.get("terrain")=="=":
  var water=StandardMaterial3D.new();water.albedo_color=Color("274f61");water.roughness=.2
  var plane=PlaneMesh.new();plane.size=Vector2(60,40)
  mesh(parent,plane,center+Vector3(0,-.025,-22),Vector3.ONE,water)
  if theme=="harbor" or context.get("terrain")=="=":
   for x in range(-10,11):
    for z in range(-2,3):block(parent,center+Vector3(x,.025,z),Vector3(.98,.05,.98),Color("877560").lightened((x+z+30)%3*.02))
  for x in range(-10,11,2):
   block(parent,center+Vector3(x,.55,-3),Vector3(.13,1.1,.13),Color("72624f"))
  block(parent,center+Vector3(0,.7,-3),Vector3(22,.12,.10),Color("8e7c60"))
 if theme in ["village","river","road","forest","harbor"]:
  for i in range(34 if theme=="forest" else 19):
   tree(parent,center+Vector3(-17+(i*11)%35,0,-6-(i%4)*2),i*83)
  if theme!="forest":
   for i in range(3):house(parent,center+Vector3(-12+i*11,0,-15),1.0+i*.13)
 if theme in ["abbey","aqueduct","observatory","castle"]:
  for x in range(-12,13,4):
   cylinder(parent,center+Vector3(x,1.8,-5),3.6,.32,Color("9e9d8d"))
   cylinder(parent,center+Vector3(x,.12,-5),.24,.5,Color("7f8178"))
   cylinder(parent,center+Vector3(x,3.5,-5),.3,.48,Color("c2bea7"))
   if theme in ["aqueduct","abbey"]:
    block(parent,center+Vector3(x+1.8,3.7,-5),Vector3(4,.35,.8),Color("aaa58f"))
  if theme=="castle":
   block(parent,center+Vector3(0,2,-9),Vector3(35,4,.7),Color("858b88"))
   for x in range(-16,17,2):block(parent,center+Vector3(x,4.2,-9),Vector3(.8,.8,.9),Color("9a9d91"))
  elif theme=="observatory":
   var ring=TorusMesh.new();ring.inner_radius=1.5;ring.outer_radius=1.58
   var orbit=mesh(parent,ring,center+Vector3(0,2.6,-10),Vector3.ONE,material(Color("b9a46f")))
   orbit.rotation.z=.7
 if theme in ["mountain","road","forest","river","village"]:
  for i in range(9):
   var shape=SphereMesh.new();shape.radius=1;shape.height=2;shape.radial_segments=18;shape.rings=8
   mesh(parent,shape,center+Vector3(-45+i*11,-1,-35-(i%3)*4),Vector3(13,(9 if theme=="mountain" else 4)+i%3,9),material(Color("809187").lightened(i%3*.035)))
  if theme=="mountain":
   for i in range(16):boulder(parent,center+Vector3(-12+(i*7)%25,.4,-4-i%3),1.0+i%3*.3)
 if theme in ["engine","furnace"]:
  for x in [-8,-4,0,4,8]:
   cylinder(parent,center+Vector3(x,2,-7),4,.4,Color("494d51"))
   cylinder(parent,center+Vector3(x,3.5,-7),.12,.6,Color("bb9a64"))
   var core_material=material(Color("fbb56c")).duplicate();core_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
   var core=SphereMesh.new();core.radius=.24;core.height=.48
   mesh(parent,core,center+Vector3(x,2.5,-6.6),Vector3.ONE,core_material)
  if theme=="engine":
   var ring=TorusMesh.new();ring.inner_radius=1.75;ring.outer_radius=2
   var outer=mesh(parent,ring,center+Vector3(0,4,-12),Vector3.ONE,material(Color("c6ad71")))
   outer.rotation.x=PI/2
   var shape=SphereMesh.new();shape.radius=1.2;shape.height=2.4
   var glow=material(Color("ffe3a0")).duplicate();glow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
   mesh(parent,shape,center+Vector3(0,4,-12),Vector3.ONE,glow)
 return theme
