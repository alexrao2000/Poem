extends "res://scripts/lance_hold.gd"
var lance_chain: Array[int]=[]
var legs=[]
var left_arm: Array[int]=[]
var mount: Node3D
func setup(skeleton: Skeleton3D,equipment: Node3D):
 super(skeleton,equipment);lance_chain=chain.duplicate();mount=lance.owner.get_node("Mount")
 for side in ["r","l"]:
  var limb: Array[int]=[]
  for label in ["foot_","calf_","thigh_"]:limb.append(rig.find_bone(label+side))
  legs.append(limb);chain.append_array(limb)
 for label in ["hand_l","lowerarm_l","upperarm_l"]:left_arm.append(rig.find_bone(label))
 chain.append_array(left_arm)
func solve() -> Array[Quaternion]:
 var combined=chain.duplicate();var originals: Array[Quaternion]=[]
 for bone in combined:originals.append(rig.get_bone_pose_rotation(bone))
 if lance.slump>0:aim(torso,Basis(Vector3.RIGHT,.6*smoothstep(0,1,lance.slump))*rig.get_bone_global_pose(torso).basis)
 elif lance.holding and not lance.throwing:
  # Follow a lowered lance with the shoulders. Keeping the rider upright
  # forces a straight elbow when reaching an infantry-height opponent.
  var facing=rig.get_bone_global_pose(head).basis
  aim(torso,Basis(Vector3.RIGHT,.68*smoothstep(0,1,lance.lift))*rig.get_bone_global_pose(torso).basis)
  aim(head,facing)
 chain=lance_chain;super()
 if mount!=null:
  for at in range(2):
   var side=-1 if at==0 else 1;var foot=legs[at][0]
   var ball=rig.find_bone("ball_r" if at==0 else "ball_l")
   var toe=rig.get_bone_global_rest(ball).origin-rig.get_bone_global_rest(foot).origin
   var stirrup=mount.bones.Horse.get_node("RightStirrup" if at==0 else "LeftStirrup")
   var point=stirrup.global_position+mount.global_basis*Vector3(0,.0275-toe.y,toe.z)
   var desired=Transform3D(rig.get_bone_global_rest(foot).basis,rig.to_local(point))
   fit_limb(legs[at],desired,Vector3(side*.8,0,1))
  var goal=rig.to_local(mount.to_global(Vector3(-.23,1.8+mount.support_height,-.27)))
  fit_limb(left_arm,Transform3D(Basis(Vector3.RIGHT,Vector3.BACK,Vector3.DOWN),goal),Vector3(1,-.35,0))
 chain=combined;return originals
func fit_limb(limb: Array[int],desired: Transform3D,pole: Vector3):
 var upper=rig.get_bone_global_pose(limb[2]);var elbow=rig.get_bone_global_pose(limb[1]);var hand=rig.get_bone_global_pose(limb[0])
 var a=upper.origin.distance_to(elbow.origin);var b=elbow.origin.distance_to(hand.origin)
 var axis=desired.origin-upper.origin;var distance=axis.length();axis/=maxf(.00001,distance);distance=clampf(distance,absf(a-b)+.0001,a+b-.0001)
 var wrist=upper.origin+axis*distance;pole-=axis*pole.dot(axis)
 var along=(a*a-b*b+distance*distance)/(2*distance)
 var bend=upper.origin+axis*along+pole.normalized()*sqrt(maxf(0,a*a-along*along))
 aim(limb[2],Basis(Rotation.rotation_between(elbow.origin-upper.origin,bend-upper.origin))*upper.basis)
 elbow=rig.get_bone_global_pose(limb[1]);hand=rig.get_bone_global_pose(limb[0])
 aim(limb[1],Basis(Rotation.rotation_between(hand.origin-elbow.origin,wrist-elbow.origin))*elbow.basis)
 aim(limb[0],desired.basis)

func target_pose() -> Transform3D:
 if lance.rider_pose!="down" and lance.holding:return super()
 var shoulder=rig.get_bone_global_pose(right_chain[2]).origin
 var up=Vector3(0,.72,.69).normalized();var carry=Transform3D(Basis(Vector3.RIGHT,up.cross(Vector3.RIGHT),up),shoulder+Vector3(-.02,-.28,.18))
 var forward=Vector3(-1,.03,.2).normalized();var x=Vector3.UP.cross(forward).normalized()
 var fallen=Transform3D(Basis(x,forward.cross(x),forward),shoulder+Vector3(-.20,-.25,.05))
 return clear_floor(carry.interpolate_with(fallen,smoothstep(0,1,lance.slump)))

func bend_pole(desired: Transform3D,upper: Transform3D,elbow: Transform3D) -> Vector3:
 return Vector3(-1,-.4,0) if not lance.holding else super(desired,upper,elbow)
