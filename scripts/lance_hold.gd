extends "res://scripts/weapon_floor.gd"
# A fitted thrust reaches the resolved impact point without stretching bones.
var lance: Node3D
var aim_point=Vector3.ZERO
var has_aim=false
var right_chain: Array[int]=[]
var torso=-1
var head=-1
func setup(skeleton: Skeleton3D,equipment: Node3D):
 configure(skeleton,Transform3D.IDENTITY);lance=equipment;fit_prop(lance.get_parent(),lance.get_node("Weapon"))
 right_chain=chain.duplicate();torso=rig.find_bone("spine_03");head=rig.find_bone("Head");chain.append(torso);chain.append(head)
func solve() -> Array[Quaternion]:
 var combined=right_chain.duplicate();combined.append(torso);combined.append(head);var originals: Array[Quaternion]=[]
 for bone in combined:originals.append(rig.get_bone_pose_rotation(bone))
 if lance.throwing:
  var head_basis=rig.get_bone_global_pose(head).basis
  var turn=.55+(.20 if lance.critical_throw_prepared else 0.0)
  aim(torso,Basis(Vector3.UP,-turn*lance.throw_raise*(1-lance.throw_push) if not lance.recovering else 0.0)*rig.get_bone_global_pose(torso).basis)
  aim(head,head_basis)
 elif lance.critical_prepared and lance.holding:
  var head_basis=rig.get_bone_global_pose(head).basis
  aim(torso,Basis(Vector3.UP,-.18*smoothstep(0,1,lance.lift)*(1-smoothstep(0,1,lance.thrust)))*rig.get_bone_global_pose(torso).basis)
  aim(head,head_basis)
 chain=right_chain;super();chain=combined;return originals
func target_pose() -> Transform3D:
 if lance.throwing:return throw_pose()
 if not lance.holding:
  var current=rig.get_bone_global_pose(chain[0])
  if lance.fall>0:
   var world=rig.global_transform*current;var z=rig.global_basis*Vector3.LEFT
   var flat=Basis(Vector3.UP.cross(z),Vector3.UP,z)
   world.basis=world.basis.slerp(flat,smoothstep(0,1,lance.fall));current=rig.global_transform.affine_inverse()*world
  return clear_floor(current)
 var shoulder=rig.get_bone_global_pose(chain[2]).origin
 var carry=shoulder+Vector3(-.02,-.28,.18)
 var up=Vector3(0,.72,.69).normalized();var carry_basis=Basis(Vector3.RIGHT,up.cross(Vector3.RIGHT),up)
 var destination=rig.to_local(aim_point) if has_aim else Vector3(0,1.1,2.1)
 var forward=(destination-(shoulder+Vector3(-.03,-.09,.34))).normalized()
 if absf(forward.dot(Vector3.UP))>.995:forward=Vector3.BACK
 var x=Vector3.UP.cross(forward).normalized();var basis=Basis(x,forward.cross(x),forward)
 var tip=lance.transform*lance.get_node("Weapon").transform*lance.get_node("Weapon/TrailTip").position
 var draw=.22+(.12*smoothstep(0,1,lance.lift) if lance.critical_prepared else 0.0)
 var goal=destination-basis*tip-forward*draw*(1-lance.thrust)
 return clear_floor(Transform3D(carry_basis,carry).interpolate_with(Transform3D(basis,goal),smoothstep(0,1,lance.lift)))
func throw_pose() -> Transform3D:
 var shoulder=rig.get_bone_global_pose(chain[2]).origin
 # Finish raising the spear before drawing farther back; combining the deep
 # draw with the shoulder's initial sweep makes the wrist turn too sharply.
 var backswing=-.20-(.08*smoothstep(.72,1,lance.throw_raise) if lance.critical_throw_prepared else 0.0)
 var goal=shoulder+Vector3(-.09,lerpf(.32,.08,lance.throw_push),lerpf(backswing,.36,lance.throw_push))
 var point=rig.to_local(aim_point) if has_aim else Vector3(0,1.1,4)
 point+=rig.global_basis.inverse()*Vector3.UP*PI*.08
 var forward=(point-goal).normalized();var basis=Basis.IDENTITY
 for step in range(4):
  if absf(forward.dot(Vector3.UP))>.995:forward=Vector3.BACK
  var x=Vector3.UP.cross(forward).normalized();basis=Basis(x,forward.cross(x),forward)
  var origin=goal+basis*(lance.transform*lance.get_node("Weapon").position)
  forward=(point-origin).normalized()
 var carry=shoulder+Vector3(-.02,-.28,.18);var up=Vector3(0,.72,.69).normalized();var carry_basis=Basis(Vector3.RIGHT,up.cross(Vector3.RIGHT),up)
 # Sweep outside the shoulder instead of folding the wrist through it on
 # the straight carry-to-overhead path; this keeps a stable elbow plane.
 var blend=smoothstep(0,1,lance.throw_raise)
 var desired=Transform3D(carry_basis,carry).interpolate_with(Transform3D(basis,goal),blend)
 desired.origin.x-=.24*sin(PI*blend)
 return clear_floor(desired)

func bend_pole(desired: Transform3D,upper: Transform3D,elbow: Transform3D) -> Vector3:
 if lance.throwing:return Vector3(-1,.25,-.9*sin(PI*smoothstep(0,1,lance.throw_raise)))
 return Vector3(-1,-.4,0) if lance.holding else super(desired,upper,elbow)
