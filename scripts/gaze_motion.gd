extends RefCounted
## A separate neck joint follows the opponent without overwriting authored
## head poses. Targets are weak references; the actor owns pause/visibility.
var neck: Node3D
var target: WeakRef
var rotation=Vector2.ZERO

func bind(actor: Node3D):
 neck=actor.bone("Gaze")

func face_opponent(other: Node3D):
 target=weakref(other) if other!=null else null

func update(pose: String,delta: float):
 if neck==null or not is_instance_valid(neck):return
 var goal=Vector2.ZERO
 var other=target.get_ref() if target!=null else null
 if is_instance_valid(other) and other.is_inside_tree() and pose not in ["hit","evade","down","victory"]:
  var point=other.socket_position("gaze")
  var direction=neck.get_parent().to_local(point)-neck.position
  if direction.length_squared()>.0001:
   var pitch=atan2(direction.y,Vector2(direction.x,direction.z).length())
   var yaw=atan2(-direction.x,-direction.z)
   goal=Vector2(clampf(pitch,-.32,.32),clampf(yaw,-.45,.45))
 rotation=rotation.lerp(goal,1.0-exp(-maxf(0,delta)*11.0))
 neck.rotation=Vector3(rotation.x,rotation.y,0)
