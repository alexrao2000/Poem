extends SkeletonModifier3D
# Presentation-only arm correction after the authored animation. The fixed
# weapon grip and bone lengths are preserved; no gameplay reach is changed.
var rig: Skeleton3D
var chain: Array[int]=[]
var endpoint=Vector3.ZERO
var inner_endpoint=Vector3.ZERO
var tip_endpoint=Vector3.ZERO
var target=Vector3.ZERO
var has_target=false
var attachments=[]
const LIMITS=[1.35,1.65,1.15]

func configure(skeleton: Skeleton3D,names: Array,inner: Node3D,tip: Node3D) -> String:
 rig=skeleton
 for name_value in names:
  var index=rig.find_bone(name_value)
  if index<0:return "Missing contact bone: "+str(name_value)
  chain.append(index)
 if chain.size()!=3:return "Contact correction needs wrist, elbow and upper arm"
 if rig.get_bone_parent(chain[0])!=chain[1] or rig.get_bone_parent(chain[1])!=chain[2]:return "Contact bones must form a direct arm chain"
 for socket in [inner,tip]:
  var attachment=socket.get_parent()
  while attachment!=null and not attachment is BoneAttachment3D:attachment=attachment.get_parent()
  if attachment==null or attachment.get_skeleton()!=rig or attachment.bone_idx!=chain[0]:return "Contact blade sockets must follow the configured wrist"
 rig.force_update_all_bone_transforms()
 for attachment in rig.find_children("*","BoneAttachment3D",true,false):attachment.on_skeleton_update()
 var inverse=rig.get_bone_global_pose(chain[0]).affine_inverse()
 tip_endpoint=inverse*rig.to_local(tip.global_position)
 inner_endpoint=inverse*rig.to_local(inner.global_position)
 if inner_endpoint.distance_to(tip_endpoint)<.01:return "Contact blade sockets must be distinct"
 endpoint=tip_endpoint
 attachments=rig.find_children("*","BoneAttachment3D",true,false)
 influence=0.0
 return ""

func solve() -> Array[Quaternion]:
 var originals: Array[Quaternion]=[]
 for bone in chain:originals.append(rig.get_bone_pose_rotation(bone))
 if not has_target:return originals
 var destination=rig.to_local(target)
 # Nearby targets meet the solid blade, rather than forcing its very tip to
 # the chest by over-folding the wrist. Both endpoints remain fixed in the grip.
 var hand_target=rig.get_bone_global_pose(chain[0]).affine_inverse()*destination
 var edge=tip_endpoint-inner_endpoint
 endpoint=inner_endpoint+edge*clampf((hand_target-inner_endpoint).dot(edge)/edge.length_squared(),0,1)
 seed_arm(destination,originals)
 for iteration in range(100):
  var tip=rig.get_bone_global_pose(chain[0])*endpoint
  if tip.distance_squared_to(destination)<.000001:break
  for joint in range(chain.size()):
   var bone=chain[joint];var pose=rig.get_bone_global_pose(bone)
   tip=rig.get_bone_global_pose(chain[0])*endpoint
   var toward_tip=tip-pose.origin;var toward_target=destination-pose.origin
   if toward_tip.length_squared()<.0000001 or toward_target.length_squared()<.0000001:continue
   aim_joint(joint,Basis(rotation_between(toward_tip,toward_target))*pose.basis,originals)
 return originals

static func rotation_between(from: Vector3,to: Vector3) -> Quaternion:
 var a=from.normalized();var b=to.normalized();var cross=a.cross(b);var dot=clampf(a.dot(b),-1,1)
 if cross.length_squared()>.000000000001:return Quaternion(cross.normalized(),atan2(cross.length(),dot))
 if dot>=0:return Quaternion.IDENTITY
 var axis=a.cross(Vector3.UP)
 if axis.length_squared()<.0001:axis=a.cross(Vector3.RIGHT)
 return Quaternion(axis.normalized(),PI)

func aim_joint(joint: int,basis: Basis,originals: Array[Quaternion]):
 var bone=chain[joint]
 var parent_pose=rig.get_bone_global_pose(rig.get_bone_parent(bone))
 var local=(parent_pose.basis.inverse()*basis).get_rotation_quaternion().normalized()
 var angle=originals[joint].angle_to(local)
 if angle>LIMITS[joint]:local=originals[joint].slerp(local,LIMITS[joint]/angle)
 rig.set_bone_pose_rotation(bone,local);rig.force_update_bone_child_transform(bone)

func seed_arm(destination: Vector3,originals: Array[Quaternion]):
 # Solve the two arm lengths first, preserving the authored elbow side. This
 # avoids slow wrist-first convergence near a fully extended source pose.
 var upper=rig.get_bone_global_pose(chain[2]);var elbow=rig.get_bone_global_pose(chain[1]);var hand=rig.get_bone_global_pose(chain[0])
 var desired_basis=Basis(rotation_between(hand.basis*endpoint,destination-hand.origin))*hand.basis
 var wrist=destination-desired_basis*endpoint
 var upper_length=upper.origin.distance_to(elbow.origin);var lower_length=elbow.origin.distance_to(hand.origin)
 var axis=wrist-upper.origin;var distance=axis.length()
 if distance<.00001:return
 axis/=distance
 distance=clampf(distance,absf(upper_length-lower_length)+.0001,upper_length+lower_length-.0001)
 wrist=upper.origin+axis*distance
 var pole=elbow.origin-upper.origin;pole-=axis*pole.dot(axis)
 if pole.length_squared()<.000001:pole=axis.cross(upper.basis.z)
 if pole.length_squared()<.000001:pole=axis.cross(upper.basis.x)
 var along=(upper_length*upper_length-lower_length*lower_length+distance*distance)/(2*distance)
 var height=sqrt(maxf(0,upper_length*upper_length-along*along))
 var bend=upper.origin+axis*along+pole.normalized()*height
 aim_joint(2,Basis(rotation_between(elbow.origin-upper.origin,bend-upper.origin))*upper.basis,originals)
 elbow=rig.get_bone_global_pose(chain[1]);hand=rig.get_bone_global_pose(chain[0])
 aim_joint(1,Basis(rotation_between(hand.origin-elbow.origin,wrist-elbow.origin))*elbow.basis,originals)
 aim_joint(0,desired_basis,originals)

func _process_modification_with_delta(_delta):
 if is_instance_valid(rig) and rig.is_inside_tree() and has_target and influence>0:solve()

func sample_attachments():
 # Direct seek/contact queries occur before the deferred modifier pass. Sample
 # the same corrected pose into attachments, then restore the animation input.
 if not is_instance_valid(rig) or not rig.is_inside_tree() or not has_target or influence<=0:return
 var originals=solve()
 for index in range(chain.size()):
  var bone=chain[index]
  rig.set_bone_pose_rotation(bone,originals[index].slerp(rig.get_bone_pose_rotation(bone),influence))
 rig.force_update_all_bone_transforms()
 for attachment in attachments:attachment.on_skeleton_update()
 for index in range(chain.size()):rig.set_bone_pose_rotation(chain[index],originals[index])

func _exit_tree():has_target=false
