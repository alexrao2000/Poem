extends Node3D
# Presentation adapter for authored scenes. The simulation owns all combat outcomes.
var pose_name="idle"
var kind="sword"
var player: AnimationPlayer
var model: Node3D
var poses: Dictionary={}
var sockets: Dictionary={}
var pose_tween: Tween
var skeletons=[]
var attachments=[]
var contact: SkeletonModifier3D
var pose_listeners=[]
var material_listeners=[]
var pose_constraints=[]
signal travel_contact(index: int)
var stride_length=0.0
var stride_contacts=[]
var stride_feet=[]
var stride_skeleton: Skeleton3D
var stride_phase=0.0
var contact_index=0
var travel_previous=Vector3.ZERO
var travel_direction=Vector3.ZERO
var camera_padding={}

func configure(scene: Node3D,spec: Dictionary) -> String:
 model=scene;add_child(model)
 skeletons=model.find_children("*","Skeleton3D",true,false)
 attachments=model.find_children("*","BoneAttachment3D",true,false)
 material_listeners=model.find_children("*","",true,false).filter(func(node):return node.has_method("materials_remapped"))
 pose_listeners=model.find_children("*","",true,false).filter(func(node):return node.has_method("combat_pose"))
 pose_constraints=model.find_children("*","SkeletonModifier3D",true,false).filter(func(node):return node.has_method("sample_attachments"))
 model.scale=Vector3.ONE*float(spec.get("scale",1.0))
 model.rotation.y=deg_to_rad(float(spec.get("yaw",0.0)))
 var offset=spec.get("offset",[0,0,0]);model.position=Vector3(offset[0],offset[1],offset[2])
 player=model.get_node_or_null(NodePath(spec.get("player","AnimationPlayer"))) as AnimationPlayer
 if player==null:return "AnimationPlayer path is missing"
 # Loop flags belong to each instance; two actors may share the same source clip.
 for library_name in player.get_animation_library_list():
  var library=player.get_animation_library(library_name).duplicate(true)
  player.remove_animation_library(library_name);player.add_animation_library(library_name,library)
 if spec.has("equipment"):
  var equipment=model.get_node(NodePath(spec.equipment))
  if equipment.has_method("configure_animations"):
   var error=equipment.configure_animations(player)
   if not error.is_empty():return error
 player.stop();player.autoplay="";player.speed_scale=1.0
 poses=spec.get("poses",{}).duplicate(true)
 for key in ["idle","advance","windup","strike","hit","evade","down"]:
  if not poses.has(key):return "Missing required pose: "+key
 for key in poses:
  var mapping=poses[key]
  if not mapping is Dictionary or not mapping.get("clip") is String:return "Invalid pose: "+str(key)
  if not player.has_animation(mapping.clip):return "Missing animation: "+mapping.clip
  var animation=player.get_animation(mapping.clip)
  var start=mapping.get("from",0.0);var end=mapping.get("to",animation.length)
  if not number(start) or not number(end) or start<0 or end<=start or end>animation.length+.0001:return "Invalid clip interval: "+str(key)
  mapping["from"]=float(start);mapping["to"]=float(end)
 for key in spec.get("sockets",{}):
  var socket=model.get_node_or_null(NodePath(spec.sockets[key])) as Node3D
  if socket==null:return "Missing socket: "+str(key)
  sockets[key]=socket
 var framing=spec.get("framing",{})
 if not framing is Dictionary:return "Model framing must be an object"
 for phase in framing:
  if phase not in ["wide","windup","impact","finish"] or not number(framing[phase]) or framing[phase]<1 or framing[phase]>2:return "Invalid model framing margin"
 camera_padding=framing.duplicate()
 return configure_stride(spec)

func camera_padding_for(phase: String) -> float:return float(camera_padding.get(phase,1.0))

func configure_stride(spec: Dictionary) -> String:
 if not spec.has("stride"):return ""
 var setup=spec.stride
 if not setup is Dictionary or not number(setup.get("length")) or setup.length<=0:return "Stride needs a positive distance per cycle"
 if not setup.get("skeleton") is String or not setup.get("feet") is Array or setup.feet.size()!=2:return "Stride needs a skeleton and two feet"
 if not setup.get("contacts") is Array or setup.contacts.size()!=2:return "Stride needs two contact phases"
 for phase in setup.contacts:
  if not number(phase) or phase<0 or phase>=1:return "Stride contact phases must be in [0, 1)"
 if setup.contacts[0]>=setup.contacts[1]:return "Stride contacts must be ordered and distinct"
 stride_skeleton=model.get_node_or_null(NodePath(setup.skeleton)) as Skeleton3D
 if stride_skeleton==null:return "Stride skeleton is missing"
 for foot in setup.feet:
  if not foot is String:return "Stride foot names must be strings"
  var index=stride_skeleton.find_bone(foot)
  if index<0 or index in stride_feet:return "Stride foot is missing or duplicated"
  stride_feet.append(index)
 stride_length=float(setup.length);stride_contacts=setup.contacts.duplicate()
 return ""

func _process(_delta):
 if pose_name=="advance" and stride_length>0 and is_visible_in_tree():update_locomotion()

func update_locomotion():
 if pose_name!="advance" or stride_length<=0:return
 var displacement=global_position-travel_previous;displacement.y=0
 travel_previous=global_position
 if displacement.length_squared()>.00000001:travel_direction=displacement.normalized()
 advance_stride(displacement.dot(-global_basis.z.normalized()))

func nominal_stride_speed() -> float:
 return stride_length*model.scale.z/(poses.advance.to-poses.advance.from) if stride_length>0 else 0.0

func advance_stride(travelled: float):
 if pose_name!="advance" or stride_length<=0 or not is_finite(travelled):return
 var world_length=stride_length*model.global_basis.z.length()
 # A discontinuous relocation is not a string of footfalls.
 if absf(travelled)>world_length*2:return
 var next_phase=stride_phase+travelled/world_length
 var crossings=0
 for phase in stride_contacts:crossings+=absi(floori(next_phase-phase)-floori(stride_phase-phase))
 stride_phase=fposmod(next_phase,1.0)
 var mapping=poses.advance
 # Manual seeks alone leave a paused crossfade pinned to its outgoing pose.
 # Advance its blend clock by the clip-time equivalent of actual ground travel.
 player.advance(absf(travelled/world_length)*(mapping.to-mapping.from))
 player.seek(lerpf(mapping.from,mapping.to,stride_phase),true,true);player.pause();refresh_skeleton()
 for step in range(crossings):travel_contact.emit(contact_index);contact_index+=1

func ground_contact_position() -> Vector3:
 if stride_skeleton==null:return global_position
 var point=Vector3(0,INF,0)
 for index in stride_feet:
  var foot=stride_skeleton.to_global(stride_skeleton.get_bone_global_pose(index).origin)
  if foot.y<point.y:point=foot
 point.y=global_position.y
 return point

func prepare_contact(spec: Dictionary) -> String:
 if not spec.has("contact"):return ""
 var setup=spec.contact
 if not setup is Dictionary or not setup.get("skeleton") is String or not setup.get("bones") is Array:return "Invalid contact configuration"
 if setup.bones.size()!=3 or not setup.bones.all(func(value):return value is String):return "Contact configuration needs three bone names"
 if not sockets.has("trail_tip") or not sockets.has("trail_inner"):return "Contact correction needs blade-edge sockets"
 var rig=model.get_node_or_null(NodePath(setup.skeleton)) as Skeleton3D
 if rig==null:return "Contact skeleton is missing"
 contact=preload("res://scripts/skeletal_contact.gd").new();rig.add_child(contact);pose_constraints.append(contact)
 return contact.configure(rig,setup.bones,sockets.trail_inner,sockets.trail_tip)

func aim_at(point: Vector3):
 if contact!=null and point.is_finite():contact.target=point;contact.has_target=true

func face_opponent(other: Node3D):
 for listener in pose_listeners:
  if listener.has_method("face_opponent"):listener.face_opponent(other)

func remap_materials(copies: Dictionary):
 for listener in material_listeners:listener.materials_remapped(copies)

func number(value) -> bool:
 return (value is float or value is int) and is_finite(float(value))

func finish_flourish(duration=.22) -> Tween:
 return pose("victory_flourish",duration) if poses.has("victory_flourish") else null

func pose(key: String,duration=.18) -> Tween:
 if pose_tween and pose_tween.is_valid():pose_tween.kill()
 pose_name=key
 if key=="advance":travel_previous=global_position;stride_phase=0.0
 for listener in pose_listeners:listener.combat_pose(key)
 if contact!=null and key!="recover":contact.influence=0.0
 var fallback="windup" if key in ["throw_windup","cast_windup","critical_windup","critical_throw_windup"] else "strike" if key in ["throw","cast"] else "idle"
 if key=="critical_hit":fallback="hit"
 if key=="critical_throw_windup" and poses.has("throw_windup"):fallback="throw_windup"
 var mapping=poses.get(key,poses[fallback])
 var animation=player.get_animation(mapping.clip)
 var looping=key in ["idle","advance"]
 animation.loop_mode=Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
 var seconds=maxf(float(duration),.001)
 var speed=1.0 if looping else (mapping.to-mapping.from)/seconds
 player.play_section(mapping.clip,mapping.from,mapping.to,minf(.06,seconds*.25),speed)
 player.seek(mapping.from,true,true)
 if key=="advance" and stride_length>0:player.pause()
 refresh_skeleton()
 pose_tween=create_tween()
 if contact!=null:
  pose_tween.tween_property(contact,"influence",1.0 if key=="strike" and contact.has_target else 0.0,seconds)
 else:pose_tween.tween_interval(seconds)
 if not looping:pose_tween.tween_callback(func():player.seek(mapping.to,true,true);player.pause();refresh_skeleton())
 return pose_tween

func refresh_skeleton():
 # A direct clip seek updates bones before the normal skeleton notification.
 # Synchronize effect/weapon sockets before sampling a held contact or preview.
 for skeleton in skeletons:skeleton.force_update_all_bone_transforms()
 for attachment in attachments:attachment.on_skeleton_update()
 for constraint in pose_constraints:constraint.sample_attachments()

func socket_position(key: String) -> Vector3:
 if sockets.has(key):return sockets[key].global_position
 if key=="guard":return socket_position("impact")
 if key=="gaze":return socket_position("impact")+Vector3.UP*.55
 return global_position+Vector3(0,1.2 if key=="projectile" else 1.1,0)

func weapon_trail_points() -> PackedVector3Array:
 if not sockets.has("trail_inner") or not sockets.has("trail_tip"):return PackedVector3Array()
 return PackedVector3Array([sockets.trail_inner.global_position,sockets.trail_tip.global_position])
