extends RefCounted
# Conservative animated bounds: every weighted vertex lies inside the union of
# its influencing bones' transformed bind-space boxes. No per-frame CPU skinning.
var skeleton: Skeleton3D
var entries=[]

func configure(mesh: MeshInstance3D) -> bool:
 if mesh.skin==null or mesh.mesh==null:return false
 skeleton=mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
 if skeleton==null:return false
 var bounds={}
 for surface in range(mesh.mesh.get_surface_count()):
  var arrays=mesh.mesh.surface_get_arrays(surface)
  var vertices=arrays[Mesh.ARRAY_VERTEX];var bones=arrays[Mesh.ARRAY_BONES];var weights=arrays[Mesh.ARRAY_WEIGHTS]
  if bones==null or weights==null or vertices.is_empty():continue
  var influences=bones.size()/vertices.size()
  for index in range(vertices.size()):
   for influence in range(influences):
    var at=index*influences+influence
    if weights[at]<=0:continue
    var bind=bones[at]
    var point=mesh.skin.get_bind_pose(bind)*vertices[index]
    if bounds.has(bind):bounds[bind]=bounds[bind].expand(point)
    else:bounds[bind]=AABB(point,Vector3.ZERO)
 for bind in bounds:
  var bone=skeleton.find_bone(mesh.skin.get_bind_name(bind))
  if bone<0:bone=mesh.skin.get_bind_bone(bind)
  if bone<0 or bone>=skeleton.get_bone_count():return false
  var corners=PackedVector3Array()
  for index in range(8):corners.append(bounds[bind].get_endpoint(index))
  entries.append([bone,corners])
 return not entries.is_empty()

func points(relative_to: Node3D) -> PackedVector3Array:
 var result=PackedVector3Array()
 if not is_instance_valid(skeleton):return result
 var local=relative_to.global_transform.affine_inverse()*skeleton.global_transform
 for entry in entries:
  var transform=local*skeleton.get_bone_global_pose(entry[0])
  for corner in entry[1]:result.append(transform*corner)
 return result
