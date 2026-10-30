extends Node
# Resolved defeat fades during the survivor's finish. Clone the complete material
# graph only for this actor, preserving face/cape ownership and shared caches.
# Unknown authored shaders keep their fall animation and hide at the same endpoint.

const Actor=preload("res://scripts/fighter_actor.gd")
const DURATION=.32
const SUPPORTED=[preload("res://assets/shaders/character.gdshader"),preload("res://assets/shaders/character-outline.gdshader"),preload("res://assets/shaders/face-blink.gdshader")]
static var fade_shaders={}
var actor: Node3D
var motion: Tween
var copies={}
var shaders: Array[ShaderMaterial]=[]
var standards={}
var visibility=1.0

func begin(subject: Node3D):
 name="CombatDefeat";actor=subject
 for mesh in actor.find_children("*","MeshInstance3D",true,false):
  if mesh.mesh==null:continue
  if mesh.material_override!=null:mesh.material_override=own(mesh.material_override)
  else:
   for index in mesh.mesh.get_surface_count():
    var material=mesh.get_active_material(index)
    if material!=null:mesh.set_surface_override_material(index,own(material))
 if actor is Actor:
  actor.face_blink.surface=copies.get(actor.face_blink.surface,actor.face_blink.surface)
  actor.cape_motion.bind(actor)
 apply_visibility(1.0)
 motion=create_tween();motion.tween_method(apply_visibility,1.0,0.0,DURATION)
 motion.tween_callback(finish)

func own(source: Material) -> Material:
 if copies.has(source):return copies[source]
 var copy=source.duplicate();copies[source]=copy
 if source.next_pass!=null:copy.next_pass=own(source.next_pass)
 if copy is ShaderMaterial and copy.shader in SUPPORTED:
  copy.shader=fade_shader(copy.shader);shaders.append(copy)
 elif copy is BaseMaterial3D:
  standards[copy]=copy.albedo_color.a
  if copy.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED:copy.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
 return copy

func apply_visibility(value: float):
 visibility=clampf(value,0.0,1.0)
 for surface in shaders:surface.set_shader_parameter("defeat_visibility",visibility)
 for surface in standards:
  var color=surface.albedo_color;color.a=standards[surface]*visibility;surface.albedo_color=color

func finish():
 if motion!=null and motion.is_valid():motion.kill()
 apply_visibility(0.0)
 if is_instance_valid(actor):actor.hide()

static func fade_shader(source: Shader) -> Shader:
 if not fade_shaders.has(source):
  var shader=Shader.new()
  shader.code=source.code.replace("void fragment() {",'#include "res://assets/shaders/defeat-mask.gdshaderinc"\nvoid fragment() {\n if (defeat_visibility < defeat_threshold(FRAGCOORD.xy)) { discard; }')
  fade_shaders[source]=shader
 return fade_shaders[source]
