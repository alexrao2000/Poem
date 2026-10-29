extends RefCounted
# A thin reverse-culled shell separates opaque combat silhouettes from scenery.
# Smooth only the outline directions across coincident vertices, preserving
# faceted lighting on the actual model. Store directions in unused vertex color;
# recompute after batching so transformed pieces share the correct local space.
# Exclude painted face cards and luminous/transparent details.
const WIDTH=.005
const SHADER=preload("res://assets/shaders/character-outline.gdshader")
static var ink: ShaderMaterial

static func material() -> ShaderMaterial:
 if ink==null:
  ink=ShaderMaterial.new();ink.shader=SHADER;ink.set_shader_parameter("width",WIDTH)
 return ink

static func smooth_directions(mesh: Mesh) -> ArrayMesh:
 var arrays=mesh.surface_get_arrays(0).duplicate(true)
 var points=arrays[Mesh.ARRAY_VERTEX];var indices=arrays[Mesh.ARRAY_INDEX];var sums={}
 if indices==null or indices.is_empty():indices=range(points.size())
 var keys=[]
 for point in points:keys.append(point.snapped(Vector3.ONE*.00001))
 for i in range(0,indices.size(),3):
  var a=points[indices[i]];var b=points[indices[i+1]];var c=points[indices[i+2]]
  var normal=(c-a).cross(b-a)
  for j in range(3):
   var key=keys[indices[i+j]];sums[key]=sums.get(key,Vector3.ZERO)+normal
 var colors=PackedColorArray()
 for i in range(points.size()):
  var normal=sums[keys[i]].normalized()
  if normal.is_zero_approx():normal=arrays[Mesh.ARRAY_NORMAL][i]
  colors.append(Color(normal.x*.5+.5,normal.y*.5+.5,normal.z*.5+.5))
 arrays[Mesh.ARRAY_COLOR]=colors
 var result=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return result

static func apply(actor: Node3D):
 var copies={}
 for mesh in actor.find_children("*","MeshInstance3D",true,false):
  if mesh.name=="PaintedFace":continue
  var surface=mesh.material_override
  if surface==null:continue
  if surface is StandardMaterial3D and (surface.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED or surface.emission_enabled):continue
  if mesh.mesh.get_surface_count()!=1:continue
  mesh.mesh=smooth_directions(mesh.mesh)
  if not copies.has(surface):
   var copy=surface.duplicate();copy.next_pass=material();copies[surface]=copy
  mesh.material_override=copies[surface]
  mesh.extra_cull_margin=maxf(mesh.extra_cull_margin,WIDTH*2.0)
