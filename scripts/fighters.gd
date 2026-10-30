extends RefCounted
# Original articulated low-poly actors. Batch rigid details within each joint,
# preserving every animated joint, painted face and authored model adapter.
var models=preload("res://scripts/combat_models.gd").new()
const Actor=preload("res://scripts/fighter_actor.gd")
const Mount=preload("res://scripts/mount_visuals.gd")
const Hair=preload("res://scripts/character_hair.gd")
const EnemyHeadgear=preload("res://scripts/enemy_headgear.gd")
const EquipmentVisuals=preload("res://scripts/equipment_visuals.gd")
const WeaponBlades=preload("res://scripts/weapon_blades.gd")
const Projectile=preload("res://scripts/combat_projectile.gd")
const Outline=preload("res://scripts/character_outline.gd")
const PromotionCostume=preload("res://scripts/promotion_costume.gd")
const Garments=preload("res://scripts/garments.gd")
const Cuirass=preload("res://scripts/cuirass.gd")
const Head=preload("res://scripts/character_head.gd")
const Commanders=preload("res://scripts/commanders.gd")
var profiles=JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
var enemy_looks=JSON.parse_string(FileAccess.get_file_as_string("res://data/enemy_looks.json"))
var surface_atlas=load("res://assets/art/character-materials.png")
var surface_shader=preload("res://assets/shaders/character.gdshader")
const COMPANY_CAPE=preload("res://assets/art/cape-company.svg")
const IMPERIAL_CAPE=preload("res://assets/art/cape-imperial.svg")
var surface_cache={}
var shading_cache={}
var strand_materials={}
var batching_enabled=true
var face_atlas=load("res://assets/art/face-features-v2.png")
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
 var actor=Actor.new();parent.add_child(actor);actor.position=p;actor.kind=u.weapon;actor.shaped_boots=u.job!="Rider"
 actor.attack_style=EquipmentVisuals.profiles[EquipmentVisuals.resolve(u.weapon,str(u.get("item","")))].get("motion","slash")
 actor.trail_edge=EquipmentVisuals.trail_edge(u.weapon,str(u.get("item","")))
 var body=joint(actor,"Body",Vector3(0,1.1,0));actor.register_bone("Body",body)
 var tint=Color(u.color)
 var palette={"Vanguard":"354c77","Knight":"394651","Ranger":"405c49","Arcanist":"434369","Warden":"c8c2ae","Rider":"3d566d","Corsair":"62463f","Duelist":"3b4355"}
 var company=u.team=="player"
 var appearance=profiles.get(u.id,{}).get("appearance",{}) if company else enemy_looks.get(u.job,{})
 var commander=Commanders.profile(u)
 if not commander.is_empty():
  appearance=appearance.duplicate(true);appearance.merge(commander.appearance,true);actor.set_meta("commander",commander.id)
 var blue=Color(appearance.get("cloth",palette[u.job] if company else "853e43"))
 var skin=Color(appearance.get("skin","e0ba98"));var steel=Color(appearance.get("steel","a8b3bb"));var gold=Color(appearance.get("metal","bca26b"));var leather=Color("554337")
 var heavy=u.job=="Knight";var robe=u.weapon in ["magic","staff"]
 var armored=u.job in ["Knight","Vanguard","Rider"] and not (company and u.id=="lyra")
 var slender=appearance.get("slender",u.id in ["lyra","sera","mara","nell","esme","faye","vela","una","petra","noor","yuna","rhea"] if company else false)
 var cape_color=Color(appearance.get("cape","e5dfce" if company and u.id in ["lyra","ivo"] else tint.darkened(.25).to_html(false)))
 actor.set_meta("costume_colors",{"cloth":blue,"cape":cape_color})
 var torso=joint(body,"Torso",Vector3(0,.1,0))
 var pelvis=ellipsoid(body,Actor.PELVIS_CENTER,Actor.PELVIS_RADII,Color("3c3f48"));pelvis.name="Pelvis"
 shell(torso,Vector3.ZERO,[[-.1,.18,.12],[.15,.21,.14],[.35,.245,.12],[.41,.15,.1]],blue)
 if armored:
  var plate=geo.mesh(torso,Cuirass.mesh(),Vector3.ZERO,Vector3.ONE,geo.material(steel));plate.name="Cuirass"
 elif not robe and not (company and u.id=="lyra"):shell(torso,Vector3(0,0,-.04),[[.02,.17,.105],[.22,.21,.12],[.34,.18,.08]],leather)
 geo.cylinder(torso,Vector3(0,-.09,0),.08,.205,leather)
 geo.block(torso,Vector3(0,-.09,-.21),Vector3(.08,.07,.025),gold)
 # Collar, leather harness, chest fittings and layered hems.
 shell(torso,Vector3(0,0,0),[[.36,.095,.085],[.49,.09,.08]],blue)
 for side_value in [-1,1]:
  var piping=geo.block(torso,Vector3(side_value*.08,.39,-.095),Vector3(.018,.14,.015),gold);piping.rotation.z=side_value*.18
 if armored:
  var edging=geo.mesh(torso,Cuirass.trim_mesh(),Vector3.ZERO,Vector3.ONE,geo.material(gold));edging.name="CuirassTrim"
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
  Garments.build(self,body,blue,gold)
 if u.weapon=="bow":
  preload("res://scripts/quiver_visuals.gd").build(self,torso,leather,gold)
 var cape=joint(torso,"Cape",Vector3(0,.35,.12));actor.register_bone("Cape",cape)
 cape_surface(cape,cape_color,company,gold)
 if company and u.id=="lyra":
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
  var boot=geo.mesh(knee,Actor.Boot.mesh(),Vector3(0,-.38,-.07),Vector3.ONE,geo.material(leather)) if actor.shaped_boots else ellipsoid(knee,Vector3(0,-.38,-.07),Vector3(.09,.075,.145),leather)
  boot.name="Boot"
  var arm_name="Arm" if sign_value>0 else "LeftArm"
  var arm=joint(body,arm_name,Vector3(sign_value*(.225 if slender else .27),.4,0));actor.register_bone(arm_name,arm)
  var shoulder_color=steel if armored else blue
  if armored:
   var pauldron=preload("res://scripts/pauldron.gd")
   var plate=geo.mesh(arm,pauldron.mesh(sign_value,heavy),Vector3(sign_value*.025,0,0),Vector3.ONE,geo.material(shoulder_color));plate.name="Pauldron"
   var rim=geo.mesh(arm,pauldron.rim(sign_value,heavy),plate.position,Vector3.ONE,geo.material(gold));rim.name="PauldronRim"
  else:shell(arm,Vector3(sign_value*.025,0,0),[[-.12,.095,.13],[.02,.11,.15],[.10,.09,.09]],shoulder_color)
  geo.cylinder(arm,Vector3(0,-.14,0),.28,.07,Color("69717a") if armored else blue,.085)
  var elbow=joint(arm,"Elbow",Vector3(0,-.29,0));actor.register_bone("Elbow" if sign_value>0 else "LeftElbow",elbow)
  ellipsoid(elbow,Vector3.ZERO,Vector3(.073,.073,.073),steel)
  geo.cylinder(elbow,Vector3(0,-.13,0),.25,.068,steel if armored else leather,.055)
  if u.weapon=="magic":
   var palm=joint(elbow,"CastingHand" if sign_value>0 else "BookHand",Vector3(0,-.29,0))
   actor.register_bone("RightHand" if sign_value>0 else "LeftHand",palm)
   var hand_material=geo.material(skin).duplicate();hand_material.set_meta("outline_width",.0015)
   geo.mesh(palm,preload("res://scripts/casting_hand.gd").mesh(sign_value),Vector3.ZERO,Vector3.ONE,hand_material)
  else:
   var glove=geo.mesh(elbow,preload("res://scripts/grip_hand.gd").mesh(sign_value),Vector3(0,-.29,0),Vector3.ONE,geo.material(leather))
   glove.name="GripHand"
  if sign_value==(-1 if u.weapon=="magic" else 1):
   var hand=EquipmentVisuals.build(self,elbow,u.weapon,str(u.get("item","")));actor.register_bone("Weapon",hand)
   if hand.has_node("NockedArrow"):actor.register_bone("NockedArrow",hand.get_node("NockedArrow"))
   if u.weapon=="bow":
    for key in ["BowStringTop","BowStringBottom"]:actor.register_bone(key,hand.get_node(key))
    actor.update_bow()
  elif heavy:
   var shield_shape=preload("res://scripts/knight_shield.gd")
   var shield_joint=joint(elbow,"Shield",Vector3(-.04,-.16,-.17));actor.register_bone("Shield",shield_joint)
   var shield=geo.mesh(shield_joint,shield_shape.body_mesh(),Vector3.ZERO,Vector3.ONE,geo.material(blue));shield.name="ShieldBody"
   var shield_trim=geo.mesh(shield_joint,shield_shape.trim_mesh(),Vector3.ZERO,Vector3.ONE,geo.material(gold));shield_trim.name="ShieldTrim"
 geo.cylinder(body,Vector3(0,.53,0),.15,.075,skin)
 var gaze=joint(body,"Gaze",Vector3(0,.69,0));actor.register_bone("Gaze",gaze)
 var head=joint(gaze,"Head",Vector3.ZERO);head.scale=Vector3(.86,.83,.86);actor.register_bone("Head",head);actor.gaze_motion.bind(actor)
 var head_shape=Head.shape_key(appearance.get("face_shape","tapered"));head.set_meta("face_shape",head_shape)
 var head_skin=geo.mesh(head,Head.mesh(head_shape),Vector3.ZERO,Vector3.ONE,geo.material(skin));head_skin.name="SculptedHead"
 for x in [-.14,.14]:ellipsoid(head,Vector3(x,-.015,0),Vector3(.025,.05,.025),skin)
 if heavy and u.team!="player":
  var helmet=preload("res://scripts/knight_helmet.gd")
  var shell_mesh=geo.mesh(head,helmet.mesh(),Vector3.ZERO,Vector3.ONE,geo.material(steel));shell_mesh.name="HelmetShell"
  var lining_material=geo.material(Color("252c38")).duplicate();lining_material.set_meta("no_character_outline",true)
  var liner=geo.mesh(head,helmet.visor_lining(),Vector3.ZERO,Vector3.ONE,lining_material);liner.name="HelmetLining"
  var nasal=geo.mesh(head,helmet.nasal_trim(),Vector3.ZERO,Vector3.ONE,geo.material(gold));nasal.name="HelmetNasal"
 else:
  Hair.build(self,head,appearance,gold)
  var loose_hair=head.get_node_or_null("HairFall")
  if loose_hair!=null:
   actor.register_bone("HairFall",loose_hair);actor.hair_motion.bind(actor,str(u.id))
  var face_index={"lyra":0,"sera":1,"mara":3,"nell":2,"esme":2,"faye":3,"vela":1,"una":0,"petra":3,"noor":2,"yuna":1,"rhea":0,"oren":5,"ivo":4,"tarin":6,"bram":4,"rook":5,"cassian":6,"dax":5,"silas":6,"ari":4,"galen":7,"hale":7,"elian":6}.get(u.id,5)
  if not company:face_index=int(appearance.get("face_variant",5))
  var face=face_surface(head,face_index,head_shape)
  actor.face_blink.bind(face,face_atlas,str(u.team)+":"+str(u.id)+":"+str(u.job))
  if company and u.id=="petra":
   for x in [-.07,.07]:
    var rim=geo.cylinder(head,Vector3(x,.13,-.10),.035,.05,gold);rim.rotation.x=PI/2
    var lens=geo.cylinder(head,Vector3(x,.13,-.122),.015,.037,Color("445d6b"));lens.rotation.x=PI/2
 if u.team=="enemy":EnemyHeadgear.build(self,head,u.job,steel,gold,appearance)
 if u.job=="Rider":
  actor.mounted=true
  for name_value in ["Body","LeftLeg","RightLeg"]:
   actor.bones[name_value].position.y+=.75
   actor.rest[name_value].position=actor.bones[name_value].position
  Mount.build(self,actor,u.id if company else "enemy_rider",blue,gold,leather)
 PromotionCostume.build(self,actor,u,torso,blue,cape_color,steel,gold,leather)
 apply_surfaces(actor,blue,tint,skin,steel,gold,leather,cape_color)
 if batching_enabled:batch_rig(actor)
 else:
  Outline.apply(actor);actor.cape_motion.bind(actor)
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
 Outline.apply(actor)
 actor.cape_motion.bind(actor)

func cape_surface(parent,color,company=true,thread=Color("bca26b")):
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
 var cape_mesh=geo.mesh(parent,st.commit(),Vector3.ZERO,Vector3.ONE,material)
 cape_mesh.set_meta("cape_mark",COMPANY_CAPE if company else IMPERIAL_CAPE)
 cape_mesh.set_meta("cape_trim",thread.darkened(.35) if color.get_luminance()>.55 else thread.lightened(.10))
 cape_mesh.set_meta("cape_fabric",true);cape_mesh.extra_cull_margin=preload("res://scripts/cape_motion.gd").MARGIN

func shell(parent,p,sections,color):
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in range(sections.size()-1):
  for side in range(8):
   var points=[];var uvs=[]
   for corner in [[row,side],[row,side+1],[row+1,side+1],[row+1,side]]:
    var section=sections[corner[0]];var angle=corner[1]*TAU/8
    points.append(Vector3(cos(angle)*section[1],section[0],sin(angle)*section[2]))
    uvs.append(Vector2(corner[1]/8.0,corner[0]/float(sections.size()-1)))
   for index in [0,1,2,0,2,3]:st.set_uv(uvs[index]);st.add_vertex(points[index])
 st.generate_normals()
 var result=geo.mesh(parent,st.commit(),p,Vector3.ONE,geo.material(color));result.set_meta("costume_shell",true)
 return result

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

func glove_surface() -> ShaderMaterial:
 if not surface_cache.has("glove"):
  var surface=painted(Color("b1a797"),3).duplicate();surface.set_meta("outline_width",.0015)
  surface_cache.glove=surface
 return surface_cache.glove

func apply_surfaces(root,blue,tint,skin,steel,gold,leather,cape_color):
 for mesh in root.find_children("*","MeshInstance3D",true,false):
  var material=mesh.material_override
  if not material is StandardMaterial3D:continue
  var color=material.albedo_color
  if mesh.name=="GripHand":mesh.material_override=glove_surface()
  elif color==steel:mesh.material_override=painted(Color("d3d7dc") if steel==Color("a8b3bb") else steel.lightened(.12),1,true)
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

  if mesh.get_meta("cape_fabric",false) and mesh.material_override is ShaderMaterial:
   mesh.material_override=mesh.material_override.duplicate()
   mesh.material_override.set_shader_parameter("cloth_amount",1.0)
   mesh.material_override.set_shader_parameter("cape_mark",mesh.get_meta("cape_mark"))
   mesh.material_override.set_shader_parameter("cape_trim",mesh.get_meta("cape_trim"))

func equipment_profile(unit: Dictionary) -> Dictionary:
 return EquipmentVisuals.profiles[EquipmentVisuals.resolve(unit.weapon,str(unit.get("item","")))]

func face_surface(parent,index,shape="tapered"):
 parent.set_meta("face_variant",index)
 var visual=geo.mesh(parent,Head.features(index,shape),Vector3.ZERO,Vector3.ONE,null);visual.name="PaintedFace";visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 return visual

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
