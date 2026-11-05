extends SkeletonModifier3D
# Exact two-bone prop support after animation. The target follows the current
# chest pose, avoiding a one-frame delay from its visual bone attachment.
const Rotation=preload("res://scripts/skeletal_contact.gd")
var rig: Skeleton3D
var chain: Array[int]=[]
var chest=-1
var target: Transform3D
var attachments=[]

func configure(skeleton: Skeleton3D,goal: Transform3D):
 rig=skeleton;target=goal;chest=rig.find_bone("spine_03")
 for name_value in ["hand_r","lowerarm_r","upperarm_r"]:chain.append(rig.find_bone(name_value))
 attachments=rig.find_children("*","BoneAttachment3D",true,false)

func aim(bone: int,basis: Basis):
 var parent=rig.get_bone_global_pose(rig.get_bone_parent(bone))
 rig.set_bone_pose_rotation(bone,(parent.basis.inverse()*basis).get_rotation_quaternion().normalized());rig.force_update_bone_child_transform(bone)

func target_pose() -> Transform3D:return rig.get_bone_global_pose(chest)*target

func solve() -> Array[Quaternion]:
 var originals: Array[Quaternion]=[]
 for bone in chain:originals.append(rig.get_bone_pose_rotation(bone))
 var desired=target_pose()
 var upper=rig.get_bone_global_pose(chain[2]);var elbow=rig.get_bone_global_pose(chain[1]);var hand=rig.get_bone_global_pose(chain[0])
 var a=upper.origin.distance_to(elbow.origin);var b=elbow.origin.distance_to(hand.origin)
 var axis=desired.origin-upper.origin;var distance=axis.length()
 if distance<.00001:return originals
 axis/=distance;distance=clampf(distance,absf(a-b)+.0001,a+b-.0001)
 var wrist=upper.origin+axis*distance
 var pole=desired.basis.z;pole-=axis*pole.dot(axis)
 if pole.length_squared()<.000001:pole=desired.basis.x;pole-=axis*pole.dot(axis)
 var along=(a*a-b*b+distance*distance)/(2*distance)
 var bend=upper.origin+axis*along+pole.normalized()*sqrt(maxf(0,a*a-along*along))
 aim(chain[2],Basis(Rotation.rotation_between(elbow.origin-upper.origin,bend-upper.origin))*upper.basis)
 elbow=rig.get_bone_global_pose(chain[1]);hand=rig.get_bone_global_pose(chain[0])
 aim(chain[1],Basis(Rotation.rotation_between(hand.origin-elbow.origin,wrist-elbow.origin))*elbow.basis)
 aim(chain[0],desired.basis)
 return originals

func _process_modification_with_delta(_delta):
 if is_instance_valid(rig) and rig.is_inside_tree():solve()

func sample_attachments():
 if not is_instance_valid(rig) or not rig.is_inside_tree() or not active or influence<=0:return
 var originals=solve()
 for index in range(chain.size()):rig.set_bone_pose_rotation(chain[index],originals[index].slerp(rig.get_bone_pose_rotation(chain[index]),influence))
 rig.force_update_all_bone_transforms()
 for attachment in attachments:attachment.on_skeleton_update()
 for index in range(chain.size()):rig.set_bone_pose_rotation(chain[index],originals[index])
