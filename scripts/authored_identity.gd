extends Node3D
# Original recruit identity layered over the licensed body. Source resources and
# the campaign record stay untouched; all expression/material state is private.
const DYED=preload("res://assets/shaders/authored-cloth.gdshader")
const FaceBlink=preload("res://scripts/face_blink.gd")
var identity=""
var blink=FaceBlink.new()
var current_pose="idle"
var source_meshes=[]
var painted_materials=[]
var head: Node3D
static var reference_cache={}

func configure_identity(id: String) -> String:
 if not identity.is_empty():return "Identity is already configured"
 var painter=load("res://scripts/fighters.gd").new()
 if not painter.profiles.has(id):return "Unknown character identity: "+id
 var model=get_parent();var rig=model.get_node_or_null("Rig/Armature/Skeleton3D") as Skeleton3D
 var face_anchor=model.get_node_or_null("Rig/Armature/Skeleton3D/Face") as BoneAttachment3D
 if rig==null or face_anchor==null:return "The source identity needs its head attachment"
 var appearance=painter.profiles[id].appearance
 var skin=Color(appearance.skin);var cloth=Color(appearance.cloth)
 identity=id;model.set_meta("character_identity",id)
 for mesh in rig.find_children("*","MeshInstance3D",true,false):
  if str(mesh.name).begins_with("Head_") or str(mesh.name).begins_with("Hair_"):
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
   dyed.set_shader_parameter("reference_luma",reference_luma(mesh.mesh,surface,material.albedo_texture,mode))
   dyed.set_meta("identity",id);dyed.set_meta("dye_mode",mode)
   mesh.set_surface_override_material(surface,dyed);painted_materials.append(dyed)
 head=painter.joint(face_anchor,"PortraitHead",Vector3(0,.105,.005));head.rotation.y=PI;head.scale=Vector3(.84,.84,.84)
 var shape=painter.Head.shape_key(appearance.get("face_shape","tapered"));head.set_meta("face_shape",shape)
 var skull=painter.geo.mesh(head,painter.Head.mesh(shape),Vector3.ZERO,Vector3.ONE,painter.geo.material(skin));skull.name="SculptedHead"
 for x in [-.14,.14]:painter.ellipsoid(head,Vector3(x,-.015,0),Vector3(.025,.05,.025),skin)
 painter.Hair.build(painter,head,appearance,Color("bca26b"))
 var face=painter.face_surface(head,painter.FACE_INDICES.get(id,5),shape)
 face.set_meta("dynamic",true)
 blink.bind(face,painter.face_atlas,"authored:"+id)
 painter.geo.batcher.combine(head,false)
 var neck=painter.geo.cylinder(face_anchor,Vector3(0,-.03,0),.15,.064,skin);neck.name="PortraitNeck"
 return ""

static func reference_luma(mesh: Mesh,surface: int,texture: Texture2D,mode: int) -> float:
 var key=str(mesh.get_instance_id())+":"+str(surface)+":"+texture.resource_path+":"+str(mode)
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

func combat_pose(key: String):current_pose=key;blink.begin_pose(key)
func face_opponent(other: Node3D):blink.opponent=weakref(other)
func _process(delta):
 if not identity.is_empty():blink.update(delta,current_pose)
