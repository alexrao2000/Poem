extends "res://scripts/weapon_floor.gd"
# Both arms are solved together so direct samples preserve the same skeleton
# state as the native modifier. The right hand carries; the left draws/releases.
var bow: Node3D
var right_chain: Array[int]=[]
var left_chain: Array[int]=[]
var solving_left=false
var torso=-1
var head=-1
var aim_point=Vector3.ZERO
var has_aim=false

func setup(skeleton: Skeleton3D,equipment: Node3D):
 torso=skeleton.find_bone("spine_03");head=skeleton.find_bone("Head")
 configure(skeleton,Transform3D.IDENTITY);right_chain=chain.duplicate();bow=equipment
 for name_value in ["hand_l","lowerarm_l","upperarm_l"]:left_chain.append(rig.find_bone(name_value))
 chain.append_array(left_chain);chain.append(torso);chain.append(head)
 fit_prop(bow.get_parent(),bow.get_node("Weapon"))

func clear_floor(desired: Transform3D) -> Transform3D:
 if corners.is_empty() or not is_instance_valid(model) or not model.is_inside_tree():return desired
 var world=rig.global_transform*desired;var floor_y=model.get_parent().global_position.y+.018
 var lift_needed=floor_y-minimum_height(world)
 if lift_needed<=0:return desired
 world.origin.y+=lift_needed
 # Preserve the animated wrist orientation. Pull inward only when raising the
 # hand would exceed the arm's reach; both lengths remain fixed.
 var shoulder=rig.to_global(rig.get_bone_global_pose(right_chain[2]).origin)
 var elbow=rig.to_global(rig.get_bone_global_pose(right_chain[1]).origin)
 var hand=rig.to_global(rig.get_bone_global_pose(right_chain[0]).origin)
 var full_reach=shoulder.distance_to(elbow)+elbow.distance_to(hand)
  # Leave a small bend when retracting a raised hand. Approaching a perfectly
 # straight elbow makes tiny wrist movements cause abrupt joint changes.
 var reach=minf(full_reach-.0002,maxf(shoulder.distance_to(hand),full_reach*.976))
 var offset=world.origin-shoulder
 offset.y=minf(offset.y,reach)
 var horizontal=Vector3(offset.x,0,offset.z);var allowed=sqrt(maxf(0,reach*reach-offset.y*offset.y))
 if horizontal.length()>allowed:horizontal=horizontal.normalized()*allowed
 world.origin=shoulder+horizontal+Vector3.UP*offset.y
 return rig.global_transform.affine_inverse()*world

func target_pose() -> Transform3D:
 if not bow.holding:return clear_floor(rig.get_bone_global_pose(right_chain[0])) if not solving_left else rig.get_bone_global_pose(left_chain[0])
 if solving_left:
  var transform=rig.get_bone_global_pose(right_chain[0])*bow.transform*bow.get_node("Weapon").transform
  var nock=transform*Vector3(0,0,.22+.30*bow.hand_draw)
  # Finger pads sit ahead of the left wrist; the palm faces the bow string.
  var basis=Basis(Vector3.DOWN,Vector3.FORWARD,Vector3.RIGHT)
  return rig.get_bone_global_pose(left_chain[0]).interpolate_with(Transform3D(basis,nock-basis*bow.finger_pad),smoothstep(0,1,bow.lift))
 var shoulder=rig.get_bone_global_pose(right_chain[2]).origin
 var goal=shoulder+Vector3(.05,lerpf(-.30,-.03,bow.lift),lerpf(.18,.40,bow.lift))
 var forward=Vector3.BACK;var basis=Basis.IDENTITY
 for step in range(3):
  var horizontal=Vector3.UP.cross(forward).normalized();var up=forward.cross(horizontal).normalized()
  # Bow +Y follows wrist +Z; its arrow -Z follows wrist +Y.
  basis=Basis(-horizontal,forward,up)
  if has_aim and bow.lift>.01:
   var direction=rig.to_local(aim_point)-(goal+basis*bow.position)
   if direction.length_squared()>.000001 and absf(direction.normalized().dot(Vector3.UP))<.995:forward=direction.normalized()
 return clear_floor(Transform3D(basis,goal))

func bend_pole(desired: Transform3D,upper: Transform3D,elbow: Transform3D) -> Vector3:
 return desired.basis.z if bow.holding else super(desired,upper,elbow)

func solve() -> Array[Quaternion]:
 var combined: Array[int]=right_chain+left_chain;combined.append(torso);combined.append(head);var originals: Array[Quaternion]=[]
 for bone in combined:originals.append(rig.get_bone_pose_rotation(bone))
 var head_basis=rig.get_bone_global_pose(head).basis
 if bow.holding:
  aim(torso,Basis(Vector3.UP,.75*bow.lift)*rig.get_bone_global_pose(torso).basis)
  aim(head,head_basis)
 chain=right_chain;solving_left=false;super()
 chain=left_chain;solving_left=true
 if bow.holding and bow.lift>0:super()
 chain=combined;solving_left=false
 return originals
