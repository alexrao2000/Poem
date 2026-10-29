extends RefCounted
# Bake only explicitly static scenery. Keep small spatial groups for culling.
const CHUNK_SIZE=8.0

func combine(root: Node3D) -> Dictionary:
 var sources=[];collect(root,Transform3D.IDENTITY,sources)
 var groups={};var merged_sources=0;var vertices=0
 for source in sources:
  var node=source.node;var shape=node.mesh;var transform=source.transform
  if transform.basis.determinant()<=0 or shape.get_surface_count()!=1:continue
  if shape is ArrayMesh:
   if shape.get_blend_shape_count()>0 or shape.surface_get_primitive_type(0)!=Mesh.PRIMITIVE_TRIANGLES:continue
  elif not shape is PrimitiveMesh or shape is PointMesh:continue
  var arrays=shape.surface_get_arrays(0).duplicate(true);var format=0
  for i in range(arrays.size()):
   if arrays[i]!=null and arrays[i].size()>0:format|=1<<i
  var material=node.material_override if node.material_override!=null else node.get_active_material(0)
  if material==null:continue
  var chunk=Vector2i(floori(transform.origin.x/CHUNK_SIZE),floori(transform.origin.z/CHUNK_SIZE))
  var key="%d:%d:%d:%d:%d:%d"%[material.get_instance_id(),format,chunk.x,chunk.y,node.cast_shadow,node.layers]
  if not groups.has(key):
   var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);surface.set_material(material)
   groups[key]={"surface":surface,"material":material,"shadow":node.cast_shadow,"layers":node.layers}
  var points=arrays[Mesh.ARRAY_VERTEX]
  for i in range(points.size()):points[i]=transform*points[i]
  arrays[Mesh.ARRAY_VERTEX]=points;vertices+=points.size()
  # SurfaceTool.append_from applies the forward basis to normals. Bake the
  # inverse transpose explicitly so stretched foliage keeps correct lighting.
  if arrays[Mesh.ARRAY_NORMAL]!=null:
   var normals=arrays[Mesh.ARRAY_NORMAL];var normal_basis=transform.basis.inverse().transposed()
   for i in range(normals.size()):normals[i]=(normal_basis*normals[i]).normalized()
   arrays[Mesh.ARRAY_NORMAL]=normals
  if arrays[Mesh.ARRAY_TANGENT]!=null:
   var tangents=arrays[Mesh.ARRAY_TANGENT]
   for i in range(0,tangents.size(),4):
    var tangent=(transform.basis*Vector3(tangents[i],tangents[i+1],tangents[i+2])).normalized()
    tangents[i]=tangent.x;tangents[i+1]=tangent.y;tangents[i+2]=tangent.z
   arrays[Mesh.ARRAY_TANGENT]=tangents
  var baked=ArrayMesh.new();baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  groups[key].surface.append_from(baked,0,Transform3D.IDENTITY)
  node.get_parent().remove_child(node);node.queue_free();merged_sources+=1
 for group in groups.values():
  var node=MeshInstance3D.new();node.name="StaticScenery";node.mesh=group.surface.commit();node.material_override=group.material
  node.cast_shadow=group.shadow;node.layers=group.layers;node.set_meta("static_batch",true);root.add_child(node)
 var result={"sources":merged_sources,"batches":groups.size(),"vertices":vertices}
 root.set_meta("batch_stats",result)
 return result

func collect(node: Node3D,transform: Transform3D,result: Array):
 for child in node.get_children():
  if not child is Node3D or child.is_queued_for_deletion() or not child.visible:continue
  if child.get_meta("dynamic",false) or child.get_meta("static_batch",false) or child.get_script()!=null:continue
  var relative=transform*child.transform
  if child is MeshInstance3D and child.mesh!=null and child.get_child_count()==0 and child.skin==null:
   result.append({"node":child,"transform":relative})
  else:collect(child,relative,result)
