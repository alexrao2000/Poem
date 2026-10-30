extends SceneTree
const Charge=preload("res://scripts/combat_charge.gd")
const Seal=preload("res://scripts/casting_seal.gd")
func _initialize():call_deferred("run")

func run():
 var fighters=load("res://scripts/fighters.gd").new()
 var rules=load("res://scripts/rules.gd").new()
 var stage=Node3D.new();root.add_child(stage)
 stage.position=Vector3(35,2,-8);stage.rotation=Vector3(.12,.42,-.08);stage.scale=Vector3.ONE*1.2
 verify_geometry()
 var bindings=0
 for unit in rules.roster.filter(func(u):return u.weapon=="magic"):
  unit=unit.duplicate(true);unit.team="player"
  for direction in [-1,1]:
   var actor=fighters.build(stage,unit,Vector3(direction*2,0,0));actor.rotation.y=direction*PI/2;actor.set_process(false)
   for folio in ["ember","gale","thunder"]:
    var effect=Charge.new();stage.add_child(effect);effect.begin(actor,folio,.28);effect.motion.kill();effect.set_process(false)
    assert(effect.motes.size()==3 and effect.get_child_count()==5,"Gathering uses four hand meshes and one ground seal without lights")
    for pose in ["windup","critical_windup","strike"]:
     actor.pose(pose,1).custom_step(1)
     for strength in [0.0,.5,1.0]:
      effect.strength=strength;effect._process(.03)
      assert(effect.global_position.distance_to(actor.socket_position("projectile"))<.0001,"Effect follows the live casting socket beneath a transformed stage")
      assert(effect.global_basis.is_equal_approx(actor.global_basis.orthonormalized()),"Gathering keeps the actor's facing without inheriting a scale")
      assert(effect.seal.global_position.distance_to(actor.global_position+Vector3.UP*.025)<.0001,"Seal stays at the caster floor, separately from the raised hand")
      assert(effect.seal.global_basis.y.is_equal_approx(Vector3.UP),"Casting seal stays horizontal beneath a rotated scaled actor")
      assert(effect.seal.global_basis.x.length()>=.72-.0001 and effect.seal.global_basis.x.length()<=1.0001,"Seal gathers within a fixed 1.4 m footprint")
      assert(is_equal_approx(effect.seal.material_override.albedo_color.a,strength*.52),"Seal fades in once with the anticipation strength")
      assert(not effect.seal.material_override.no_depth_test and effect.seal.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Seal remains depth-tested, unshadowed additive detail")
      assert(effect.seal.mesh==Seal.shape(folio),"All casters of a folio share immutable seal geometry")
      for mesh in [effect.ring]+effect.motes:
       assert(mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and mesh.material_override.blend_mode==BaseMaterial3D.BLEND_MODE_ADD)
       var box=mesh.mesh.get_aabb()
       for corner in range(8):
        var vertex=mesh.to_global(box.get_endpoint(corner))
        assert(vertex.distance_to(effect.global_position)<.36,"Elemental gathering stays within 36 cm of the hand")
       assert(mesh.material_override.albedo_color.a<=.7 and mesh.material_override.albedo_color.a>=0)
    effect.strength=1;effect.release();effect.motion.kill()
    var released_position=effect.global_position
    var released_floor=effect.seal.global_position
    var last_extent=effect.seal.global_basis.x.length()
    actor.position.x+=1;effect._process(.1)
    assert(effect.global_position==released_position,"Dissipating charge stays at the actual launch point")
    for strength in [.75,.5,.25,0.0]:
     effect.strength=strength;effect._process(.02)
     assert(effect.seal.global_position.distance_to(released_floor)<.00001,"Released seal stays at its casting floor while the actor moves")
     var extent=effect.seal.global_basis.x.length()
     assert(extent>=last_extent-.0001 and extent<=1.1401,"Released seal expands gently as it fades, instead of shrinking back")
     last_extent=extent
    assert(is_zero_approx(effect.seal.material_override.albedo_color.a),"Seal reaches zero opacity before cleanup")
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

func verify_geometry():
 var counts=[]
 for folio in ["ember","gale","thunder"]:
  var mesh=Seal.shape(folio);assert(mesh.get_surface_count()==1)
  var arrays=mesh.surface_get_arrays(0);var points=arrays[Mesh.ARRAY_VERTEX];var colors=arrays[Mesh.ARRAY_COLOR]
  counts.append(points.size()/3)
  assert(points.size()>1000 and points.size()<2000,"Ornament remains one small cached batch")
  for i in range(0,points.size(),3):
   assert((points[i+1]-points[i]).cross(points[i+2]-points[i]).length_squared()>1e-14,"Ring and glyph segments have noncollapsed triangles")
  for i in range(points.size()):
   assert(is_zero_approx(points[i].y) and points[i].length()<.71,"All strokes lie on a bounded ground plane")
   assert(is_zero_approx(colors[i].a) or is_equal_approx(colors[i].a,.8),"Every stroke has a bright spine and transparent outer edge")
  assert(Array(colors).any(func(color):return color.a==0),"Untextured seal edges fade out")
 assert(counts[0]!=counts[1] and counts[1]!=counts[2],"Flame, wind and thunder use different glyph geometry")
 print("PASS: %s casting-seal triangles, three original glyph sets, soft edges and shared geometry"%[counts])
