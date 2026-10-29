extends RefCounted
# Original articulated low-poly actors. Nodes are named for animation replacement.
const Actor=preload("res://scripts/fighter_actor.gd")
var profiles=JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
var surface_atlas=load("res://assets/art/character-materials.png")
var surface_shader=preload("res://assets/shaders/character.gdshader")
var surface_cache={}
var geo = preload("res://scripts/scenery.gd").new()

func ellipsoid(parent,p,size,color):
 var shape=SphereMesh.new();shape.radius=1;shape.height=2;shape.radial_segments=12;shape.rings=7
 return geo.mesh(parent,shape,p,size,geo.material(color))

func cloth(parent,points,color):
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var uv=[Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]
 for i in [0,1,2,0,2,3]:st.set_uv(uv[i]);st.add_vertex(points[i])
 st.generate_normals()
 var material=geo.material(color).duplicate();material.cull_mode=BaseMaterial3D.CULL_DISABLED
 return geo.mesh(parent,st.commit(),Vector3.ZERO,Vector3.ONE,material)

func joint(parent,node_name,p):
 var n=Node3D.new();n.name=node_name;n.position=p;parent.add_child(n);return n

func build(parent,u,p) -> Node3D:
 var actor=Actor.new();parent.add_child(actor);actor.position=p;actor.kind=u.weapon
 var body=joint(actor,"Body",Vector3(0,1.1,0));actor.register_bone("Body",body)
 var tint=Color(u.color)
 var palette={"Vanguard":"354c77","Knight":"394651","Ranger":"405c49","Arcanist":"434369","Warden":"c8c2ae","Rider":"3d566d","Corsair":"62463f","Duelist":"3b4355"}
 var blue=Color(palette[u.job]) if u.team=="player" else Color("853e43")
 var appearance=profiles.get(u.id,{}).get("appearance",{})
 var skin=Color(appearance.get("skin","e0ba98"));var steel=Color("a8b3bb");var gold=Color("bca26b");var leather=Color("554337")
 var heavy=u.job=="Knight";var robe=u.weapon in ["magic","staff"]
 var armored=u.job in ["Knight","Vanguard","Rider"]
 var cape_color=Color("e5dfce") if u.id in ["lyra","ivo"] else tint.darkened(.25)
 var torso=joint(body,"Torso",Vector3(0,.1,0))
 ellipsoid(body,Vector3(0,-.16,0),Vector3(.19,.19,.14),Color("3c3f48"))
 shell(torso,Vector3.ZERO,[[-.1,.18,.12],[.15,.21,.14],[.35,.245,.12],[.41,.15,.1]],blue)
 if armored:shell(torso,Vector3(0,0,-.065),[[.02,.17,.10],[.22,.23,.11],[.37,.20,.08]],steel)
 elif not robe:shell(torso,Vector3(0,0,-.04),[[.02,.17,.105],[.22,.21,.12],[.34,.18,.08]],leather)
 geo.cylinder(torso,Vector3(0,-.09,0),.08,.205,leather)
 geo.block(torso,Vector3(0,-.09,-.21),Vector3(.08,.07,.025),gold)
 # A layered coat/tassets with gold hem and a moving cape silhouette.
 for side_value in [-1,1]:
  var flap=cloth(torso,[Vector3(side_value*.02,-.13,-.14),Vector3(side_value*.20,-.13,-.12),Vector3(side_value*.25,-.46,-.20),Vector3(side_value*.035,-.43,-.23)],steel if heavy else blue)
  cloth(torso,[Vector3(side_value*.035,-.405,-.23),Vector3(side_value*.25,-.435,-.20),Vector3(side_value*.25,-.46,-.20),Vector3(side_value*.035,-.43,-.23)],gold)
 if robe:
  geo.cylinder(body,Vector3(0,-.55,0),.85,.29,blue,.18)
  geo.cylinder(body,Vector3(0,-.97,0),.035,.295,gold,.29)
 if u.weapon=="bow":
  var quiver=geo.cylinder(torso,Vector3(.16,.14,.19),.48,.075,leather);quiver.rotation.z=-.22
  for i in range(4):geo.cylinder(torso,Vector3(.12+i*.025,.43,.19),.4,.009,Color("9c8769"))
 var cape=joint(torso,"Cape",Vector3(0,.35,.12));actor.register_bone("Cape",cape)
 cape_surface(cape,cape_color)
 if u.id=="lyra":shell(torso,Vector3(0,0,.025),[[.34,.28,.16],[.43,.25,.15],[.47,.105,.085]],cape_color)
 for sign_value in [-1,1]:
  var leg_name="LeftLeg" if sign_value<0 else "RightLeg"
  var leg=joint(actor,leg_name,Vector3(sign_value*.13,.85,0));actor.register_bone(leg_name,leg)
  geo.cylinder(leg,Vector3(0,-.18,0),.37,.08,Color("3c3f48"),.10)
  var knee=joint(leg,"Knee",Vector3(0,-.36,0));actor.register_bone("LeftKnee" if sign_value<0 else "RightKnee",knee)
  ellipsoid(knee,Vector3(0,0,-.02),Vector3(.10,.11,.09),steel)
  geo.cylinder(knee,Vector3(0,-.18,0),.32,.085,steel if heavy else leather,.07)
  ellipsoid(knee,Vector3(0,-.38,-.07),Vector3(.09,.075,.145),leather)
  var arm_name="Arm" if sign_value>0 else "LeftArm"
  var arm=joint(body,arm_name,Vector3(sign_value*.27,.4,0));actor.register_bone(arm_name,arm)
  var shoulder_color=steel if armored else blue
  shell(arm,Vector3(sign_value*.025,0,0),[[-.12,.13 if heavy else .095,.13],[.02,.16 if heavy else .11,.15],[.10,.09,.09]],shoulder_color)
  if armored:geo.cylinder(arm,Vector3(0,-.12,0),.025,.13 if heavy else .10,gold)
  geo.cylinder(arm,Vector3(0,-.14,0),.28,.07,Color("69717a") if armored else blue,.085)
  var elbow=joint(arm,"Elbow",Vector3(0,-.29,0));actor.register_bone("Elbow" if sign_value>0 else "LeftElbow",elbow)
  ellipsoid(elbow,Vector3.ZERO,Vector3(.073,.073,.073),steel)
  geo.cylinder(elbow,Vector3(0,-.13,0),.25,.068,steel if armored else leather,.055)
  ellipsoid(elbow,Vector3(0,-.29,0),Vector3(.075,.085,.065),leather)
  if sign_value>0:weapon(elbow,u.weapon,gold,steel,leather)
  elif heavy:
   var shield=geo.cylinder(elbow,Vector3(-.04,-.16,-.17),.08,.29,blue)
   shield.rotation.x=PI/2;shield.scale=Vector3(.8,1,1.3)
   geo.block(elbow,Vector3(-.04,-.16,-.22),Vector3(.055,.45,.025),gold)
 geo.cylinder(body,Vector3(0,.53,0),.15,.075,skin)
 var head=joint(body,"Head",Vector3(0,.69,0));head.scale=Vector3(.86,.83,.86);actor.register_bone("Head",head)
 ellipsoid(head,Vector3.ZERO,Vector3(.145,.19,.14),skin)
 ellipsoid(head,Vector3(0,-.01,-.135),Vector3(.022,.029,.026),skin)
 for x in [-.14,.14]:ellipsoid(head,Vector3(x,-.015,0),Vector3(.025,.05,.025),skin)
 if heavy and u.team!="player":
  ellipsoid(head,Vector3(0,.045,.015),Vector3(.16,.19,.16),steel)
  geo.block(head,Vector3(0,.005,-.15),Vector3(.24,.045,.025),Color("303841"))
  geo.block(head,Vector3(0,-.055,-.16),Vector3(.05,.15,.03),gold)
 else:
  var hair=Color(appearance.get("hair","623c31"))
  if appearance.get("hair_style")!="bald":ellipsoid(head,Vector3(0,.085,.025),Vector3(.157,.145,.155),hair)
  for i in range(0 if appearance.get("hair_style")=="bald" else 7):
   var bang=geo.cylinder(head,Vector3((i-3)*.04,.065,-.115),.19,.035,hair,.002)
   bang.rotation.x=PI+.2;bang.rotation.z=(i-3)*.12
  for x in [-.061,.061]:
   geo.block(head,Vector3(x,-.014,-.146),Vector3(.053,.033,.012),Color("eee6d8"))
   geo.block(head,Vector3(x,-.014,-.155),Vector3(.022,.028,.008),Color("394c5c"))
   geo.block(head,Vector3(x,.015,-.146),Vector3(.054,.011,.012),hair.darkened(.3))
  geo.block(head,Vector3(0,-.08,-.125),Vector3(.043,.008,.008),skin.darkened(.3))
  if u.id=="petra":
   for x in [-.07,.07]:
    var rim=geo.cylinder(head,Vector3(x,.13,-.10),.035,.05,gold);rim.rotation.x=PI/2
    var lens=geo.cylinder(head,Vector3(x,.13,-.122),.015,.037,Color("445d6b"));lens.rotation.x=PI/2
  if appearance.get("hair_style")=="long":
   ellipsoid(head,Vector3(0,-.14,.14),Vector3(.13,.25,.09),hair)
  elif appearance.get("hair_style") in ["beard","bald"]:
   ellipsoid(head,Vector3(0,-.12,-.07),Vector3(.13,.12,.1),hair)
 if u.job=="Rider":
  actor.mounted=true
  for name_value in ["Body","LeftLeg","RightLeg"]:
   actor.bones[name_value].position.y+=.75
   actor.rest[name_value].position=actor.bones[name_value].position
  var horse=joint(actor,"Horse",Vector3(0,.85,0))
  ellipsoid(horse,Vector3.ZERO,Vector3(.34,.4,.68),Color("77513a"))
  ellipsoid(horse,Vector3(0,.34,-.52),Vector3(.19,.47,.2),Color("77513a"))
  ellipsoid(horse,Vector3(0,.63,-.66),Vector3(.16,.21,.30),Color("77513a"))
  var i=0
  for x in [-.23,.23]:
   for z in [-.4,.43]:
    var leg=joint(horse,"Leg"+str(i),Vector3(x,-.12,z));actor.register_bone("HorseLeg"+str(i),leg)
    geo.cylinder(leg,Vector3(0,-.35,0),.7,.055,Color("5b3e32"))
    ellipsoid(leg,Vector3(0,-.72,0),Vector3(.075,.055,.10),Color("30333a"));i+=1
 apply_surfaces(actor,blue,tint,skin,steel,gold,leather,cape_color)
 actor.pose("idle",.01)
 return actor

func cape_surface(parent,color):
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in range(6):
  for column in range(6):
   var points=[];var uvs=[]
   for corner in [[column,row],[column+1,row],[column+1,row+1],[column,row+1]]:
    var u=corner[0]/6.0;var v=corner[1]/6.0
    points.append(Vector3((u-.5)*(.5+v*.25),-v*(.94+.04*sin(u*PI)),v*.42+sin(u*PI)*.10+sin(u*PI*6)*v*.025))
    uvs.append(Vector2(u,v))
   for index in [0,1,2,0,2,3]:st.set_uv(uvs[index]);st.add_vertex(points[index])
 st.generate_normals()
 var material=geo.material(color).duplicate();material.cull_mode=BaseMaterial3D.CULL_DISABLED
 geo.mesh(parent,st.commit(),Vector3.ZERO,Vector3.ONE,material)

func shell(parent,p,sections,color):
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in range(sections.size()-1):
  for side in range(8):
   var points=[];var uvs=[]
   for corner in [[row,side],[row,side+1],[row+1,side+1],[row+1,side]]:
    var section=sections[corner[0]];var angle=corner[1]*TAU/8
    points.append(Vector3(cos(angle)*section[1],section[0],sin(angle)*section[2]))
    uvs.append(Vector2(corner[1]/8.0,corner[0]/float(sections.size()-1)))
   for index in [0,2,1,0,3,2]:st.set_uv(uvs[index]);st.add_vertex(points[index])
 st.generate_normals()
 return geo.mesh(parent,st.commit(),p,Vector3.ONE,geo.material(color))

func painted(color: Color,tile: int,metal=false) -> ShaderMaterial:
 var key=color.to_html()+str(tile)+str(metal)
 if surface_cache.has(key):return surface_cache[key]
 var material=ShaderMaterial.new();material.shader=surface_shader
 material.set_shader_parameter("materials_atlas",surface_atlas)
 material.set_shader_parameter("tint",color)
 material.set_shader_parameter("quadrant",Vector2((tile%2)*.5,(tile/2)*.5))
 material.set_shader_parameter("texture_repeat",3.0 if tile==2 else 1.0)
 material.set_shader_parameter("metal",1.0 if metal else 0.0)
 surface_cache[key]=material;return material

func apply_surfaces(root,blue,tint,skin,steel,gold,leather,cape_color):
 for mesh in root.find_children("*","MeshInstance3D",true,false):
  var material=mesh.material_override
  if not material is StandardMaterial3D:continue
  var color=material.albedo_color
  if color==steel:mesh.material_override=painted(Color("d3d7dc"),1,true)
  elif color==leather:mesh.material_override=painted(Color("b1a797"),3)
  elif color==Color("69717a"):mesh.material_override=painted(Color("b8bfc8"),2)
  elif color in [blue,tint,cape_color,cape_color.darkened(.06)]:mesh.material_override=painted(color,0)
  elif color==gold:
   var metallic=material.duplicate();metallic.metallic=.45;metallic.roughness=.5;mesh.material_override=metallic
  elif color!=skin:
   var shaded=material.duplicate();shaded.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON;mesh.material_override=shaded

func weapon(arm,kind,gold,steel,leather):
 var hand=joint(arm,"Weapon",Vector3(0,-.29,-.04))
 if kind in ["magic","staff"]:
  geo.cylinder(hand,Vector3(0,.05,0),1.35,.022,leather)
  var orb=ellipsoid(hand,Vector3(0,.78,0),Vector3(.11,.11,.11),Color("79cbdb"))
  var glow=orb.material_override.duplicate();glow.emission_enabled=true;glow.emission=Color("6ebfce");glow.emission_energy_multiplier=1.4;orb.material_override=glow
 elif kind=="bow":
  hand.rotation.x=-1.5
  for i in range(12):
   var t=float(i)/12*PI;var next_t=float(i+1)/12*PI
   var start=Vector3(0,cos(t)*.45,-sin(t)*.22)
   var end=Vector3(0,cos(next_t)*.45,-sin(next_t)*.22)
   var segment=geo.cylinder(hand,(start+end)*.5,start.distance_to(end)+.008,.018,leather)
   segment.quaternion=Quaternion(Vector3.UP,(end-start).normalized())
  geo.block(hand,Vector3.ZERO,Vector3(.009,.9,.009),Color("d6c9a4"))
 else:
  var grip=geo.cylinder(hand,Vector3(0,0,-.08),.23,.027,leather);grip.rotation.x=PI/2
  if kind=="lance":
   var shaft=geo.cylinder(hand,Vector3(0,0,-.5),1.8,.024,leather);shaft.rotation.x=PI/2
   var tip=geo.cylinder(hand,Vector3(0,0,-1.48),.28,.075,steel,0);tip.rotation.x=-PI/2
  elif kind=="axe":
   var shaft=geo.cylinder(hand,Vector3(0,0,-.35),.9,.029,leather);shaft.rotation.x=PI/2
   cloth(hand,[Vector3(-.20,0,-.65),Vector3(.20,0,-.65),Vector3(.29,0,-.97),Vector3(-.29,0,-.97)],steel)
  else:
   geo.block(hand,Vector3(0,0,-.21),Vector3(.24,.04,.055),gold)
   var blade=geo.cylinder(hand,Vector3(0,0,-.65),.85,.055,steel,0);blade.rotation.x=-PI/2;blade.scale.x=.35
