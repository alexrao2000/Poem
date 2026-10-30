extends SceneTree
# Check original effect geometry, actual event gating and transformed anchoring.
# These checks do not establish the rendered appearance of the assembled scene.

const Burst=preload("res://scripts/combat_spell_burst.gd")
const Impact=preload("res://scripts/combat_impact.gd")
func _initialize():call_deferred("run")

func run():
 var stage=Node3D.new();root.add_child(stage);stage.position=Vector3(35,2,-8);stage.rotation=Vector3(.1,.42,.07);stage.scale=Vector3.ONE*1.3
 var camera=Camera3D.new();root.add_child(camera);camera.position=Vector3(4,3,8);camera.look_at(Vector3(0,1,0))
 await verify_flights(stage)
 var triangles={};var samples=0
 for folio in ["ember","gale","thunder"]:
  var mesh=Burst.shape(folio);assert(mesh==Burst.shape(folio),"Each element reuses one immutable impact mesh")
  var arrays=mesh.surface_get_arrays(0);var points=arrays[Mesh.ARRAY_VERTEX];var colors=arrays[Mesh.ARRAY_COLOR]
  assert(points.size()%3==0 and points.size()>90 and points.size()<650,"One additive batch contains bounded elemental detail")
  triangles[folio]=points.size()/3
  for i in range(0,points.size(),3):
   assert((points[i+1]-points[i]).cross(points[i+2]-points[i]).length_squared()>1e-14,"Tapered ends omit collapsed triangles")
  for point in points:assert(point.y>=.015 and point.y<=2.701 and Vector2(point.x,point.z).length()<.8,"Bursts stay above the contact floor inside a narrow local column")
  assert(colors.size()==points.size() and Array(colors).all(func(color):return color.a>0 and color.a<=1),"Every vertex carries its element's color")
  for height in [.9,1.1,1.85]:
   for critical in [false,true]:
    var ground=Vector3(34,2.3,-7);var effect=Burst.new();stage.add_child(effect)
    effect.begin(folio,ground,height,critical,Impact.accent_material());effect.set_process(false)
    assert(effect.get_child_count()==1 and effect.body.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Spatial impacts add one unshadowed mesh without lights")
    assert(effect.body.material_override.blend_mode==BaseMaterial3D.BLEND_MODE_ADD and not effect.body.material_override.no_depth_test,"Translucent elements respect scene depth")
    var previous_alpha=1.0
    for frame in range(17):
     effect.progress=frame/16.0;effect.apply_progress()
     assert(effect.global_position.distance_to(ground)<.00001 and effect.global_basis.is_equal_approx(Basis.IDENTITY),"A tilted scaled parent cannot tilt the vertical discharge or move its floor")
     var alpha=effect.body.material_override.albedo_color.a
     assert(alpha>=0 and alpha<=previous_alpha,"Local light fades continuously without repeated flashes");previous_alpha=alpha
     for point in points:
      var world=effect.body.to_global(point)
      assert(world.y>=ground.y and world.y<ground.y+5 and Vector2(world.x-ground.x,world.z-ground.z).length()<1.2,"Growing wind/flame/lightning remain bounded around infantry and mounted recipients")
     samples+=1
    assert(is_zero_approx(previous_alpha),"Effect fades completely before deletion")
    effect.queue_free();await process_frame
  for event in [{"hit":true,"damage":3,"crit":false},{"hit":true,"damage":8,"crit":true},{"hit":true,"damage":0,"crit":false},{"hit":false,"damage":0,"crit":false}]:
   var effect=Impact.new();root.add_child(effect);effect.configure(Vector3(0,1.1,0),event,camera,folio,Vector3.ZERO);effect.motion.kill()
   assert((effect.elemental!=null)==(event.hit and event.damage>0),"Only confirmed damaging spells create an elemental burst; guards and misses stay restrained")
   if effect.elemental!=null:
    var reference=weakref(effect.elemental);effect.elemental._process(Burst.DURATION+.01);await process_frame
    assert(reference.get_ref()==null and is_instance_valid(effect.amount),"Element clears promptly while the readable damage number can finish")
   effect.queue_free();await process_frame
 assert(triangles.ember!=triangles.gale and triangles.gale!=triangles.thunder,"Element geometries differ beyond recoloring")
 var effect=Burst.new();stage.add_child(effect);effect.begin("gale",Vector3.ZERO,1.1,false,Impact.accent_material())
 var reference=weakref(effect);stage.queue_free();await process_frame
 assert(reference.get_ref()==null,"Skipping or clearing the arena removes its active effect immediately")
 camera.queue_free();await process_frame
 print("PASS: %s elemental triangles; %d infantry/mounted/critical animation samples, closed timing, transformed ground anchoring, event gating and cleanup"%[triangles,samples])
 quit()

func verify_flights(stage):
 var Projectile=preload("res://scripts/combat_projectile.gd");var samples=0
 for element in ["ember","gale","thunder",""]:
  for direction in [-1,1]:
   for vertical in [false,true]:
    var origin=Vector3(34,2.2,-7);var target=origin+Vector3(0,2.0*direction,.001) if vertical else origin+Vector3(direction*4,.65*direction,.2)
    var shot=Projectile.new();stage.add_child(shot);shot.launch(origin,target,"magic",1,element).kill();shot.set_process(false)
    assert(shot.global_basis.is_equal_approx(Basis.IDENTITY),"Projectile dimensions use world meters even beneath a tilted, scaled parent")
    assert(shot.wake.get_parent()==shot and shot.wake.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Magic wake is one owned unshadowed mesh")
    assert(shot.body.get_node("SpellGlow").material_override.albedo_texture!=null and shot.body.get_node("SpellGlow").material_override.billboard_mode==BaseMaterial3D.BILLBOARD_ENABLED,"A small soft halo remains camera-facing around the distinct elemental core")
    var gradient=shot.body.get_node("SpellGlow").material_override.albedo_texture
    assert(gradient.fill==GradientTexture2D.FILL_RADIAL and gradient.gradient.sample(1).a==0 and gradient.gradient.sample(0).a>.8,"Halo definition fades fully to transparent outside a bright center")
    for core in shot.body.get_children():
     if core.mesh is SphereMesh:assert(core.material_override.cull_mode==BaseMaterial3D.CULL_BACK,"Orb backfaces do not double the additive core brightness")
     assert(core.material_override.blend_mode==BaseMaterial3D.BLEND_MODE_ADD and core.material_override.albedo_color.a<1 and core.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Elemental flight glows instead of casting opaque bead shadows")
    for progress in [0.0,.025,.12,.5,1.0]:
     shot.progress=progress;shot._process(0)
     assert(shot.global_position.distance_to(shot.point_at(progress))<.00001)
     if progress==0:assert(not shot.wake.visible,"No tail exists before any distance is travelled");continue
     var arrays=shot.wake.mesh.surface_get_arrays(0);var points=arrays[Mesh.ARRAY_VERTEX];var colors=arrays[Mesh.ARRAY_COLOR]
     assert(shot.wake.visible and points.size()>90 and points.size()<=384,"Continuous crossed wake uses a bounded single surface")
     for i in range(0,points.size(),3):assert((points[i+1]-points[i]).cross(points[i+2]-points[i]).length_squared()>1e-15,"Tapered tail omits collapsed end faces")
     var along=(target-origin).normalized();var oldest=shot.point_at(maxf(0,progress-.28));var latest=shot.point_at(progress)
     var low=(oldest-origin).dot(along);var high=(latest-origin).dot(along)
     for i in range(points.size()):
      var world=shot.wake.to_global(points[i]);var distance=(world-origin).dot(along)
      assert(distance>=low-.012 and distance<=high+.012,"Tail follows only the already-travelled interval and cannot project ahead of the spell")
      assert(world.distance_to(Geometry3D.get_closest_point_to_segment(world,oldest,latest))<.13,"Tail remains narrow around its curved flight")
      assert(colors[i].a>=0 and colors[i].a<=.451,"Wake edges and oldest center taper to transparency")
     assert(Array(colors).any(func(color):return color.a==0) and Array(colors).any(func(color):return color.a>.4),"Wake has a luminous center and soft transparent edges")
     samples+=1
    var reference=weakref(shot.wake);shot.queue_free();await process_frame
    assert(reference.get_ref()==null,"Completing or skipping flight releases its wake")
 print("PASS: %d elemental flight samples, continuous additive wake, transformed/vertical flights, bounded soft edges and cleanup"%samples)
