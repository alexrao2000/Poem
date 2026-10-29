extends RefCounted
# Original articulated low-poly actors. Batch rigid details within each joint,
# preserving every animated joint, painted face and authored model adapter.
var models=preload("res://scripts/combat_models.gd").new()
const Actor=preload("res://scripts/fighter_actor.gd")
const Mount=preload("res://scripts/mount_visuals.gd")
const Hair=preload("res://scripts/character_hair.gd")
const EnemyHeadgear=preload("res://scripts/enemy_headgear.gd")
var profiles=JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
var surface_atlas=load("res://assets/art/character-materials.png")
var surface_shader=preload("res://assets/shaders/character.gdshader")
var surface_cache={}
var shading_cache={}
var strand_materials={}
var batching_enabled=true
var face_atlas=load("res://assets/art/face-features.png")
var face_materials={}
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
 var imported=models.build(parent,u,p)
 if imported!=null:return imported
 shading_cache.clear();strand_materials.clear()
 var actor=Actor.new();parent.add_child(actor);actor.position=p;actor.kind=u.weapon
 var body=joint(actor,"Body",Vector3(0,1.1,0));actor.register_bone("Body",body)
 var tint=Color(u.color)
 var palette={"Vanguard":"354c77","Knight":"394651","Ranger":"405c49","Arcanist":"434369","Warden":"c8c2ae","Rider":"3d566d","Corsair":"62463f","Duelist":"3b4355"}
 var appearance=profiles.get(u.id,{}).get("appearance",{})
 var blue=Color(appearance.get("cloth",palette[u.job])) if u.team=="player" else Color("853e43")
 var skin=Color(appearance.get("skin","e0ba98"));var steel=Color("a8b3bb");var gold=Color("bca26b");var leather=Color("554337")
 var heavy=u.job=="Knight";var robe=u.weapon in ["magic","staff"]
 var armored=u.job in ["Knight","Vanguard","Rider"] and u.id!="lyra"
 var slender=u.id in ["lyra","sera","mara","nell","esme","faye","vela","una","petra","noor","yuna","rhea"]
 var cape_color=Color(appearance.get("cape","e5dfce" if u.id in ["lyra","ivo"] else tint.darkened(.25).to_html(false))) if u.team=="player" else tint.darkened(.25)
 actor.set_meta("costume_colors",{"cloth":blue,"cape":cape_color})
 var torso=joint(body,"Torso",Vector3(0,.1,0))
 ellipsoid(body,Vector3(0,-.16,0),Vector3(.19,.19,.14),Color("3c3f48"))
 shell(torso,Vector3.ZERO,[[-.1,.18,.12],[.15,.21,.14],[.35,.245,.12],[.41,.15,.1]],blue)
 if armored:shell(torso,Vector3(0,0,-.065),[[.02,.17,.10],[.22,.23,.11],[.37,.20,.08]],steel)
 elif not robe and u.id!="lyra":shell(torso,Vector3(0,0,-.04),[[.02,.17,.105],[.22,.21,.12],[.34,.18,.08]],leather)
 geo.cylinder(torso,Vector3(0,-.09,0),.08,.205,leather)
 geo.block(torso,Vector3(0,-.09,-.21),Vector3(.08,.07,.025),gold)
 # Collar, leather harness, chest fittings and layered hems.
 shell(torso,Vector3(0,0,0),[[.36,.095,.085],[.49,.09,.08]],blue)
 for side_value in [-1,1]:
  var piping=geo.block(torso,Vector3(side_value*.08,.39,-.095),Vector3(.018,.14,.015),gold);piping.rotation.z=side_value*.18
 if armored:
  for side_value in [-1,1]:
   var ridge=geo.block(torso,Vector3(side_value*.09,.20,-.173),Vector3(.018,.24,.013),gold);ridge.rotation.z=-side_value*.20
  ellipsoid(torso,Vector3(0,.31,-.17),Vector3(.045,.05,.014),gold)
 else:
  var strap=geo.block(torso,Vector3(0,.16,-.165),Vector3(.052,.48,.025),leather);strap.rotation.z=-.48
  geo.block(torso,Vector3(.025,.20,-.185),Vector3(.07,.06,.02),gold)
 for side_value in [-1,1]:
  var pouch=ellipsoid(torso,Vector3(side_value*.21,-.11,-.04),Vector3(.07,.09,.065),leather)
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
 if u.id=="lyra":
  shell(torso,Vector3(0,0,.025),[[.34,.28,.16],[.43,.25,.15],[.47,.105,.085]],cape_color)
  for side_value in [-1,1]:
   cloth(torso,[Vector3(side_value*.09,.44,-.11),Vector3(side_value*.27,.34,-.10),Vector3(side_value*.24,.20,-.15),Vector3(0,.34,-.17)],cape_color)
   var chain=geo.block(torso,Vector3(side_value*.13,.31,-.17),Vector3(.23,.016,.018),gold);chain.rotation.z=side_value*.42
  ellipsoid(torso,Vector3(0,.34,-.18),Vector3(.04,.045,.018),gold)
 for sign_value in [-1,1]:
  var leg_name="LeftLeg" if sign_value<0 else "RightLeg"
  var leg=joint(actor,leg_name,Vector3(sign_value*.13,.85,0));actor.register_bone(leg_name,leg)
  geo.cylinder(leg,Vector3(0,-.18,0),.37,.08,Color("3c3f48"),.10)
  var knee=joint(leg,"Knee",Vector3(0,-.36,0));actor.register_bone("LeftKnee" if sign_value<0 else "RightKnee",knee)
  ellipsoid(knee,Vector3(0,0,-.02),Vector3(.10,.11,.09),steel)
  geo.cylinder(knee,Vector3(0,-.18,0),.32,.085,steel if heavy else leather,.07)
  geo.cylinder(knee,Vector3(0,-.04,0),.06,.091,gold if heavy else leather.lightened(.13))
  if not heavy:
   for j in range(3):geo.block(knee,Vector3(0,-.11-j*.065,-.077),Vector3(.10,.012,.014),Color("8e7a61"))
  var boot=ellipsoid(knee,Vector3(0,-.38,-.07),Vector3(.09,.075,.145),leather);boot.name="Boot"
  var arm_name="Arm" if sign_value>0 else "LeftArm"
  var arm=joint(body,arm_name,Vector3(sign_value*(.225 if slender else .27),.4,0));actor.register_bone(arm_name,arm)
  var shoulder_color=steel if armored else blue
  shell(arm,Vector3(sign_value*.025,0,0),[[-.12,.13 if heavy else .095,.13],[.02,.16 if heavy else .11,.15],[.10,.09,.09]],shoulder_color)
  if armored:geo.cylinder(arm,Vector3(0,-.12,0),.025,.13 if heavy else .10,gold)
  geo.cylinder(arm,Vector3(0,-.14,0),.28,.07,Color("69717a") if armored else blue,.085)
  var elbow=joint(arm,"Elbow",Vector3(0,-.29,0));actor.register_bone("Elbow" if sign_value>0 else "LeftElbow",elbow)
  ellipsoid(elbow,Vector3.ZERO,Vector3(.073,.073,.073),steel)
  geo.cylinder(elbow,Vector3(0,-.13,0),.25,.068,steel if armored else leather,.055)
  ellipsoid(elbow,Vector3(0,-.29,0),Vector3(.075,.085,.065),leather)
  if sign_value>0:actor.register_bone("Weapon",weapon(elbow,u.weapon,gold,steel,leather))
  elif heavy:
   var shield=geo.cylinder(elbow,Vector3(-.04,-.16,-.17),.08,.29,blue)
   shield.rotation.x=PI/2;shield.scale=Vector3(.8,1,1.3)
   geo.block(elbow,Vector3(-.04,-.16,-.22),Vector3(.055,.45,.025),gold)
 geo.cylinder(body,Vector3(0,.53,0),.15,.075,skin)
 var head=joint(body,"Head",Vector3(0,.69,0));head.scale=Vector3(.86,.83,.86);actor.register_bone("Head",head)
 ellipsoid(head,Vector3.ZERO,Vector3(.145,.19,.14),skin)
 ellipsoid(head,Vector3(0,-.035,-.135),Vector3(.010,.025,.012),skin)
 for x in [-.14,.14]:ellipsoid(head,Vector3(x,-.015,0),Vector3(.025,.05,.025),skin)
 if heavy and u.team!="player":
  ellipsoid(head,Vector3(0,.045,.015),Vector3(.16,.19,.16),steel)
  geo.block(head,Vector3(0,.005,-.15),Vector3(.24,.045,.025),Color("303841"))
  geo.block(head,Vector3(0,-.055,-.16),Vector3(.05,.15,.03),gold)
 else:
  Hair.build(self,head,appearance,gold)
  var face_index={"lyra":0,"sera":1,"mara":3,"nell":2,"esme":2,"faye":3,"vela":1,"una":0,"petra":3,"noor":2,"yuna":1,"rhea":0,"oren":5,"ivo":4,"tarin":6,"bram":4,"rook":5,"cassian":6,"dax":5,"silas":6,"ari":4,"galen":7,"hale":7,"elian":6}.get(u.id,5)
  face_surface(head,face_index)
  if u.id=="petra":
   for x in [-.07,.07]:
    var rim=geo.cylinder(head,Vector3(x,.13,-.10),.035,.05,gold);rim.rotation.x=PI/2
    var lens=geo.cylinder(head,Vector3(x,.13,-.122),.015,.037,Color("445d6b"));lens.rotation.x=PI/2
 if u.team=="enemy":EnemyHeadgear.build(self,head,u.job,steel,gold)
 if u.job=="Rider":
  actor.mounted=true
  for name_value in ["Body","LeftLeg","RightLeg"]:
   actor.bones[name_value].position.y+=.75
   actor.rest[name_value].position=actor.bones[name_value].position
  Mount.build(self,actor,u.id,blue,gold,leather)
 apply_surfaces(actor,blue,tint,skin,steel,gold,leather,cape_color)
 if batching_enabled:batch_rig(actor)
 actor.grounded_stance=not actor.mounted
 actor.pose("idle",.01)
 return actor

func batch_rig(actor):
 for node in actor.bones.values():node.set_meta("dynamic",true)
 for node in actor.find_children("PaintedFace","MeshInstance3D",true,false):node.set_meta("dynamic",true)
 var totals={"sources":0,"batches":0,"vertices":0}
 var parts=[actor];parts.append_array(actor.bones.values())
 for part in parts:
  var stats=geo.batcher.combine(part,false)
  for key in totals:totals[key]+=stats[key]
 actor.set_meta("rig_batch_stats",totals)

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
   if not shading_cache.has(material):
    var metallic=material.duplicate();metallic.metallic=.45;metallic.roughness=.5;shading_cache[material]=metallic
   mesh.material_override=shading_cache[material]
  elif color!=skin:
   if not shading_cache.has(material):
    var shaded=material.duplicate();shaded.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON;shading_cache[material]=shaded
   mesh.material_override=shading_cache[material]

func weapon(arm,kind,gold,steel,leather) -> Node3D:
 var hand=joint(arm,"Weapon",Vector3(0,-.29,-.04))
 if kind=="magic":
  var book=joint(hand,"Spellbook",Vector3(0,.10,-.06));book.rotation.x=-.15
  geo.block(book,Vector3.ZERO,Vector3(.22,.29,.075),Color("344d65"))
  geo.block(book,Vector3(.006,0,-.043),Vector3(.195,.26,.025),Color("e8dfbf"))
  geo.block(book,Vector3(-.108,0,0),Vector3(.025,.30,.09),gold)
  for side_value in [-1,1]:
   geo.block(book,Vector3(0,side_value*.12,-.059),Vector3(.18,.012,.005),gold)
  var seal=geo.block(book,Vector3(0,0,-.062),Vector3(.075,.075,.008),gold);seal.rotation.z=PI/4
 elif kind=="staff":
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
 return hand

func face_surface(parent,index):
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in range(16):
  for column in range(16):
   var points=[];var uvs=[]
   for corner in [[column,row],[column+1,row],[column+1,row+1],[column,row+1]]:
    var u=corner[0]/16.0;var v=corner[1]/16.0
    var x=(u-.5)*.286;var y=.19-v*.38
    var z=-.14*sqrt(maxf(.015,1.0-pow(x/.145,2)-pow(y/.19,2)))-.003
    points.append(Vector3(x,y,z));uvs.append(Vector2((index%4+u)*.25,(index/4+v)*.5))
   for vertex in [0,2,1,0,3,2]:st.set_uv(uvs[vertex]);st.add_vertex(points[vertex])
 st.generate_normals()
 if not face_materials.has(index):
  var mat=StandardMaterial3D.new();mat.albedo_texture=face_atlas;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;mat.alpha_scissor_threshold=.22
  mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.roughness=1;mat.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON
  face_materials[index]=mat
 var visual=geo.mesh(parent,st.commit(),Vector3.ZERO,Vector3.ONE,face_materials[index]);visual.name="PaintedFace";visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func hair_lock(parent,points,radius,color):
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for segment in range(points.size()-1):
  for side in range(7):
   var vertices=[]
   for corner in [[segment,side],[segment,side+1],[segment+1,side+1],[segment+1,side]]:
    var taper=1.0-float(corner[0])/float(points.size()-1)*.95
    var angle=corner[1]*TAU/7
    vertices.append(points[corner[0]]+Vector3(cos(angle)*radius*taper,0,sin(angle)*radius*taper))
   for vertex in [0,2,1,0,3,2]:st.add_vertex(vertices[vertex])
 st.generate_normals()
 if not strand_materials.has(color):
  var mat=geo.material(color).duplicate();mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON;strand_materials[color]=mat
 return geo.mesh(parent,st.commit(),Vector3.ZERO,Vector3.ONE,strand_materials[color])
