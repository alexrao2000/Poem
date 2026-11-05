extends Node
# Private material passes preserve the supplied geometry and skin. Run after
# cloth drivers so both passes use the same frame, including after defeat remaps.
const SHADER=preload("res://assets/shaders/authored-outline.gdshader")
const CHARACTER=preload("res://assets/shaders/character.gdshader")
const DYED=preload("res://assets/shaders/authored-cloth.gdshader")
const WIDTH=.0025
const CLOTH={"cloth_amount":0.0,"cloth_clock":0.0,"cloth_drive":0.0,"cloth_floor_enabled":false,"cloth_floor_y":0.0}
var model: Node3D
var pairs=[]

func configure(body: Node3D) -> Dictionary:
 model=body;process_priority=1
 var copies={}
 for mesh in model.find_children("*","MeshInstance3D",true,false):
  if mesh.mesh==null or mesh.name=="PaintedFace" or not locally_visible(mesh):continue
  if mesh.material_override!=null:
   mesh.material_override=outlined(mesh.material_override,copies)
  else:
   for index in range(mesh.mesh.get_surface_count()):
    var material=mesh.get_active_material(index)
    if eligible(material):mesh.set_surface_override_material(index,outlined(material,copies))
  mesh.extra_cull_margin=maxf(mesh.extra_cull_margin,WIDTH*2)
 sync_cloth()
 return copies

func locally_visible(node: Node) -> bool:
 while node!=null:
  if node is Node3D and not node.visible:return false
  if node==model:return true
  node=node.get_parent()
 return false

static func eligible(material: Material) -> bool:
 if material==null or material.next_pass!=null or material.get_meta("no_character_outline",false):return false
 if material is BaseMaterial3D:return material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and not material.emission_enabled
 return material is ShaderMaterial and material.shader in [CHARACTER,DYED]

func outlined(source: Material,copies: Dictionary) -> Material:
 if copies.has(source):return copies[source]
 if not eligible(source):return source
 var material=source.duplicate();var shell=ShaderMaterial.new();shell.shader=SHADER
 shell.set_shader_parameter("width",clampf(float(source.get_meta("outline_width",WIDTH)),0,WIDTH))
 material.next_pass=shell;copies[source]=material
 pairs.append({"material":material,"shell":shell,"cloth":source is ShaderMaterial and source.shader==CHARACTER})
 return material

func materials_remapped(copies: Dictionary):
 for pair in pairs:
  pair.material=copies.get(pair.material,pair.material);pair.shell=copies.get(pair.shell,pair.shell)
 sync_cloth()

func sync_cloth():
 for pair in pairs:
  if not pair.cloth:continue
  for key in CLOTH:
   var value=pair.material.get_shader_parameter(key)
   pair.shell.set_shader_parameter(key,CLOTH[key] if value==null else value)

func _process(_delta):
 if is_instance_valid(model) and model.is_visible_in_tree():sync_cloth()
