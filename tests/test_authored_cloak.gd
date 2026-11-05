extends SceneTree
const Models=preload("res://scripts/debug_duelist_models.gd")
const Rules=preload("res://scripts/rules.gd")
const Fighters=preload("res://scripts/fighters.gd")
const HitStop=preload("res://scripts/combat_hit_stop.gd")
const Defeat=preload("res://scripts/combat_defeat.gd")
func _initialize():call_deferred("run")
func run():
 var world=Node3D.new();world.position=Vector3(0,2.7,0);root.add_child(world)
 var models=Models.new();var rules=Rules.new();var painter=Fighters.new();var count=0
 for id in ["nell","silas"]:
  var unit=rules.roster.filter(func(value):return value.id==id)[0].duplicate(true);unit.team="player"
  var actor=models.build(world,unit,Vector3(35,0,0));var other=models.build(world,unit,Vector3(40,0,0));await process_frame;await process_frame
  var identity=actor.model.get_node("Identity");var cloak=identity.cloak;var mesh=cloak.cloth;var material=mesh.material_override
  var second=other.model.get_node("Identity").cloak
  assert(mesh.mesh==painter.Capes.mesh("forked") and mesh.mesh==second.cloth.mesh,"Original duelist cut shares immutable geometry")
  assert(material!=second.cloth.material_override and material.get_shader_parameter("tint")==Color(painter.profiles[id].appearance.cape))
  assert(material.get_shader_parameter("cape_mark")==painter.COMPANY_CAPE and material.get_shader_parameter("cloth_amount")==1.0,"Original company embroidery remains attached to animated cloth")
  assert(material.get_shader_parameter("cloth_floor_enabled") and is_equal_approx(material.get_shader_parameter("cloth_floor_y"),2.718),"The floor plane follows the actual stage height")
  assert(mesh.extra_cull_margin>=.1 and cloak.anchor in actor.attachments,"Culling and direct clip samples include the fitted cloak")
  var rig=cloak.anchor.get_skeleton()
  var anchors=[]
  for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
   if is_zero_approx(vertex.y):anchors.append(vertex)
  for pose_key in ["idle","advance","windup","strike","recover","hit","evade","down","victory"]:
   var mapping=actor.poses[pose_key]
   for sample in range(17):
    actor.player.play(mapping.clip,0);actor.player.advance(.1);actor.player.seek(lerpf(mapping.from,mapping.to,sample/16.0),true,true);actor.player.pause();actor.refresh_skeleton()
    for vertex in anchors:
     var position=mesh.to_global(vertex);var nearest=INF
     for name_value in ["upperarm_l","upperarm_r","neck_01"]:
      var point=rig.to_global(rig.get_bone_global_pose(rig.find_bone(name_value)).origin)
      nearest=minf(nearest,point.distance_to(position))
     assert(nearest<.25,"The complete top edge stays near the shoulders/neck throughout actual clips")
    count+=1
  actor.pose("advance",.1);await create_timer(.2).timeout;var driven=cloak.motion.drive
  assert(driven>.5 and driven<.9)
  actor.pose("idle",.1);await create_timer(.3).timeout;assert(cloak.motion.drive<driven)
  var stop=HitStop.new();world.add_child(stop);var hold=stop.play([actor],.12);var clock=cloak.elapsed;var other_clock=second.elapsed
  await create_timer(.04).timeout;assert(cloak.elapsed==clock and second.elapsed>other_clock,"Hit-stop freezes only the held actor's cloth clock")
  await hold.finished
  actor.hide();clock=cloak.elapsed;await create_timer(.04).timeout;assert(cloak.elapsed==clock,"Hidden models do not advance cloth")
  actor.show();world.position.y=4.1;await process_frame;await process_frame
  assert(is_equal_approx(material.get_shader_parameter("cloth_floor_y"),4.118),"Relocated stages update the floor without sharing materials")
  actor.pose("down",.1);var blink=identity.blink.surface;var fade=Defeat.new();world.add_child(fade);fade.begin(actor);fade.motion.pause()
  assert(cloak.motion.surfaces[0]==fade.copies[material] and mesh.material_override==cloak.motion.surfaces[0],"Cloth continues updating the actual fading material")
  assert(identity.blink.surface==fade.copies[blink],"Imported face expressions also rebind after material cloning")
  var fade_clock=cloak.motion.surfaces[0].get_shader_parameter("cloth_clock");await create_timer(.03).timeout
  assert(cloak.motion.surfaces[0].get_shader_parameter("cloth_clock")>fade_clock)
  fade.apply_visibility(.5);assert(cloak.motion.surfaces[0].get_shader_parameter("defeat_visibility")==.5)
  assert(not second.cloth.material_override.shader.code.contains("defeat_visibility"),"The surviving cloak retains its normal shader")
  fade.queue_free();actor.queue_free();other.queue_free();await process_frame;world.position.y=2.7
 assert(not painter.painted(Color("355f98"),0).get_shader_parameter("cloth_floor_enabled"),"Shared procedural body fabric never receives imported floor contact")
 world.queue_free();await process_frame
 print("PASS: ",count," actual cloak poses with shoulder-edge attachment, original forked geometry/palette/embroidery, private motion/floor planes, hit-stop/visibility, fade/face rebinding and unchanged shared materials")
 quit()
