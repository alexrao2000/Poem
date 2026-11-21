extends SceneTree
# Chapter commanders share fitted enemy bodies while preserving their own look.
# Inspect actual resources and poses, with a following ordinary soldier checking
# that identity overrides never mutate the shared class or commander records.
const Commanders=preload("res://scripts/commanders.gd")
const Models=preload("res://scripts/revised_enemy_models.gd")
const Imported=preload("res://scripts/imported_fighter.gd")
const Vertices=preload("helpers/authored_vertices.gd")
const Rules=preload("res://scripts/rules.gd")
func _initialize():call_deferred("run")
func run():
 var world=Node3D.new();root.add_child(world);var rules=Rules.new();var models=Models.new();var painter=load("res://scripts/fighters.gd").new()
 var profiles=Commanders.profiles.duplicate(true);var looks=painter.enemy_looks.duplicate(true);var count=0;var samples=0;var lowest=INF
 for chapter in range(12):
  rules.chapter=chapter;rules.start_battle();var saved=rules.save_data("battle").duplicate(true);var rng=rules.rng.state
  var unit=rules.living("enemy").filter(func(value):return value.get("boss",false))[0];var profile=Commanders.profile(unit)
  var actor=models.build(world,unit,Vector3(35,.65,0));assert(actor is Imported and models.models.issues.is_empty(),str(models.models.issues));await process_frame;actor.set_process(false)
  var identity=actor.model.get_node("Identity");identity.set_process(false);var look=looks[unit.job].duplicate(true);look.merge(profile.appearance,true)
  assert(actor.get_meta("commander")==profile.id and actor.model.get_meta("commander")==profile.id)
  assert(actor.get_meta("costume_colors").cloth==Color(look.cloth) and actor.get_meta("costume_colors").cape==Color(look.cape))
  assert(identity.head.get_meta("face_variant")==int(look.face_variant) and identity.cloak.cloth.material_override.get_shader_parameter("tint")==Color(look.cape))
  for material in identity.painted_materials:assert(material.get_shader_parameter("tint")==Color(look.skin if material.get_meta("dye_mode")==3 else look.cloth))
  if profile.appearance.has("crest") or profile.appearance.has("circlet"):
   var color=Color(profile.appearance.get("crest",profile.appearance.get("circlet","ffffff")))
   assert(identity.head.find_children("*","MeshInstance3D",true,false).any(func(mesh):return mesh.material_override is StandardMaterial3D and mesh.material_override.albedo_color==color),"Fitted head retains the commander's own crest or jewel")
  if identity.armor!=null:
   assert(identity.armor.surfaces[0].get_shader_parameter("tint")==Color(look.get("steel","d3d7dc")))
   assert(identity.armor.surfaces[1].get_shader_parameter("tint")==Color(look.get("metal","bca26b")))
  if actor.model.has_node("Mount"):
   var mount=actor.model.get_node("Mount")
   assert(mount.find_children("*","MeshInstance3D",true,false).any(func(mesh):return mesh.material_override is StandardMaterial3D and mesh.material_override.albedo_color==Color(look.cloth)),"Mounted commander retains its saddle cloth color")
  var cache=Vertices.prepare(actor).filter(func(entry):
   var material=entry[0].get_active_material(0)
   return not (material is ShaderMaterial and material.shader.resource_path.ends_with("character.gdshader") and material.get_shader_parameter("cloth_floor_enabled")))
  var mapping=actor.poses.down;var animation=actor.player.get_animation(mapping.clip);animation.loop_mode=Animation.LOOP_NONE
  identity.hair_motion.update(0,"down",2)
  for listener in actor.pose_listeners:listener.combat_pose("down")
  for step in range(129):
   actor.player.stop();actor.player.play(mapping.clip,0);actor.player.seek(lerpf(mapping.from,mapping.to,step/128.0),true,true);actor.player.pause();actor.refresh_skeleton()
   var height=Vertices.minimum(actor,cache)-actor.global_position.y;lowest=minf(lowest,height)
   assert(height>(-.00001 if actor.model.has_node("Mount") else .010),"Commander outfit clears its floor: %s %s %s"%[profile.id,step,height]);samples+=1
  await actor.pose("idle").finished
  var rig=actor.model.get_node("Rig/Armature/Skeleton3D");assert(rig.get_bone_pose_position(rig.find_bone("root")).is_equal_approx(Vector3.ZERO))
  var material=identity.painted_materials[0];actor.queue_free();await process_frame
  var ordinary=unit.duplicate(true);ordinary.boss=false
  actor=models.build(world,ordinary,Vector3.ZERO);assert(actor is Imported and not actor.has_meta("commander") and not actor.model.has_meta("commander"))
  assert(actor.model.get_node("Identity").painted_materials[0]!=material and actor.model.get_meta("costume_colors").cloth==Color(looks[unit.job].cloth))
  actor.queue_free();await process_frame
  for patch in [{"name":"Unknown commander"},{"job":"Duelist"},{"team":"player"},{"promotion":"unsupported"}]:
   var invalid=unit.duplicate(true);invalid.merge(patch,true);assert(models.build(world,invalid,Vector3.ZERO)==null,"Unknown or mismatched commanders keep their original fallback")
  assert(rules.save_data("battle")==saved and rules.rng.state==rng);count+=1
 assert(Commanders.profiles==profiles and painter.enemy_looks==looks)
 world.queue_free();await process_frame
 print("PASS: ",count," revised chapter commanders, original cloth/cape/face/armor/crest/jewel/mount colors, ",samples," complete fall poses with minimum ",lowest," m, fall recovery, ordinary/unknown/promoted fallbacks and private profile/campaign/RNG isolation")
 quit()
