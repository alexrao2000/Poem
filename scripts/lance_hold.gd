extends "res://scripts/weapon_floor.gd"
# A fitted thrust reaches the resolved impact point without stretching bones.
var lance: Node3D
var aim_point=Vector3.ZERO
var has_aim=false
func setup(skeleton: Skeleton3D,equipment: Node3D):
 configure(skeleton,Transform3D.IDENTITY);lance=equipment;fit_prop(lance.get_parent(),lance.get_node("Weapon"))
func target_pose() -> Transform3D:
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
 var goal=destination-basis*tip-forward*.22*(1-lance.thrust)
 return clear_floor(Transform3D(carry_basis,carry).interpolate_with(Transform3D(basis,goal),smoothstep(0,1,lance.lift)))
func bend_pole(desired: Transform3D,upper: Transform3D,elbow: Transform3D) -> Vector3:
 return Vector3(-1,-.4,0) if lance.holding else super(desired,upper,elbow)
