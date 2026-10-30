extends SceneTree
# Exercise material ownership and real animation bindings across the complete
# roster. Rendering is inspected separately; headless checks cannot judge a fade.

const Fighters=preload("res://scripts/fighters.gd")
const Rules=preload("res://scripts/rules.gd")
const Defeat=preload("res://scripts/combat_defeat.gd")
func _initialize():call_deferred("run")

func materials(actor: Node3D) -> Array:
 var result=[]
 for mesh in actor.find_children("*","MeshInstance3D",true,false):
  if mesh.mesh==null:continue
  for index in mesh.mesh.get_surface_count():
   var surface=mesh.get_active_material(index)
   while surface!=null:
    if surface not in result:result.append(surface)
    surface=surface.next_pass
 return result

func snapshot(surfaces: Array) -> Dictionary:
 var state={}
 for surface in surfaces:
  if surface is ShaderMaterial:state[surface]=[surface.next_pass,surface.get_shader_parameter("defeat_visibility"),surface.get_shader_parameter("eyes_closed"),surface.get_shader_parameter("cloth_clock")]
  else:state[surface]=[surface.next_pass,surface.albedo_color,surface.transparency]
 return state

func run():
 var painter=Fighters.new();var rules=Rules.new();var world=Node3D.new();root.add_child(world)
 var count=0
 for recruit in rules.roster:
  var unit=recruit.duplicate(true);unit.team="player"
  var defeated=painter.build(world,unit,Vector3.ZERO);defeated.set_process(false)
  var survivor=painter.build(world,unit,Vector3(3,0,0));survivor.set_process(false)
  defeated.pose("down",1).custom_step(1);survivor.pose("idle",1).custom_step(1)
  var original=materials(defeated);var protected=materials(survivor);protected.append_array(original)
  var before=snapshot(protected);var face=defeated.face_blink.surface
  var effect=Defeat.new();world.add_child(effect);effect.begin(defeated);effect.motion.pause()
  var owned=materials(defeated)
  for material in original:
   assert(material not in owned,"Defeat owns every body, face, weapon, rein and outline surface")
   if material is ShaderMaterial:assert("defeat_visibility" not in material.shader.code,"Ordinary characters retain their original opaque shaders")
  assert(not effect.shaders.is_empty() and not effect.standards.is_empty(),"Both painted cloth and standard skin/metal participate")
  for surface in effect.standards:assert(surface.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA,"Standard skin/metal uses supported partial transparency in the Compatibility renderer")
  assert(defeated.face_blink.surface==effect.copies[face],"Expression controller follows the cloned face")
  for surface in defeated.cape_motion.surfaces:assert(surface in owned,"Cape clock remains bound to the visible cloned passes")
  for visibility in [1.0,.75,.5,.25,0.0]:
   effect.apply_visibility(visibility)
   defeated.face_blink.set_closed(false);defeated.face_blink.set_closed(true)
   defeated.cape_motion.update(2.5,"down",.1)
   assert(defeated.face_blink.surface.get_shader_parameter("eyes_closed"),"Defeated face stays closed while fading")
   for surface in defeated.cape_motion.surfaces:assert(is_equal_approx(surface.get_shader_parameter("cloth_clock"),2.5),"Cape deformation survives material rebinding")
   for surface in effect.shaders:assert(is_equal_approx(surface.get_shader_parameter("defeat_visibility"),visibility),"Face, body and outline share coverage")
   for surface in effect.standards:assert(is_equal_approx(surface.albedo_color.a,effect.standards[surface]*visibility),"Skin/metal alpha retains its original multiplier")
   assert(snapshot(protected)==before,"Defeat cannot alter the survivor, source materials or shared outline cache")
   count+=1
  effect.finish();assert(not defeated.visible and survivor.visible and not effect.motion.is_valid(),"Completion hides only the defeated actor and stops the tween")
  effect.finish();effect.queue_free();defeated.queue_free();survivor.queue_free();await process_frame
 verify_authored_surfaces(world)
 world.queue_free();await process_frame
 print("PASS: %d roster fade samples, private complete material graphs, live face/cape bindings, survivor/cache isolation, imported surface slots and immediate cancellation"%count)
 quit()

func verify_authored_surfaces(world):
 var actor=Node3D.new();world.add_child(actor)
 var mesh=MeshInstance3D.new();actor.add_child(mesh)
 var shape=ArrayMesh.new();var box=BoxMesh.new()
 var opaque=StandardMaterial3D.new();var glass=StandardMaterial3D.new();glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.albedo_color=Color(1,1,1,.4)
 var cutout=StandardMaterial3D.new();cutout.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
 var pixels=Image.create(2,2,false,Image.FORMAT_RGBA8);pixels.fill(Color(1,1,1,.5));cutout.albedo_texture=ImageTexture.create_from_image(pixels)
 var hashed=StandardMaterial3D.new();hashed.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
 for surface in [opaque,glass,cutout,hashed]:
  shape.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,box.surface_get_arrays(0));shape.surface_set_material(shape.get_surface_count()-1,surface)
 mesh.mesh=shape
 var custom=MeshInstance3D.new();custom.mesh=BoxMesh.new();actor.add_child(custom)
 var shader=Shader.new();shader.code="shader_type spatial; void fragment() { ALBEDO=vec3(1.0); }"
 var surface=ShaderMaterial.new();surface.shader=shader;custom.material_override=surface
 var empty=MeshInstance3D.new();actor.add_child(empty)
 var effect=Defeat.new();world.add_child(effect);effect.begin(actor);effect.motion.pause();effect.apply_visibility(.5)
 assert(mesh.get_active_material(0)!=opaque and mesh.get_active_material(1)!=glass,"Imported mesh surfaces receive private instance overrides")
 assert(is_equal_approx(mesh.get_active_material(1).albedo_color.a,.2) and is_equal_approx(glass.albedo_color.a,.4),"Existing authored transparency remains proportional and isolated")
 assert(mesh.get_active_material(0).transparency==BaseMaterial3D.TRANSPARENCY_ALPHA and mesh.get_active_material(2).transparency==BaseMaterial3D.TRANSPARENCY_ALPHA and mesh.get_active_material(3).transparency==BaseMaterial3D.TRANSPARENCY_ALPHA,"Opaque and cutout authored surfaces use the browser-supported fade path")
 assert(mesh.get_active_material(2).albedo_texture==cutout.albedo_texture and cutout.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR and hashed.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_HASH,"Authored alpha artwork and original modes remain untouched")
 assert(custom.material_override.shader==shader,"Unknown authored shaders retain their fall appearance")
 effect.finish();assert(not actor.visible,"All authored materials hide at the common endpoint")
 effect.queue_free();actor.queue_free()
