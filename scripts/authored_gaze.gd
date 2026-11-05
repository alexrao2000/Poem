extends Node
# Bound the attention cone in actor space, then let Godot solve the head bone.
# Actor-space limits avoid confusing the source rig's rotated neck rest axes
# with anatomical yaw/pitch. Reactions retain their complete authored head pose.
const TRACKING=["idle","advance","windup","critical_windup","strike","recover","guard"]
const YAW=.45
const PITCH=.32
var model: Node3D
var rig: Skeleton3D
var head=-1
var modifier: LookAtModifier3D
var target: Marker3D
var opponent: WeakRef
var pose_name="idle"

func configure(body: Node3D,skeleton: Skeleton3D):
 model=body;rig=skeleton;head=rig.find_bone("Head")
 target=Marker3D.new();target.name="GazeTarget";model.add_child(target)
 modifier=LookAtModifier3D.new();modifier.name="OpponentGaze";rig.add_child(modifier)
 modifier.active=false;modifier.influence=0;modifier.bone_name="Head"
 modifier.forward_axis=SkeletonModifier3D.BONE_AXIS_PLUS_Z
 # Rotating this bone never moves its own origin; no child feedback is used.
 modifier.origin_from=LookAtModifier3D.ORIGIN_FROM_SPECIFIC_BONE;modifier.origin_bone_name="Head"
 modifier.use_angle_limitation=false
 modifier.duration=.12;modifier.target_node=modifier.get_path_to(target)

func face_opponent(other: Node3D):opponent=weakref(other) if other!=null else null

func combat_pose(key: String):
 pose_name=key
 if key not in TRACKING:release()

func release():
 if is_instance_valid(modifier):modifier.active=false;modifier.influence=0

func _process(delta):
 if not is_instance_valid(model) or not model.is_inside_tree():return
 var actor=model.get_parent() as Node3D
 var other=opponent.get_ref() if opponent!=null else null
 if actor==null or not actor.is_visible_in_tree() or pose_name not in TRACKING or not is_instance_valid(other) or not other.is_inside_tree() or not other.is_visible_in_tree():release();return
 var point=other.socket_position("gaze") if other.has_method("socket_position") else other.global_position
 var origin=rig.to_global(rig.get_bone_global_pose(head).origin)
 if not point.is_finite() or origin.distance_squared_to(point)<.01:release();return
 var basis=actor.global_basis.orthonormalized();var direction=basis.inverse()*(point-origin)
 if direction.z>=0:release();return
 var yaw=clampf(atan2(-direction.x,-direction.z),-YAW,YAW)
 var pitch=clampf(atan2(direction.y,Vector2(direction.x,direction.z).length()),-PITCH,PITCH)
 var bounded=Vector3(-sin(yaw)*cos(pitch),sin(pitch),-cos(yaw)*cos(pitch))
 target.global_position=origin+basis*bounded*2.0
 modifier.active=true;modifier.influence=lerpf(modifier.influence,1.0,1.0-exp(-maxf(0,delta)*11.0))

func _exit_tree():
 release()
 if is_instance_valid(modifier):modifier.target_node=NodePath("")
