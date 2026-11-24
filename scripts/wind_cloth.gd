extends Node3D
# Bounded vertex motion keeps the entire attached edge pinned. The node stays
# outside static batching so local dimensions and culling bounds remain valid.
# Geometry depends on the dimensions and shape. Materials and clocks stay per instance.
# Both wave frequencies repeat at the same phase interval.
const SHADER=preload("res://assets/shaders/cloth.gdshader")
const LINEN=preload("res://assets/art/character-materials.png")
const PERIOD=TAU*10.0
const MAX_CACHED_MESHES=12
static var cloth_meshes: Dictionary={}
var cloth: MeshInstance3D
var material: ShaderMaterial
var phase=0.0
var dimensions=Vector2.ZERO
var standard=true

func configure(extent: Vector2,color: Color,is_standard=true,start_phase=0.0):
 name="WindStandard" if is_standard else "WindSail";dimensions=extent;standard=is_standard
 material=ShaderMaterial.new();material.shader=SHADER;material.set_shader_parameter("linen_atlas",LINEN)
 material.set_shader_parameter("dimensions",extent);material.set_shader_parameter("tint",color);material.set_shader_parameter("emblem",standard)
 seek_phase(start_phase)
 cloth=MeshInstance3D.new();cloth.name="Cloth";cloth.mesh=mesh_for(extent,is_standard);cloth.material_override=material
 cloth.custom_aabb=AABB(Vector3(0,-extent.y*.545,-extent.x*.061),Vector3(extent.x,extent.y*1.045,extent.x*.122))
 cloth.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
 add_child(cloth)

static func mesh_for(extent: Vector2,is_standard: bool) -> ArrayMesh:
 var key=Vector3(extent.x,extent.y,1 if is_standard else 0)
 if cloth_meshes.has(key):return cloth_meshes[key]
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in range(6):
  for column in range(12):
   var uv=[Vector2(column/12.0,row/6.0),Vector2((column+1)/12.0,row/6.0),Vector2((column+1)/12.0,(row+1)/6.0),Vector2(column/12.0,(row+1)/6.0)]
   for i in [0,1,2,0,2,3]:
    var point=uv[i];var edge=1.0-.13*(1.0-absf(point.y*2-1)) if is_standard else 1.0
    tool.set_uv(point);tool.set_normal(Vector3.BACK);tool.add_vertex(Vector3(point.x*extent.x*edge,(.5-point.y)*extent.y,0))
 var shape=tool.commit()
 if cloth_meshes.size()<MAX_CACHED_MESHES:cloth_meshes[key]=shape
 return shape

func seek_phase(value: float):
 phase=fposmod(value,PERIOD);material.set_shader_parameter("phase",phase)

func _process(dt):
 if material!=null and is_visible_in_tree():seek_phase(phase+dt)
