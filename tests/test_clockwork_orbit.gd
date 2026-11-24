extends SceneTree
## Validate moving source geometry, local batching, clock isolation and actual
## scene teardown. These checks do not evaluate rendered color or appearance.
const Orbit=preload("res://scripts/clockwork_orbit.gd")
const Scenery=preload("res://scripts/scenery.gd")
const Rules=preload("res://scripts/rules.gd")
const Encounters=preload("res://scripts/debug_encounters.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
const CombatCamera=preload("res://scripts/combat_camera.gd")

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
   var nearby=neighbor.find_children("*","MeshInstance3D",true,false)
   for index in 3:assert(nearby[index].mesh==meshes[index].mesh and nearby[index]!=meshes[index])
   assert((neighbor.core.mesh==orbit.core.mesh)==(radius==1.1),"Identical core dimensions use one sphere")
   assert(neighbor.outer!=orbit.outer and neighbor.inner!=orbit.inner and neighbor.core!=orbit.core)
   assert(neighbor.outer.get_meta("batch_stats")==orbit.outer.get_meta("batch_stats"))
   orbit.queue_free();neighbor.queue_free();await process_frame
 verify_clockwork_cache_boundaries(host)
 var game=Rules.new();var saved=game.save_data("camp").duplicate(true);var random=game.rng.state
 var scenery=Scenery.new();scenery.batching_enabled=false
 for chapter in [8,11]:
  game.chapter=chapter
  var world=Node3D.new();host.add_child(world);scenery.landscape(world,game)
  var row=1 if chapter==8 else 4
  var context=scenery.combat_context(game,{"x":10,"y":row},{"x":11,"y":row})
  assert(context.landmarks.size()==1 and context.landmarks[0].kind==context.environment)
  var arena=Node3D.new();host.add_child(arena);scenery.battle_landscape(arena,Vector3(35,0,0),context)
  var landmarks=world.find_children("ClockworkOrbit*","Node3D",true,false);var backdrops=arena.find_children("ClockworkOrbit*","Node3D",true,false)
  assert(landmarks.size()==1 and backdrops.size()==1,"A mapped clockwork landmark contributes one arena mechanism")
  var anchor=backdrops[0].global_position
  var expected=Vector3(35+clampf(context.landmarks[0].x,-3.8,3.8),2.6 if chapter==8 else 3.45,minf(context.landmarks[0].z,-10 if chapter==8 else -12))
  assert(anchor.is_equal_approx(expected),"The mechanism stays behind the lane while retaining the landmark side")
  if chapter==11:
   verify_chamber(landmarks[0],-.07)
   var basin=arena.get_node("EngineBasinWater")
   assert(basin.material_override==scenery.water_material("engine"))
   assert(basin.position.z+basin.mesh.size.y*.5<-6,"The water basin stays behind the fighting lane")
   verify_chamber(backdrops[0],basin.position.y)
   var rims=arena.find_children("EngineBasinRim*","MeshInstance3D",false,false)
   assert(rims.size()==4)
   for rim in rims:
    var side=rim.transform*rim.mesh.get_aabb()
    assert(side.position.y<basin.position.y and side.end.y>basin.position.y,"All four basin rims cross the waterline")
   assert(landmarks[0].get_parent().scale.is_equal_approx(Vector3.ONE*.46) and backdrops[0].get_parent().scale==Vector3.ONE)
   var map_shaft=landmarks[0].get_parent().get_node("EnginePylonShaft")
   var arena_shaft=backdrops[0].get_parent().get_node("EnginePylonShaft")
   assert(map_shaft.mesh==arena_shaft.mesh and map_shaft.material_override==arena_shaft.material_override,"Map and close-up chamber share structure and finish")
  else:
   verify_meridian(landmarks[0],-.15,1.1)
   verify_meridian(backdrops[0],-.06,1.54)
   await verify_meridian_wide(arena,Vector3(35,0,0))
  scenery.batcher.combine(world);scenery.batcher.combine(arena)
  for node in landmarks+backdrops:
   assert(node is Orbit and node.theme==game.info().environment)
   assert(node.outer.get_child_count()>=2 and node.inner.get_child_count()>=1,"Scenery batching retains independently moving ring groups")
  var fallback=Node3D.new();host.add_child(fallback)
  scenery.battle_landscape(fallback,Vector3(35,0,0),{"environment":context.environment})
  var centered=fallback.find_children("ClockworkOrbit*","Node3D",true,false)
  assert(centered.size()==1 and is_equal_approx(centered[0].global_position.x,35))
  if chapter==8:
   verify_meridian(centered[0],-.06,1.54)
   await verify_meridian_wide(fallback,Vector3(35,0,0))
   var mirrored=Node3D.new();host.add_child(mirrored)
   var reversed=scenery.combat_context(game,{"x":10,"y":row},{"x":11,"y":row},-1)
   scenery.battle_landscape(mirrored,Vector3(35,0,0),reversed)
   var other=mirrored.get_node("ClockworkOrbit")
   assert(is_equal_approx(other.global_position.x+anchor.x,70))
   verify_meridian(other,-.06,1.54)
   await verify_meridian_wide(mirrored,Vector3(35,0,0))
   mirrored.queue_free()
  world.queue_free();arena.queue_free();fallback.queue_free();await process_frame
 game.chapter=saved.chapter;assert(game.save_data("camp")==saved and game.rng.state==random)
 host.queue_free();await process_frame
 await scenes()
 print("PASS: %d moving geometry samples, one arena mechanism per landmark, four grounded Sun Engine pylons with ring clearance, hidden-clock suspension and actual normal/Skip cleanup"%samples)
 print("PASS: Starfall's grounded meridian dais and brass dial clear the moving rings, with planted columns and eighteen wide-shot projections")
 quit()

func verify_clockwork_cache_boundaries(host: Node3D):
 var before_rings=Orbit.rings.duplicate()
 var before_cores=Orbit.cores.duplicate()
 for index in Orbit.MAX_RING_SHAPES+3:
  var orbit=Orbit.new();host.add_child(orbit)
  orbit.configure("observatory",2+.13*index,.8+.08*index)
  assert(orbit.outer.get_child_count()==2 and orbit.inner.get_child_count()==1)
  orbit.free()
 assert(Orbit.rings.size()==Orbit.MAX_RING_SHAPES)
 assert(Orbit.cores.size()==Orbit.MAX_CORE_SHAPES)
 assert(before_rings.keys().all(func(key):return Orbit.rings[key]==before_rings[key]))
 assert(before_cores.keys().all(func(key):return Orbit.cores[key]==before_cores[key]))
 Orbit.rings=before_rings;Orbit.cores=before_cores
 print("PASS: repeated clockwork shares immutable rings and cores with bounded caches and independent transforms")

func verify_chamber(orbit: Node3D,ground_height: float):
 var chamber=orbit.get_parent()
 var foundation=chamber.get_node("EngineFoundation")
 var base=foundation.global_transform*foundation.mesh.get_aabb()
 assert(base.position.y<ground_height and base.end.y>ground_height)
 var feet=chamber.find_children("EnginePylonFoot*","MeshInstance3D",false,false)
 var shafts=chamber.find_children("EnginePylonShaft*","MeshInstance3D",false,false)
 var crowns=chamber.find_children("EnginePylonCrown*","MeshInstance3D",false,false)
 var braces=chamber.find_children("EngineBrace*","MeshInstance3D",false,false)
 assert(feet.size()==4 and shafts.size()==4 and crowns.size()==4 and braces.size()==2)
 for index in 4:
  var shaft=shafts[index].transform*shafts[index].mesh.get_aabb()
  var foot=feet[index].transform*feet[index].mesh.get_aabb()
  var crown=crowns[index].transform*crowns[index].mesh.get_aabb()
  var ground=feet[index].global_transform*feet[index].mesh.get_aabb()
  assert(shaft.intersects(foot) and shaft.intersects(crown) and ground.position.y<ground_height)
 for part in chamber.get_children():
  if not part is MeshInstance3D:continue
  var bounds=part.transform*part.mesh.get_aabb()
  var nearest=orbit.position.clamp(bounds.position,bounds.end)
  assert(nearest.distance_to(orbit.position)>1.875*1.15,"Stationary containment stays outside the full swept ring volume")

func verify_meridian(orbit: Node3D,ground_height: float,radius: float):
 var dais=orbit.get_parent().get_node("ObservatoryDais")
 var base=dais.get_node("MeridianFooting")
 var foundation=base.global_transform*base.mesh.get_aabb()
 assert(foundation.position.y<ground_height and foundation.end.y>ground_height,"The plinth intersects the land beneath it")
 var names=["MeridianFooting","MeridianPlinth","MeridianTable","MeridianRim","MeridianDial"]
 var previous=AABB()
 for name in names:
  var part=dais.get_node(name)
  var bounds=part.transform*part.mesh.get_aabb()
  if name!=names[0]:assert(bounds.intersects(previous),"Every level of the plinth supports the next")
  previous=bounds
 var ticks=dais.find_children("MeridianTick*","MeshInstance3D",false,false)
 var axes=dais.find_children("MeridianAxis*","MeshInstance3D",false,false)
 assert(ticks.size()==12 and axes.size()==2)
 assert(ticks.filter(func(mark):return mark.scale.z>.2).size()==4)
 for marker in ticks+axes:
  var bounds=marker.transform*marker.mesh.get_aabb()
  assert(bounds.intersects(previous),"Marks lie on the actual dial")
 for part in dais.get_children():
  var bounds=part.global_transform*part.mesh.get_aabb()
  var nearest=orbit.global_position.clamp(bounds.position,bounds.end)
  assert(nearest.distance_to(orbit.global_position)>radius*1.15,"Stone and dial stay outside the complete swept ring radius")

func verify_meridian_wide(arena: Node3D,center: Vector3):
 var dais=arena.get_node("ObservatoryDais")
 var shafts=arena.find_children("ObservatoryColumnShaft*","MeshInstance3D",false,false)
 var bases=arena.find_children("ObservatoryColumnBase*","MeshInstance3D",false,false)
 var capitals=arena.find_children("ObservatoryColumnCapital*","MeshInstance3D",false,false)
 assert(shafts.size()==6 and bases.size()==6 and capitals.size()==6)
 var silhouettes=[]
 for index in 6:
  var foot=bases[index].global_transform*bases[index].mesh.get_aabb()
  var shaft=shafts[index].global_transform*shafts[index].mesh.get_aabb()
  var capital=capitals[index].global_transform*capitals[index].mesh.get_aabb()
  assert(foot.position.y<center.y-.06 and foot.intersects(shaft) and shaft.intersects(capital))
  silhouettes.append(foot.merge(shaft).merge(capital))
 var viewport=SubViewport.new()
 viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var camera=Camera3D.new();viewport.add_child(camera);camera.current=true
 var edges=[dais.global_position+Vector3(-1.08,.5895,.60),dais.global_position+Vector3(1.08,.5895,.60)]
 for mounted in [false,true]:
  var shot=CombatCamera.frame_pair(center+Vector3.LEFT*1.6,center+Vector3.RIGHT*1.6,"wide",false,mounted)
  camera.position=shot.anchor;camera.fov=shot.lens;camera.look_at(shot.focus)
  for dimensions in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
   viewport.size=dimensions;await process_frame
   var safe=Rect2(Vector2(20,20),Vector2(dimensions)-Vector2(40,174))
   assert(edges.any(func(point):
    var clear=not silhouettes.any(func(pillar):return pillar.intersects_segment(camera.global_position,point)!=null)
    return clear and not camera.is_position_behind(point) and safe.has_point(camera.unproject_position(point))
   ),"At least one bronze rim point stays clear of the columns and HUD")
 viewport.queue_free();await process_frame

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
   assert(orbits.size()==1)
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
