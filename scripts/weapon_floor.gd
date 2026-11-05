extends "res://scripts/prop_floor.gd"
# Broad axe heads lie on their blade plane during falls. Use a consistent face:
# choosing whichever face is nearest can flip the wrist halfway through a fall.
func flatten(world: Transform3D) -> Basis:
 var direction=world.basis.z;var horizontal=Vector3(direction.x,0,direction.z)
 if horizontal.length_squared()<.000001:horizontal=Vector3(world.basis.x.x,0,world.basis.x.z)
 var z=horizontal.normalized()
 return Basis(Vector3.UP.cross(z),Vector3.UP,z)*Basis.from_scale(world.basis.get_scale())

func target_pose() -> Transform3D:return clear_floor(rig.get_bone_global_pose(chain[0]))

func bend_pole(desired: Transform3D,upper: Transform3D,elbow: Transform3D) -> Vector3:
 # When floor contact begins, retain the animated elbow's side of the arm.
 # Switching to a prop-defined pole can snap a bent elbow despite a smooth wrist.
 var original_axis=(rig.get_bone_global_pose(chain[0]).origin-upper.origin).normalized()
 var next_axis=(desired.origin-upper.origin).normalized()
 var pole=elbow.origin-upper.origin;pole-=original_axis*pole.dot(original_axis)
 return Basis(Rotation.rotation_between(original_axis,next_axis))*pole

func solve() -> Array[Quaternion]:
 # Safe animated poses must retain their exact source elbow and wrist rotations.
 if rig.get_bone_global_pose(chain[0]).is_equal_approx(target_pose()):
  var originals: Array[Quaternion]=[]
  for bone in chain:originals.append(rig.get_bone_pose_rotation(bone))
  return originals
 return super()
