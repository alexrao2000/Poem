extends RefCounted
# Reuse only the licensed neck below the original skull. Keeping its skin
# weights preserves the collar connection while our original head turns.
static var cache={}

static func mesh_for(source: MeshInstance3D,rig: Skeleton3D) -> ArrayMesh:
 if source.mesh==null or source.skin==null or source.mesh.get_surface_count()!=1:return null
 var key=(source.mesh.resource_path if not source.mesh.resource_path.is_empty() else str(source.mesh.get_instance_id()))+":"+(source.skin.resource_path if not source.skin.resource_path.is_empty() else str(source.skin.get_instance_id()))
 if cache.has(key):return cache[key]
 var arrays=source.mesh.surface_get_arrays(0);var vertices=arrays[Mesh.ARRAY_VERTEX]
 var bones=arrays[Mesh.ARRAY_BONES];var weights=arrays[Mesh.ARRAY_WEIGHTS]
 var influences=bones.size()/vertices.size();var binds=[]
 for index in range(source.skin.get_bind_count()):
  var bone=rig.find_bone(source.skin.get_bind_name(index))
  if bone<0:bone=source.skin.get_bind_bone(index)
  binds.append(rig.get_bone_global_rest(bone)*source.skin.get_bind_pose(index))
 var head_origin=rig.get_bone_global_rest(rig.find_bone("Head")).origin
 # Crop in the supplied rig's rest coordinates. The forward cutoff removes
 # the lower jaw/chin that would protrude through the smaller original head.
 var ceiling=head_origin.y+.01
 var retained=[]
 for index in range(vertices.size()):
  var rest=Vector3.ZERO
  for influence in range(influences):
   var slot=index*influences+influence;rest+=(binds[bones[slot]]*vertices[index])*weights[slot]
  retained.append(rest.y<=ceiling and rest.z<=head_origin.z+.055)
 var indices=arrays[Mesh.ARRAY_INDEX];var surface=SurfaceTool.new()
 surface.set_skin_weight_count(SurfaceTool.SKIN_8_WEIGHTS if influences==8 else SurfaceTool.SKIN_4_WEIGHTS)
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var normals=arrays[Mesh.ARRAY_NORMAL];var tangents=arrays[Mesh.ARRAY_TANGENT];var uv=arrays[Mesh.ARRAY_TEX_UV];var count=0
 for triangle in range(0,indices.size(),3):
  if not retained[indices[triangle]] or not retained[indices[triangle+1]] or not retained[indices[triangle+2]]:continue
  for corner in range(3):
   var index=indices[triangle+corner];surface.set_normal(normals[index]);surface.set_uv(uv[index])
   if tangents!=null and not tangents.is_empty():surface.set_tangent(Plane(Vector3(tangents[index*4],tangents[index*4+1],tangents[index*4+2]),tangents[index*4+3]))
   surface.set_bones(bones.slice(index*influences,(index+1)*influences));surface.set_weights(weights.slice(index*influences,(index+1)*influences));surface.add_vertex(vertices[index]);count+=1
 if count==0:return null
 surface.index();var mesh=surface.commit();mesh.set_meta("neck_triangles",count/3);cache[key]=mesh;return mesh
