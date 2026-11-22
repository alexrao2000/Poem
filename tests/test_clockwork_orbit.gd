extends SceneTree
## Validate moving source geometry, local batching, clock isolation and actual
## scene teardown. These checks do not evaluate rendered color or appearance.
const Orbit=preload("res://scripts/clockwork_orbit.gd")
const Scenery=preload("res://scripts/scenery.gd")
const Rules=preload("res://scripts/rules.gd")
const Encounters=preload("res://scripts/debug_encounters.gd")
const Shutdown=preload("helpers/game_shutdown.gd")

func _initialize():call_deferred("run")
func run():
 var host=Node3D.new();root.add_child(host);var samples=0
 for theme in ["observatory","engine"]:
  for radius in [1.1,1.875]:
   var orbit=Orbit.new();host.add_child(orbit);orbit.configure(theme,radius,.55 if radius==1.1 else 1.2);orbit.set_process(false);await process_frame
   var meshes=orbit.find_children("*","MeshInstance3D",true,false)
   assert(meshes.size()==4 and orbit.find_children("*","Light3D",true,false).is_empty())
   var vertices=[];var triangles=0
   for mesh in meshes:
    assert(mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
    var arrays=mesh.mesh.surface_get_arrays(0)
    triangles+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null else arrays[Mesh.ARRAY_VERTEX].size())/3
    vertices.append({"mesh":mesh,"points":arrays[Mesh.ARRAY_VERTEX]})
   assert(triangles<4000)
   var first=[orbit.outer.transform,orbit.inner.transform,orbit.core.transform,orbit.core_material.albedo_color]
   for frame in 73:
    orbit.elapsed=Orbit.PERIOD*frame/72.0;orbit.update_motion()
    assert(is_equal_approx(orbit.outer.basis.determinant(),1) and is_equal_approx(orbit.inner.basis.determinant(),1))
    for item in vertices:
     var transform=orbit.global_transform.affine_inverse()*item.mesh.global_transform
     for point in item.points:assert((transform*point).length()<radius*1.15,"Every moving vertex remains inside the mechanism's reserved radius")
    assert(orbit.core.scale.x>=.9799 and orbit.core.scale.x<=1.0201)
    samples+=1
   assert(orbit.outer.transform.is_equal_approx(first[0]) and orbit.inner.transform.is_equal_approx(first[1]) and orbit.core.transform.is_equal_approx(first[2]) and orbit.core_material.albedo_color.is_equal_approx(first[3]),"A bounded clock loops without a pose or pulse discontinuity")
   orbit.elapsed=0;orbit.update_motion();orbit._process(1)
   assert(orbit.outer.transform!=first[0] and orbit.inner.transform!=first[1],"The rings move independently")
   var held=[orbit.elapsed,orbit.outer.transform,orbit.inner.transform,orbit.core_material.albedo_color]
   host.hide();orbit._process(2)
   assert([orbit.elapsed,orbit.outer.transform,orbit.inner.transform,orbit.core_material.albedo_color]==held)
   host.show();orbit._process(.1);assert(orbit.elapsed>held[0])
   var neighbor=Orbit.new();host.add_child(neighbor);neighbor.configure(theme,radius,.55)
   assert(neighbor.core_material!=orbit.core_material and neighbor.elapsed==0,"Each instance owns its pulse material and clock")
   orbit.queue_free();neighbor.queue_free();await process_frame
 var game=Rules.new();var saved=game.save_data("camp").duplicate(true);var random=game.rng.state
 var scenery=Scenery.new()
 for chapter in [8,11]:
  game.chapter=chapter
  var world=Node3D.new();host.add_child(world);scenery.landscape(world,game)
  var arena=Node3D.new();host.add_child(arena);scenery.battle_landscape(arena,Vector3(35,0,0),{"environment":game.info().environment})
  var landmarks=world.find_children("ClockworkOrbit*","Node3D",true,false);var backdrops=arena.find_children("ClockworkOrbit*","Node3D",true,false)
  assert(not landmarks.is_empty() and backdrops.size()==1)
  for node in landmarks+backdrops:
   assert(node is Orbit and node.theme==game.info().environment)
   assert(node.outer.get_child_count()>=2 and node.inner.get_child_count()>=1,"Scenery batching retains independently moving ring groups")
  assert(backdrops[0].position.z<=-10 and backdrops[0].position.x==35,"Large mechanisms stay behind the combat lane")
  world.queue_free();arena.queue_free();await process_frame
 game.chapter=saved.chapter;assert(game.save_data("camp")==saved and game.rng.state==random)
 host.queue_free();await process_frame
 await scenes()
 print("PASS: %d moving geometry samples, four bounded meshes per mechanism, private pulse materials, exact hidden-clock suspension, matching map/arena landmarks and actual normal/Skip cleanup"%samples)
 quit()

func scenes():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-clockwork-%d.json"%Time.get_ticks_usec();root.add_child(app);await process_frame
 app.preferences.values.character_models="revised";app.preferences.values.combat="all"
 for chapter in [8,11]:
  var setup=Encounters.start_recruit(app.game,"lyra","",309,"",chapter);assert(not setup.is_empty())
  app.make_map();app.show_battle()
  var a=app.game.units.filter(func(u):return u.id==setup.actor)[0];var b=app.game.units.filter(func(u):return u.id==setup.target)[0]
  var snapshot=app.game.save_data("battle").duplicate(true);var lighting=app.lighting_state();var refs=[];var observations={"frames":0,"moved":false,"initial":0.0}
  var monitor=func():
   if not app.stage.visible:return
   var orbits=app.stage.find_children("ClockworkOrbit*","Node3D",true,false)
   if orbits.is_empty():return
   if refs.is_empty():
    for orbit in orbits:refs.append(weakref(orbit))
    observations.initial=orbits[0].elapsed
   observations.frames+=1;observations.moved=observations.moved or orbits[0].elapsed>observations.initial+.05
   if chapter==11 and observations.moved:app.skip_combat=true
   var playback=app.ui.get_node_or_null("CombatPlayback")
   if playback!=null:playback.fast_button.button_pressed=true
  process_frame.connect(monitor)
  await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"damage":1,"remaining":19,"hit":true,"crit":false}],{a.id:20,b.id:20})
  process_frame.disconnect(monitor);await process_frame
  assert(observations.moved and observations.frames>2 and not refs.is_empty() and refs.all(func(ref):return ref.get_ref()==null))
  assert(app.game.save_data("battle")==snapshot and app.lighting_state()==lighting and not app.stage.visible)
 await Shutdown.dispose(app)
