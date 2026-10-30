extends SceneTree
const Charge=preload("res://scripts/combat_charge.gd")
func _initialize():call_deferred("run")

func run():
 var fighters=load("res://scripts/fighters.gd").new()
 var rules=load("res://scripts/rules.gd").new()
 var stage=Node3D.new();root.add_child(stage)
 stage.position=Vector3(35,2,-8);stage.rotation.y=.42;stage.scale=Vector3.ONE*1.2
 var bindings=0
 for unit in rules.roster.filter(func(u):return u.weapon=="magic"):
  unit=unit.duplicate(true);unit.team="player"
  for direction in [-1,1]:
   var actor=fighters.build(stage,unit,Vector3(direction*2,0,0));actor.rotation.y=direction*PI/2;actor.set_process(false)
   for folio in ["ember","gale","thunder"]:
    var effect=Charge.new();stage.add_child(effect);effect.begin(actor,folio,.28);effect.motion.kill();effect.set_process(false)
    assert(effect.motes.size()==3 and effect.get_child_count()==4,"Gathering uses four small meshes and no extra lights")
    for pose in ["windup","critical_windup","strike"]:
     actor.pose(pose,1).custom_step(1)
     for strength in [0.0,.5,1.0]:
      effect.strength=strength;effect._process(.03)
      assert(effect.global_position.distance_to(actor.socket_position("projectile"))<.0001,"Effect follows the live casting socket beneath a transformed stage")
      assert(effect.global_basis.is_equal_approx(actor.global_basis.orthonormalized()),"Gathering keeps the actor's facing without inheriting a scale")
      for mesh in [effect.ring]+effect.motes:
       assert(mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and mesh.material_override.blend_mode==BaseMaterial3D.BLEND_MODE_ADD)
       var box=mesh.mesh.get_aabb()
       for corner in range(8):
        var vertex=mesh.to_global(box.get_endpoint(corner))
        assert(vertex.distance_to(effect.global_position)<.36,"Elemental gathering stays within 36 cm of the hand")
       assert(mesh.material_override.albedo_color.a<=.7 and mesh.material_override.albedo_color.a>=0)
    effect.strength=1;effect.release();effect.motion.kill()
    var released_position=effect.global_position
    actor.position.x+=1;effect._process(.1)
    assert(effect.global_position==released_position,"Dissipating charge stays at the actual launch point")
    actor.position.x-=1;effect.queue_free();bindings+=1
   actor.queue_free();await process_frame
 var sample=rules.roster.filter(func(u):return u.weapon=="magic")[0].duplicate(true);sample.team="player"
 var actor=fighters.build(stage,sample,Vector3.ZERO)
 var effect=Charge.new();stage.add_child(effect);effect.begin(actor,"gale",.04)
 await effect.motion.finished
 assert(is_equal_approx(effect.strength,1),"Anticipation reaches its authored strength")
 var reference=weakref(effect);effect.release();await effect.motion.finished;await process_frame
 assert(reference.get_ref()==null,"Released gathering cleans up promptly")
 effect=Charge.new();stage.add_child(effect);effect.begin(actor,"thunder",.1);reference=weakref(effect)
 actor.queue_free();await process_frame;await process_frame
 assert(reference.get_ref()==null,"Removing a caster also releases its gathering")
 stage.queue_free();await process_frame
 print("PASS: %d caster/element/facing bindings, transformed hand attachment, bounded additive geometry, release anchoring and cleanup"%bindings)
 quit()
