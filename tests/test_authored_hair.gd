extends SceneTree
const Models=preload("res://scripts/combat_models.gd")
const Rules=preload("res://scripts/rules.gd")
const HitStop=preload("res://scripts/combat_hit_stop.gd")
func _initialize():call_deferred("run")
func run():
 var studies=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json"));var rules=Rules.new();var stage=Node3D.new();root.add_child(stage);var samples=0
 for id in ["vela","noor"]:
  var spec=studies.caster_female.duplicate(true);spec.appearance="Identity"
  var models=Models.new("");models.catalog={"characters":{id:spec}}
  var unit=rules.roster.filter(func(value):return value.id==id)[0].duplicate(true);unit.team="player"
  var actor=models.build(stage,unit,Vector3(35,0,0));var other=models.build(stage,unit,Vector3(39,0,0));await process_frame
  var identity=actor.model.get_node("Identity");var other_identity=other.model.get_node("Identity");identity.set_process(false)
  var motion=identity.hair_motion;var hair=motion.root;var anchor=hair.position
  assert(hair.get_parent()==identity.head and hair.get_meta("dynamic") and hair.get_child_count()>0)
  assert(other_identity.hair_motion.root!=hair and other_identity.hair_motion!=motion,"Imported identities never share hair pose state")
  var meshes=hair.find_children("*","MeshInstance3D",true,false);var vertices=[]
  for mesh in meshes:
   for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:vertices.append(identity.head.to_local(mesh.to_global(vertex)))
  var fixed=identity.head.get_children().filter(func(node):return node!=hair);var transforms=fixed.map(func(node):return node.transform)
  var maximum=0.0;var clock=0.0
  for key in ["idle","advance","critical_windup","strike","recover","hit","evade","down"]:
   actor.pose(key,.01);actor.pose_tween.kill();actor.player.pause()
   for delta in [.016,.033,.1,.5]:
    clock+=delta;motion.update(clock,key,delta)
    assert(hair.position==anchor and fixed.map(func(node):return node.transform)==transforms,"Loose motion keeps scalp root, face and fringe fixed beneath the animated head")
    assert(absf(hair.rotation.x)<=motion.strength+.000001 and absf(hair.rotation.z)<=motion.strength+.000001)
    var index=0
    for mesh in meshes:
     for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
      var moved=identity.head.to_local(mesh.to_global(vertex)).distance_to(vertices[index]);maximum=maxf(maximum,moved);index+=1
      assert(moved<.12,"Styled loose lengths stay within their bounded original motion envelope")
    samples+=1
  assert(maximum>.005)
  motion.update(clock,"down",1);assert(motion.angle.length()<.001)
  identity.set_process(true);actor.pose("idle",.01);await process_frame
  var stop=HitStop.new();stage.add_child(stop);var pause=stop.play([actor],.1);pause.pause()
  var frozen=motion.angle;var elapsed=identity.elapsed;var other_clock=other_identity.elapsed
  for frame in range(3):await process_frame
  assert(motion.angle==frozen and identity.elapsed==elapsed and other_identity.elapsed>other_clock,"Local hit-stop freezes styled hair without stopping other identities")
  pause.play();await pause.finished
  actor.hide();elapsed=identity.elapsed;frozen=motion.angle
  for frame in range(3):await process_frame
  assert(identity.elapsed==elapsed and motion.angle==frozen,"Hidden imported identities suspend both hair and expression clocks")
  actor.show()
  for frame in range(3):await process_frame
  assert(identity.elapsed>elapsed and motion.angle!=frozen)
  var fade=load("res://scripts/combat_defeat.gd").new();stage.add_child(fade);fade.begin(actor);fade.apply_visibility(.4)
  for mesh in meshes:
   for surface in range(mesh.mesh.get_surface_count()):
    var material=mesh.get_active_material(surface)
    assert((material is ShaderMaterial and is_equal_approx(material.get_shader_parameter("defeat_visibility"),.4)) or (material is BaseMaterial3D and is_equal_approx(material.albedo_color.a,.4)),"Loose imported hair participates in defeat fading")
  fade.queue_free();actor.queue_free();other.queue_free();await process_frame
 var short=studies.caster.duplicate(true);short.appearance="Identity";var models=Models.new("");models.catalog={"characters":{"tarin":short}}
 var unit=rules.roster.filter(func(value):return value.id=="tarin")[0].duplicate(true);unit.team="player";var actor=models.build(stage,unit,Vector3.ZERO)
 assert(actor.model.get_node("Identity").hair_motion.root==null,"Short-haired identities keep their existing static hair")
 stage.queue_free();await process_frame
 print("PASS: ",samples," styled braid/long-hair samples, stable scalp/fringe geometry, bounded motion, private controllers, local hit-stop, hidden clocks and defeat fades")
 quit()
