extends RefCounted
# Bake only explicitly static scenery. Keep small spatial groups for culling.
# Share lighting attributes across matching rotations and scales.
# Inverse-transpose normals retain correct lighting under nonuniform scale.
const CHUNK_SIZE=8.0
const MAX_ORIENTATIONS_PER_MESH=32

func combine(root: Node3D,spatial=true) -> Dictionary:
 var sources=[];collect(root,Transform3D.IDENTITY,sources)
 var groups={};var surfaces={};var merged_sources=0;var vertices=0
 for source in sources:
  var node=source.node;var shape=node.mesh;var transform=source.transform
  if transform.basis.determinant()<=0 or shape.get_surface_count()!=1:continue
  if shape is ArrayMesh:
   if shape.get_blend_shape_count()>0 or shape.surface_get_primitive_type(0)!=Mesh.PRIMITIVE_TRIANGLES:continue
  elif not shape is PrimitiveMesh or shape is PointMesh:continue
  # Reuse the source attributes for repeated meshes within this build.
  if not surfaces.has(shape):
   var attributes=shape.surface_get_arrays(0);var format=0
   for i in range(attributes.size()):
    if attributes[i]!=null and attributes[i].size()>0:format|=1<<i
   surfaces[shape]={"attributes":attributes,"format":format,"orientations":{}}
  var source_surface=surfaces[shape]
  var material=node.material_override if node.material_override!=null else node.get_active_material(0)
  if material==null:continue
  var chunk=Vector2i(floori(transform.origin.x/CHUNK_SIZE),floori(transform.origin.z/CHUNK_SIZE)) if spatial else Vector2i.ZERO
  var key="%d:%d:%d:%d:%d:%d"%[material.get_instance_id(),source_surface.format,chunk.x,chunk.y,node.cast_shadow,node.layers]
  if not groups.has(key):
   var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);surface.set_material(material)
   groups[key]={"surface":surface,"material":material,"shadow":node.cast_shadow,"layers":node.layers,"cull_margin":0.0}
  groups[key].cull_margin=maxf(groups[key].cull_margin,node.extra_cull_margin)
  var orientation=source_surface.orientations.get(transform.basis)
  if orientation==null:
   orientation=orient_surface(source_surface.attributes,transform.basis)
   if source_surface.orientations.size()<MAX_ORIENTATIONS_PER_MESH:
    source_surface.orientations[transform.basis]=orientation
  var arrays=orientation.duplicate()
  var points: PackedVector3Array=transform*arrays[Mesh.ARRAY_VERTEX]
  arrays[Mesh.ARRAY_VERTEX]=points;vertices+=points.size()
  var baked=ArrayMesh.new();baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  groups[key].surface.append_from(baked,0,Transform3D.IDENTITY)
  node.get_parent().remove_child(node);node.queue_free();merged_sources+=1
 for group in groups.values():
  var node=MeshInstance3D.new();node.name="StaticScenery";node.mesh=group.surface.commit();node.material_override=group.material
  node.cast_shadow=group.shadow;node.layers=group.layers;node.set_meta("static_batch",true);root.add_child(node)
  node.extra_cull_margin=group.cull_margin
 var result={"sources":merged_sources,"batches":groups.size(),"vertices":vertices}
 root.set_meta("batch_stats",result)
 return result

func orient_surface(attributes: Array,basis: Basis) -> Array:
 var arrays=attributes.duplicate()
 if arrays[Mesh.ARRAY_NORMAL]!=null:
  var normal_transform=Transform3D(basis.inverse().transposed(),Vector3.ZERO)
  var normals: PackedVector3Array=normal_transform*arrays[Mesh.ARRAY_NORMAL]
  for i in range(normals.size()):normals[i]=normals[i].normalized()
  arrays[Mesh.ARRAY_NORMAL]=normals
 if arrays[Mesh.ARRAY_TANGENT]!=null:
  var tangents=arrays[Mesh.ARRAY_TANGENT].duplicate()
  for i in range(0,tangents.size(),4):
   var tangent=(basis*Vector3(tangents[i],tangents[i+1],tangents[i+2])).normalized()
   tangents[i]=tangent.x;tangents[i+1]=tangent.y;tangents[i+2]=tangent.z
  arrays[Mesh.ARRAY_TANGENT]=tangents
 return arrays

func collect(node: Node3D,transform: Transform3D,result: Array):
 for child in node.get_children():
  if not child is Node3D or child.is_queued_for_deletion() or not child.visible:continue
  if child.get_meta("dynamic",false) or child.get_meta("static_batch",false) or child.get_script()!=null:continue
  var relative=transform*child.transform
  if child is MeshInstance3D and child.mesh!=null and child.get_child_count()==0 and child.skin==null:
   result.append({"node":child,"transform":relative})
  else:collect(child,relative,result)
