extends "res://scripts/skeletal_hold.gd"
# Keep the rigid staff in its palm during falls. Adjust the wrist goal before
# the arm solve, using the prop's conservative local bounds against the floor.
var corners=[]
var model: Node3D

func fit_prop(anchor: BoneAttachment3D,weapon: Node3D):
 model=anchor.owner as Node3D
 var box=AABB();var first=true
 for mesh in weapon.find_children("*","MeshInstance3D",true,false):
  var transform=mesh.transform;var parent=mesh.get_parent()
  while parent!=anchor:transform=parent.transform*transform;parent=parent.get_parent()
  for surface in range(mesh.mesh.get_surface_count()):
   for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
    var point=transform*vertex
    if first:box=AABB(point,Vector3.ZERO);first=false
    else:box=box.expand(point)
 corners.clear()
 if not first:
  for index in range(8):corners.append(box.get_endpoint(index))

func minimum_height(transform: Transform3D) -> float:
 var height=INF
 for point in corners:height=minf(height,(transform*point).y)
 return height

func target_pose() -> Transform3D:
 var desired=super()
 if corners.is_empty() or not is_instance_valid(model) or not model.is_inside_tree():return desired
 var world=rig.global_transform*desired;var floor_y=model.get_parent().global_position.y+.018
 if minimum_height(world)>=floor_y:return desired
 var direction=world.basis.z.normalized();var horizontal=Vector3(direction.x,0,direction.z)
 if horizontal.length_squared()<.000001:horizontal=Vector3(world.basis.x.x,0,world.basis.x.z)
 var flat=Transform3D(Basis(Rotation.rotation_between(direction,horizontal.normalized()))*world.basis,world.origin)
 world.origin.y+=maxf(0,floor_y-minimum_height(flat));flat.origin=world.origin
 var start=world.basis.orthonormalized().get_rotation_quaternion();var finish=flat.basis.orthonormalized().get_rotation_quaternion();var size=Basis.from_scale(world.basis.get_scale())
 var low=0.0;var high=1.0
 for step in range(10):
  var middle=(low+high)*.5;var candidate=Transform3D(Basis(start.slerp(finish,middle))*size,world.origin)
  if minimum_height(candidate)<floor_y:low=middle
  else:high=middle
 world.basis=Basis(start.slerp(finish,high))*size
 return rig.global_transform.affine_inverse()*world
