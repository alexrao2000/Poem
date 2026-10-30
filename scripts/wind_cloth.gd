extends Node3D
# Bounded vertex motion keeps the entire attached edge pinned. The node stays
# outside static batching so local dimensions and culling bounds remain valid.
const SHADER=preload("res://assets/shaders/cloth.gdshader")
const LINEN=preload("res://assets/art/character-materials.png")
const PERIOD=TAU*10.0
var cloth: MeshInstance3D
var material: ShaderMaterial
var phase=0.0
var dimensions=Vector2.ZERO
var standard=true

func configure(extent: Vector2,color: Color,is_standard=true,start_phase=0.0):
 name="WindStandard" if is_standard else "WindSail";dimensions=extent;standard=is_standard
 phase=fposmod(start_phase,PERIOD)
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in range(6):
  for column in range(12):
   var uv=[Vector2(column/12.0,row/6.0),Vector2((column+1)/12.0,row/6.0),Vector2((column+1)/12.0,(row+1)/6.0),Vector2(column/12.0,(row+1)/6.0)]
   for i in [0,1,2,0,2,3]:
    var point=uv[i];var edge=1.0-.13*(1.0-absf(point.y*2-1)) if standard else 1.0
    tool.set_uv(point);tool.set_normal(Vector3.BACK);tool.add_vertex(Vector3(point.x*extent.x*edge,(.5-point.y)*extent.y,0))
 material=ShaderMaterial.new();material.shader=SHADER;material.set_shader_parameter("linen_atlas",LINEN)
 material.set_shader_parameter("dimensions",extent);material.set_shader_parameter("tint",color);material.set_shader_parameter("emblem",standard);material.set_shader_parameter("phase",phase)
 cloth=MeshInstance3D.new();cloth.name="Cloth";cloth.mesh=tool.commit();cloth.material_override=material
 cloth.custom_aabb=AABB(Vector3(0,-extent.y*.545,-extent.x*.061),Vector3(extent.x,extent.y*1.045,extent.x*.122))
 cloth.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
 add_child(cloth)

func _process(dt):
 if material==null or not is_visible_in_tree():return
 # Both wave frequencies repeat exactly at this bounded phase interval.
 phase=fposmod(phase+dt,PERIOD);material.set_shader_parameter("phase",phase)
