extends Node3D
# Original recruit identity layered over the licensed body. Source resources and
# the campaign record stay untouched; all expression/material state is private.
const DYED=preload("res://assets/shaders/authored-cloth.gdshader")
const FaceBlink=preload("res://scripts/face_blink.gd")
@export var cloak_cut="forked"
@export var robe_enabled=false
@export var mantle_enabled=false
@export var armor_enabled=false
@export var light_armor=false
@export var enemy_job=""
var armor: Node
@export_range(.75,1.5) var mantle_depth=1.0
var mantle: Node
var robe: Node
var identity=""
var blink=FaceBlink.new()
var current_pose="idle"
var hair_motion=preload("res://scripts/hair_motion.gd").new()
var elapsed=0.0
var source_meshes=[]
var painted_materials=[]
var head: Node3D
var gaze: Node
var cloak: Node
var outline: Node
static var reference_cache={}

func configure_identity(id: String) -> String:
 if not identity.is_empty():return "Identity is already configured"
 var painter=load("res://scripts/fighters.gd").new()
 if enemy_job.is_empty() and not painter.profiles.has(id):return "Unknown character identity: "+id
 if not enemy_job.is_empty() and not painter.enemy_looks.has(enemy_job):return "Unknown enemy class: "+enemy_job
 var model=get_parent();var rig=model.get_node_or_null("Rig/Armature/Skeleton3D") as Skeleton3D
 var face_anchor=model.get_node_or_null("Rig/Armature/Skeleton3D/Face") as BoneAttachment3D
 if rig==null or face_anchor==null:return "The source identity needs its head attachment"
 var appearance=painter.profiles[id].appearance if enemy_job.is_empty() else painter.enemy_looks[enemy_job]
 var skin=Color(appearance.skin);var cloth=Color(appearance.cloth)
 identity=id;model.set_meta("character_identity",id)
 if not enemy_job.is_empty():model.set_meta("enemy_appearance",enemy_job)
 var source_head: MeshInstance3D
 for mesh in rig.find_children("*","MeshInstance3D",true,false):
  if str(mesh.name).begins_with("Head_") or str(mesh.name).begins_with("Hair_"):
   if str(mesh.name).begins_with("Head_") and str(mesh.name) not in ["Head_Eyes","Head_Eyebrows"]:source_head=mesh
   source_meshes.append(mesh);mesh.hide();continue
  if mesh.mesh==null:continue
  for surface in range(mesh.mesh.get_surface_count()):
   var material=mesh.get_active_material(surface) as StandardMaterial3D
   if material==null or material.albedo_texture==null:continue
   var mode=0
   if material.resource_name.contains("Regular_Male"):mode=3
   elif material.resource_name.contains("Peasant"):
    if str(mesh.name).ends_with("_Legs"):mode=2
    elif str(mesh.name).ends_with("_Body") or str(mesh.name).ends_with("_Arms"):mode=1
   if mode==0:continue
   var dyed=ShaderMaterial.new();dyed.shader=DYED
   dyed.set_shader_parameter("albedo_map",material.albedo_texture)
   dyed.set_shader_parameter("has_normal",material.normal_texture!=null)
   if material.normal_texture!=null:dyed.set_shader_parameter("normal_map",material.normal_texture)
   dyed.set_shader_parameter("tint",skin if mode==3 else cloth)
   dyed.set_shader_parameter("dye_mode",mode)
   if mode==2:dyed.set_shader_parameter("dye_detail",.35)
   dyed.set_shader_parameter("reference_luma",reference_luma(mesh.mesh,surface,material.albedo_texture,mode))
   dyed.set_meta("identity",id);dyed.set_meta("dye_mode",mode)
   mesh.set_surface_override_material(surface,dyed);painted_materials.append(dyed)
 head=painter.joint(face_anchor,"PortraitHead",Vector3(0,.105,.005));head.rotation.y=PI;head.scale=Vector3(.84,.84,.84)
 var shape=painter.Head.shape_key(appearance.get("face_shape","tapered"));head.set_meta("face_shape",shape)
 var skull=painter.geo.mesh(head,painter.Head.mesh(shape),Vector3.ZERO,Vector3.ONE,painter.geo.material(skin));skull.name="SculptedHead"
 for x in [-.14,.14]:painter.ellipsoid(head,Vector3(x,-.015,0),Vector3(.025,.05,.025),skin)
 painter.Hair.build(painter,head,appearance,Color("bca26b"))
 if not enemy_job.is_empty():painter.EnemyHeadgear.build(painter,head,enemy_job,Color(appearance.get("steel","a8b3bb")),Color(appearance.get("metal","bca26b")),appearance)
 var face_index=painter.FACE_INDICES.get(id,5) if enemy_job.is_empty() else int(appearance.get("face_variant",5))
 var face=painter.face_surface(head,face_index,shape)
 face.set_meta("dynamic",true)
 blink.bind(face,painter.face_atlas,"authored:"+id)
 painter.geo.batcher.combine(head,false)
 hair_motion.bind_root(head.get_node_or_null("HairFall"),id)
 if source_head==null:return "Source neck mesh is missing"
 var neck_mesh=preload("res://scripts/authored_neck.gd").mesh_for(source_head,rig)
 if neck_mesh==null:return "Source neck skin could not be isolated"
 var neck=MeshInstance3D.new();neck.name="PortraitNeck";neck.mesh=neck_mesh;neck.skin=source_head.skin;neck.skeleton=source_head.skeleton;neck.transform=source_head.transform;rig.add_child(neck)
 var source_skin=source_head.get_active_material(0) as StandardMaterial3D
 if source_skin==null or source_skin.albedo_texture==null:return "Source neck material is missing"
 var neck_material=ShaderMaterial.new();neck_material.shader=DYED;neck_material.set_shader_parameter("albedo_map",source_skin.albedo_texture)
 neck_material.set_shader_parameter("normal_map",source_skin.normal_texture);neck_material.set_shader_parameter("has_normal",source_skin.normal_texture!=null)
 neck_material.set_shader_parameter("tint",skin);neck_material.set_shader_parameter("dye_mode",3)
 neck_material.set_shader_parameter("reference_luma",reference_luma(neck_mesh,0,source_skin.albedo_texture,3))
 neck_material.set_meta("identity",id);neck_material.set_meta("dye_mode",3);neck.material_override=neck_material;painted_materials.append(neck_material)
 cloak=preload("res://scripts/authored_cloak.gd").new();cloak.name="CloakDriver";add_child(cloak);cloak.configure(model,rig,painter,appearance,cloak_cut,enemy_job.is_empty())
 if mantle_enabled:
  mantle=preload("res://scripts/authored_mantle.gd").new();mantle.name="MantleDriver";add_child(mantle);mantle.configure(model,rig,painter,appearance,mantle_depth)
 if robe_enabled:
  robe=preload("res://scripts/authored_robe.gd").new();robe.name="RobeDriver";add_child(robe);robe.configure(model,rig,painter,appearance)
 if armor_enabled:
  armor=preload("res://scripts/authored_armor.gd").new();armor.name="ArmorDriver";add_child(armor);armor.configure(model,rig,painter,appearance,light_armor)
 gaze=preload("res://scripts/authored_gaze.gd").new();gaze.name="GazeDriver";add_child(gaze);gaze.configure(model,rig)
 outline=preload("res://scripts/authored_outline.gd").new();outline.name="OutlineDriver";add_child(outline)
 var copies=outline.configure(model)
 for listener in model.find_children("*","",true,false):
  if listener.has_method("materials_remapped"):listener.materials_remapped(copies)
 return ""

static func reference_luma(mesh: Mesh,surface: int,texture: Texture2D,mode: int) -> float:
 var key=(mesh.resource_path if not mesh.resource_path.is_empty() else str(mesh.get_instance_id()))+":"+str(surface)+":"+texture.resource_path+":"+str(mode)
 if reference_cache.has(key):return reference_cache[key]
 var image=texture.get_image();var total=0.0;var count=0
 if image!=null:
  if image.is_compressed():image.decompress()
  var uv=mesh.surface_get_arrays(surface)[Mesh.ARRAY_TEX_UV]
  var stride=maxi(1,uv.size()/256)
  for index in range(0,uv.size(),stride):
   var point=uv[index];var pixel=image.get_pixel(mini(image.get_width()-1,int(fposmod(point.x,1)*image.get_width())),mini(image.get_height()-1,int(fposmod(point.y,1)*image.get_height()))).srgb_to_linear()
   var warmth=maxf(pixel.r-pixel.b,0)/maxf(pixel.r,.01)
   if mode==1 and warmth>.80:continue
   total+=pixel.r*.2126+pixel.g*.7152+pixel.b*.0722;count+=1
 var result=maxf(.005,total/count) if count>0 else .2
 reference_cache[key]=result;return result

func materials_remapped(copies: Dictionary):
 blink.surface=copies.get(blink.surface,blink.surface)
 for index in range(painted_materials.size()):painted_materials[index]=copies.get(painted_materials[index],painted_materials[index])

func combat_pose(key: String):current_pose=key;blink.begin_pose(key)
func face_opponent(other: Node3D):blink.opponent=weakref(other)
func _process(delta):
 if identity.is_empty() or not is_visible_in_tree():return
 elapsed+=maxf(0,delta);blink.update(delta,current_pose);hair_motion.update(elapsed,current_pose,delta)
