extends Node3D
# Presentation adapter for authored scenes. The simulation owns all combat outcomes.
var pose_name="idle"
var kind="sword"
var player: AnimationPlayer
var model: Node3D
var poses: Dictionary={}
var sockets: Dictionary={}
var pose_tween: Tween

func configure(scene: Node3D,spec: Dictionary) -> String:
 model=scene;add_child(model)
 model.scale=Vector3.ONE*float(spec.get("scale",1.0))
 model.rotation.y=deg_to_rad(float(spec.get("yaw",0.0)))
 var offset=spec.get("offset",[0,0,0]);model.position=Vector3(offset[0],offset[1],offset[2])
 player=model.get_node_or_null(NodePath(spec.get("player","AnimationPlayer"))) as AnimationPlayer
 if player==null:return "AnimationPlayer path is missing"
 # Loop flags belong to each instance; two actors may share the same source clip.
 for library_name in player.get_animation_library_list():
  var library=player.get_animation_library(library_name).duplicate(true)
  player.remove_animation_library(library_name);player.add_animation_library(library_name,library)
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
 return ""

func number(value) -> bool:
 return (value is float or value is int) and is_finite(float(value))

func pose(key: String,duration=.18) -> Tween:
 if pose_tween and pose_tween.is_valid():pose_tween.kill()
 pose_name=key
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
 pose_tween=create_tween();pose_tween.tween_interval(seconds)
 if not looping:pose_tween.tween_callback(func():player.seek(mapping.to,true,true);player.pause())
 return pose_tween

func socket_position(key: String) -> Vector3:
 if sockets.has(key):return sockets[key].global_position
 if key=="gaze":return socket_position("impact")+Vector3.UP*.55
 return global_position+Vector3(0,1.2 if key=="projectile" else 1.1,0)

func weapon_trail_points() -> PackedVector3Array:
 if not sockets.has("trail_inner") or not sockets.has("trail_tip"):return PackedVector3Array()
 return PackedVector3Array([sockets.trail_inner.global_position,sockets.trail_tip.global_position])
