extends RefCounted
# CPU reference sampling for fitted-outfit checks and offline calibration.
# Shader-clamped cloth is covered separately by its own motion/floor suites.
static func prepare(actor) -> Array:
 var rig=actor.model.get_node("Rig/Armature/Skeleton3D");var result=[]
 for mesh in actor.find_children("*","MeshInstance3D",true,false):
  if not mesh.is_visible_in_tree() or str(mesh.get_path()).contains("Cloak"):continue
  var bones=[]
  if mesh.skin!=null:
   assert(mesh.transform.is_equal_approx(Transform3D.IDENTITY))
   for bind in range(mesh.skin.get_bind_count()):bones.append(rig.find_bone(mesh.skin.get_bind_name(bind)))
  for surface in range(mesh.mesh.get_surface_count()):result.append([mesh,mesh.mesh.surface_get_arrays(surface),bones])
 return result
static func minimum(actor,cache: Array) -> float:
 var rig=actor.model.get_node("Rig/Armature/Skeleton3D");var originals=[]
 for modifier in actor.pose_constraints:originals.append(modifier.solve())
 var lowest=INF
 for entry in cache:
  var mesh=entry[0];var arrays=entry[1];var vertices=arrays[Mesh.ARRAY_VERTEX];var transforms=[]
  for bind in range(entry[2].size()):transforms.append(rig.get_bone_global_pose(entry[2][bind])*mesh.skin.get_bind_pose(bind))
  for index in range(vertices.size()):
   var point=vertices[index]
   if not transforms.is_empty():
    point=Vector3.ZERO;var bones=arrays[Mesh.ARRAY_BONES];var weights=arrays[Mesh.ARRAY_WEIGHTS];var influences=bones.size()/vertices.size()
    for j in range(influences):
     var offset=index*influences+j;point+=(transforms[bones[offset]]*vertices[index])*weights[offset]
    point=rig.to_global(point)
   else:point=mesh.to_global(point)
   assert(point.is_finite());lowest=minf(lowest,point.y)
 for at in range(actor.pose_constraints.size()-1,-1,-1):
  var modifier=actor.pose_constraints[at]
  for index in range(modifier.chain.size()):rig.set_bone_pose_rotation(modifier.chain[index],originals[at][index])
 rig.force_update_all_bone_transforms()
 assert(is_finite(lowest));return lowest
