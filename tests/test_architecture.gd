extends SceneTree
const Cloth=preload("res://scripts/wind_cloth.gd")
const Roof=preload("res://scripts/architecture.gd")
const Scenery=preload("res://scripts/scenery.gd")
const Rules=preload("res://scripts/rules.gd")
const HarborBoat=preload("res://scripts/harbor_boat.gd")
const HarborNet=preload("res://scripts/harbor_net.gd")
const HarborSignal=preload("res://scripts/harbor_signal.gd")
const HarborBreakwater=preload("res://scripts/harbor_breakwater.gd")
const CombatCamera=preload("res://scripts/combat_camera.gd")
const CinderfordMarket=preload("res://scripts/cinderford_market.gd")
const ReedTollhouse=preload("res://scripts/reed_tollhouse.gd")
const RiverBank=preload("res://scripts/river_bank.gd")
const AbbeyMosaic=preload("res://scripts/abbey_mosaic.gd")
const KingsroadHoist=preload("res://scripts/kingsroad_hoist.gd")
const AqueductWheel=preload("res://scripts/aqueduct_waterwheel.gd")
const ReddeepCart=preload("res://scripts/reddeep_slag_cart.gd")
func _initialize():call_deferred("run")
func run():
 await verify_gate()
 await verify_towers()
 await verify_fountain()
 await verify_harbor_boats()
 await verify_harbor_quay()
 await verify_reddeep_furnaces()
 await verify_reddeep_cart()
 await verify_aqueduct_gallery()
 await verify_abbey_arcade()
 await verify_abbey_belfry()
 await verify_abbey_mosaic()
 await verify_ruined_columns()
 await verify_village_groves()
 await verify_market_stall()
 await verify_reed_tollhouse()
 await verify_trail_lanterns()
 await verify_greywood_shelter()
 await verify_kingsroad_canal()
 await verify_cart()
 await verify_barrels()
 var colors=[]
 for variant in range(3):
  var roof=Roof.roof(variant);assert(roof==Roof.roof(variant),"Repeated houses share their immutable roof mesh")
  var arrays=roof.surface_get_arrays(0);var points=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL]
  assert(points.size()/3<600,"Tile courses stay within a small fixed triangle budget")
  assert(roof.get_aabb().size.x>1.6 and roof.get_aabb().size.z>1.25,"Both eaves overhang the existing wall footprint")
  assert(roof.get_aabb().end.y>1.7 and roof.get_aabb().end.y<1.82,"The gable peak is covered by a restrained raised ridge")
  for i in range(0,points.size(),3):
   var cross=(points[i+1]-points[i]).cross(points[i+2]-points[i])
   assert(cross.length()>.000001 and cross.normalized().dot(normals[i])<-.999,"All roof and tile faces have valid clockwise winding and matching normals")
  for z in [-.63,-.1,.1,.63]:
   for step in range(-8,9):
    var x=step*.1;var underside=INF
    for i in range(0,points.size(),3):
     var hit=Geometry3D.ray_intersects_triangle(Vector3(x,0,z),Vector3.UP,points[i],points[i+1],points[i+2])
     if hit!=null:underside=minf(underside,hit.y)
    assert(absf(underside-(1.7-absf(x)*.625))<.0001,"Actual roof underside meets the existing gable profile without a hole or protrusion")
  var palette=arrays[Mesh.ARRAY_COLOR]
  assert(not palette[0] in colors,"House roof palettes are distinct")
  colors.append(palette[0])
  var varied=false
  for color in palette:
   if not color.is_equal_approx(palette[0]):varied=true
  assert(varied,"Tile courses retain subtle individual coloration")
 assert(Roof.material().vertex_color_use_as_albedo and Roof.material().vertex_color_is_srgb,"Roof tile colors reach the shared material")
 var scenery=Scenery.new();scenery.batching_enabled=false;var game=Rules.new();var state=game.rng.state;var cases=0
 verify_building_atlas(scenery)
 for chapter in range(12):
  game.chapter=chapter
  for item in game.info().landmarks:
   if item.kind not in ["house","warehouse"]:continue
   var p=Vector3(item.position[0],0,item.position[1]);var expected=Roof.variant_at(p)
   var world=Node3D.new();root.add_child(world);scenery.landmark(world,p,item.kind)
   var house=world.get_node("House");assert(house.get_meta("roof_variant")==expected)
   assert(house.get_node("TiledRoof").mesh==Roof.roof(expected),"Map building uses its stable position-based palette")
   var finish=Scenery.BuildingFinish.OCHRE_PLASTER if item.kind=="warehouse" else Scenery.BuildingFinish.LIME_PLASTER
   var plaster=scenery.building_material(finish)
   assert(house.get_node("PlasterWall").material_override==plaster)
   var gables=house.find_children("PlasterGable*","MeshInstance3D",true,false)
   assert(gables.size()==2 and gables.all(func(node):return node.material_override==plaster),"Both gables use the same finish as the house walls")
   var oak=scenery.building_material(Scenery.BuildingFinish.OAK)
   assert(house.get_children().filter(func(node):return node is MeshInstance3D and node.material_override==oak).size()>=16)
   var context=scenery.combat_context(game,{"x":int(p.x)-1,"y":int(p.z)},{"x":int(p.x),"y":int(p.z)})
   assert(context.landmarks[0].kind==item.kind and context.landmarks[0].roof_variant==expected,"Nearest building keeps its roof identity when remapped into the arena")
   var arena=Node3D.new();root.add_child(arena);scenery.battle_landscape(arena,Vector3(35,0,0),context)
   var landmarks=arena.get_children().filter(func(node):return str(node.name).begins_with("ArenaLandmark"))
   assert(landmarks[0].get_node("House").get_meta("roof_variant")==expected,"Actual combat backdrop receives the preserved palette")
   assert(landmarks[0].get_node("House/PlasterWall").material_override==plaster,"The map and arena share the painted building material")
   world.queue_free();arena.queue_free();await process_frame;cases+=1
 assert(cases>0 and game.rng.state==state,"Architecture never consumes gameplay RNG")
 await verify_cloth()
 print("PASS: arched castle gate/portcullis, tiered fountain basins/jets, six shared fortified towers, battlement/deck rays, three cached roofs, 204 gable intersections, ",cases," house identities, 16 pinned map-cloth placements, bounded motion parameters and cleanup")
 quit()

func verify_ruined_columns():
 var ruin=preload("res://scripts/ruined_columns.gd")
 var shape=ruin.mesh()
 assert(shape==ruin.mesh())
 var arrays=shape.surface_get_arrays(0)
 var vertices=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL]
 var stride=ruin.OUTLINE.size()*12
 assert(vertices.size()==ruin.COURSES.size()*stride)
 var bounds=shape.get_aabb()
 assert(is_zero_approx(bounds.position.y) and bounds.end.y>1 and bounds.end.y<1.05)
 assert(bounds.position.x>=-.24 and bounds.end.x<1.43 and bounds.size.z<=.521)
 for start in range(0,vertices.size(),stride):
  var edges={};var volume=0.0
  for i in range(start,start+stride,3):
   var a=vertices[i];var b=vertices[i+1];var c=vertices[i+2]
   var normal=(b-a).cross(c-a)
   assert(normal.length_squared()>.00000001 and normal.normalized().dot(normals[i])<-.998)
   volume-=a.dot(b.cross(c))/6.0
   for edge in [[a,b],[b,c],[c,a]]:
    var first=str(edge[0]);var second=str(edge[1])
    var key=first+"/"+second if first<second else second+"/"+first
    edges[key]=edges.get(key,0)+1
  assert(volume>0 and edges.values().all(func(count):return count==2),"Every fractured course is a closed, outward-wound stone")
 var game=Rules.new();var rng=game.rng.state
 var scenery=Scenery.new();var chapters=0
 for chapter in range(12):
  game.chapter=chapter
  var sites=game.info().landmarks.filter(func(item):return item.kind=="ruin")
  if sites.is_empty():continue
  var snapshot=game.save_data("camp")
  var site=sites[0].position
  var map=Node3D.new();root.add_child(map);scenery.landscape(map,game)
  var mapped=map.get_node("RuinMasonry")
  assert(mapped.mesh==shape and mapped.position==Vector3(site[0],0,site[1]))
  var x=clampi(int(site[0]),0,game.board_size().x-2);var y=int(site[1])
  var context=scenery.combat_context(game,{"x":x,"y":y},{"x":x+1,"y":y})
  var stage=Node3D.new();root.add_child(stage);scenery.battle_landscape(stage,Vector3(35,0,0),context)
  var framed=stage.find_child("RuinMasonry",true,false)
  assert(framed!=null and framed.mesh==shape and framed.material_override==mapped.material_override)
  assert(framed.global_position.z<-6 and is_zero_approx(framed.global_position.y))
  assert(game.save_data("camp")==snapshot)
  map.queue_free();stage.queue_free();await process_frame;chapters+=1
 assert(chapters==3 and game.rng.state==rng)
 print("PASS: fourteen closed ruined masonry courses and one shared mesh at all six map and arena placements")

func verify_abbey_arcade():
 var scenery=Scenery.new();scenery.batching_enabled=false
 var game=Rules.new();game.chapter=3
 var snapshot=game.save_data("camp")
 var map=Node3D.new();root.add_child(map);scenery.landscape(map,game)
 var mapped_trees=map.find_children("AbbeyGardenTree*","Node3D",false,false)
 assert(mapped_trees.size()==8 and mapped_trees.all(func(tree):return tree.position.z<-2.5 and tree.position.y<0),
  "The Abbey grove stays beyond the playable courtyard")
 var context=scenery.combat_context(game,{"x":6,"y":8},{"x":6,"y":7})
 assert(context.environment=="abbey" and not context.landmarks.is_empty())
 var viewport=SubViewport.new();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var camera=Camera3D.new();viewport.add_child(camera);camera.current=true
 for terrain in ["p","="]:
  var center=Vector3(35,0 if terrain=="p" else .7,0)
  context.terrain=terrain
  var stage=Node3D.new();root.add_child(stage);scenery.battle_landscape(stage,center,context)
  var arcade=stage.get_node("AbbeyArcade")
  var garden=stage.get_node("AbbeyGardenLawn")
  var staged_trees=stage.find_children("AbbeyGardenTree*","Node3D",false,false)
  assert(staged_trees.size()==mapped_trees.size() and garden.position.y<center.y)
  var lawn=garden.transform*garden.mesh.get_aabb()
  assert(lawn.end.z<arcade.position.z-1.8 and lawn.position.z<-90.0,"The grass starts beyond the arcade and extends under the far hills")
  for index in staged_trees.size():
   var tree=staged_trees[index]
   assert(tree.position.y==garden.position.y and tree.position.z<arcade.position.z-4.5)
   assert(tree.get_node("ConiferCrown").mesh==mapped_trees[index].get_node("ConiferCrown").mesh,
    "The same garden tree silhouettes frame the map and the arena")
  var ridges=stage.find_children("ArenaRidge*","MeshInstance3D",false,false)
  assert(ridges.size()==3 and ridges.all(func(ridge):return ridge.mesh.get_aabb().end.z<=-26.0),
   "All three distant hills sit beyond the planted garden")
  var walk=arcade.get_node("ArcadeWalk")
  var step=arcade.get_node("ArcadeStep")
  var coping=arcade.get_node("ArcadeCoping")
  var rim=arcade.get_node("ArcadeCornice")
  var bounds=func(mesh):return mesh.transform*mesh.mesh.get_aabb()
  assert(is_equal_approx(bounds.call(walk).position.y,-.06) and bounds.call(walk).intersects(bounds.call(step)))
  assert(bounds.call(coping).intersects(bounds.call(rim)) and arcade.position.z+bounds.call(step).end.z<-5.5)
  var bases=arcade.find_children("ArcadeFooting*","MeshInstance3D",false,false)
  var shafts=arcade.find_children("ArcadeShaft*","MeshInstance3D",false,false)
  var capitals=arcade.find_children("ArcadeCapital*","MeshInstance3D",false,false)
  var abaci=arcade.find_children("ArcadeAbacus*","MeshInstance3D",false,false)
  var spans=arcade.find_children("MasonryArch*","MeshInstance3D",false,false)
  assert([bases.size(),shafts.size(),capitals.size(),abaci.size(),spans.size()]==[7,7,7,7,6])
  for index in 7:
   var stack=[walk,bases[index],shafts[index],capitals[index],abaci[index]]
   for layer in range(stack.size()-1):
    assert(bounds.call(stack[layer]).intersects(bounds.call(stack[layer+1])),"Every column connects its walk, footing, shaft and capital")
  for index in spans.size():
   var span=spans[index]
   assert(span.mesh==spans[0].mesh and bounds.call(span).intersects(bounds.call(coping)))
   assert(bounds.call(span).intersects(bounds.call(abaci[index])) and bounds.call(span).intersects(bounds.call(abaci[index+1])))
  var tiles=spans[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  var crown_hit=false
  for i in range(0,tiles.size(),3):
   assert(Geometry3D.ray_intersects_triangle(Vector3(.08,.85,2),Vector3.FORWARD,tiles[i],tiles[i+1],tiles[i+2])==null)
   if Geometry3D.ray_intersects_triangle(Vector3(.08,1.82,2),Vector3.FORWARD,tiles[i],tiles[i+1],tiles[i+2])!=null:crown_hit=true
  assert(crown_hit,"The arch keeps an open interior beneath real crown masonry")
  for landmark in stage.find_children("ArenaLandmark*","Node3D",false,false):
   assert(landmark.position.z<=-13.0 and landmark.position.y==center.y,"The mapped abbey ruins sit behind the arcade")
  var frame=CombatCamera.frame_pair(center+Vector3.LEFT*1.6,center+Vector3.RIGHT*1.6,"wide",false)
  camera.position=frame.anchor;camera.fov=frame.lens;camera.look_at(frame.focus)
  for dimensions in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
   viewport.size=dimensions;await process_frame
   var arch=spans[1].to_global(Vector3(.4,1.85,0))
   assert(Rect2(Vector2.ZERO,Vector2(dimensions)).grow(-10).has_point(camera.unproject_position(arch)),"A masonry crown fits the wide shot")
  stage.queue_free();await process_frame
 map.queue_free();viewport.queue_free();await process_frame
 assert(game.save_data("camp")==snapshot)
 print("PASS: seven seated abbey piers, six open arches in shared stone, planted walk and six camera projections")
 print("PASS: eight shared Abbey trees, grass beyond the arcade and three continuous hills in both floor setups")

func verify_abbey_mosaic():
 var scenery=Scenery.new();scenery.batching_enabled=false
 var game=Rules.new();game.chapter=3
 var saved=game.save_data("camp")
 var field=Node3D.new();root.add_child(field);scenery.landscape(field,game)
 var inlay=field.get_node("AbbeyFloorMosaic")
 var shape=AbbeyMosaic.shape()
 assert(inlay.mesh==shape and inlay.position==AbbeyMosaic.MAP_SITE)
 var arrays=shape.surface_get_arrays(0)
 var points=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL]
 assert(points.size()==426 and inlay.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
 for index in range(0,points.size(),3):
  var cross=(points[index+1]-points[index]).cross(points[index+2]-points[index])
  assert(cross.y<-.00001 and normals[index].dot(Vector3.UP)>.9999)
  for offset in 3:
   var world=inlay.to_global(points[index+offset])
   assert(is_equal_approx(world.y,.004) and game.terrain(Vector2i(roundi(world.x),roundi(world.z)))=="p")
 var missing=AbbeyMosaic.point(.81,TAU*6.5/32)+Vector3.UP
 var intact=AbbeyMosaic.point(.81,TAU*5.5/32)+Vector3.UP
 assert(barrel_hit(shape,missing,Vector3.DOWN)==null and barrel_hit(shape,intact,Vector3.DOWN)!=null)
 var viewport=SubViewport.new();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var camera=Camera3D.new();viewport.add_child(camera);camera.current=true
 var anchor=Vector3(6.5,0,4.5)
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=16
 camera.position=anchor+Vector3(2.5,22,11.5);camera.look_at(anchor);camera.h_offset=2
 var sizes=[Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]
 for size in sizes:
  viewport.size=size;await process_frame
  assert(Rect2(Vector2.ZERO,Vector2(size)).grow(-12).has_point(camera.unproject_position(inlay.global_position)))
 camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.h_offset=0
 var origin=Vector3(35,.6,0)
 for step in [Vector2i.RIGHT,Vector2i.DOWN]:
  var target=Vector2i(5,4)+step
  var context=scenery.combat_context(game,{"x":5,"y":4},{"x":target.x,"y":target.y})
  var stage=Node3D.new();root.add_child(stage);scenery.battle_landscape(stage,origin,context)
  var arena=stage.get_node("AbbeyFloorMosaic")
  assert(arena.mesh==shape and arena.material_override==inlay.material_override)
  assert(is_equal_approx(arena.rotation.y,0.0 if step==Vector2i.RIGHT else PI/2))
  var box=arena.global_transform*shape.get_aabb()
  assert(box.end.z<0 and box.position.z> -3 and is_equal_approx(box.position.y,origin.y+.004),
   "The inlay is held flush within the arena’s stone lane, behind the fighter footing")
  var frame=CombatCamera.frame_pair(origin+Vector3.LEFT*1.6,origin+Vector3.RIGHT*1.6,"wide",false,step==Vector2i.DOWN)
  camera.position=frame.anchor;camera.fov=frame.lens;camera.look_at(frame.focus)
  for size in sizes:
   viewport.size=size;await process_frame
   var inside=Rect2(Vector2(12,12),Vector2(size)-Vector2(24,164))
   assert(inside.has_point(camera.unproject_position(arena.global_position)))
  scenery.batcher.combine(stage)
  var batches=stage.get_children().filter(func(node):return node is MeshInstance3D and node.material_override==inlay.material_override)
  assert(batches.size()==1 and batches[0].mesh.surface_get_array_len(0)==points.size())
  assert(batches[0].mesh.get_aabb().is_equal_approx(box),"The inlay survives static batching with its exact seated position")
  stage.free()
 var distant=scenery.combat_context(game,{"x":1,"y":4},{"x":2,"y":4})
 assert(not distant.has("mosaic_yaw"))
 var deck=scenery.combat_context(game,{"x":5,"y":4},{"x":6,"y":4});deck.terrain="="
 var alternate=Node3D.new();root.add_child(alternate);scenery.battle_landscape(alternate,origin,deck)
 assert(not alternate.has_node("AbbeyFloorMosaic") and alternate.has_node("ArenaRailing"))
 alternate.free()
 viewport.free();field.free()
 assert(game.save_data("camp")==saved)
 print("PASS: worn 142-triangle Hallow Abbey floor mosaic, shared geometry with oriented arena placement and nine clear projections")

func verify_abbey_belfry():
 var scenery=Scenery.new();scenery.batching_enabled=false
 var game=Rules.new();game.chapter=3
 var saved=game.save_data("camp");var rng=game.rng.state
 var field=Node3D.new();root.add_child(field);scenery.landscape(field,game)
 var belfry=field.get_node("EmptyBelfry")
 verify_belfry_frame(belfry)
 var foot=belfry.get_node("BelfryFooting")
 var footprint=foot.global_transform*foot.mesh.get_aabb()
 assert(footprint.end.z<-.5 and footprint.position.y<-.15 and footprint.end.y>-.15)
 var viewport=SubViewport.new();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var camera=Camera3D.new();viewport.add_child(camera);camera.current=true
 var center=Vector3((game.board_size().x-1)*.5,0,(game.board_size().y-1)*.5)
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=maxf(16,game.board_size().x+2)
 camera.position=center+Vector3(2.5,22,11.5);camera.look_at(center);camera.h_offset=2
 var sizes=[Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]
 for size in sizes:
  viewport.size=size;await process_frame
  assert(Rect2(Vector2.ZERO,Vector2(size)).grow(-12).has_point(camera.unproject_position(belfry.to_global(Vector3(0,2.06,.62)))))
 camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.h_offset=0
 for pair in [[Vector2i(3,7),Vector2i(4,7)],[Vector2i(10,3),Vector2i(11,3)],[Vector2i(11,3),Vector2i(10,3)]]:
  var context=scenery.combat_context(game,{"x":pair[0].x,"y":pair[0].y},{"x":pair[1].x,"y":pair[1].y})
  var has_map_belfry=context.landmarks.any(func(item):return item.kind=="belfry")
  assert(has_map_belfry==(pair[0].x>=10))
  var mounted=pair[0].x==11
  center=Vector3(35,0,0)
  var stage=Node3D.new();root.add_child(stage);scenery.battle_landscape(stage,center,context)
  var arena=stage.get_node("EmptyBelfry")
  assert(stage.find_children("EmptyBelfry","Node3D",false,false).size()==1)
  assert(is_equal_approx(arena.position.x,center.x+(2.7 if pair[0].x==10 else -5.7)))
  verify_belfry_frame(arena)
  assert(arena.get_node("BelfryArch").mesh==belfry.get_node("BelfryArch").mesh)
  var step=stage.get_node("AbbeyArcade/ArcadeStep")
  var bounds=step.global_transform*step.mesh.get_aabb()
  assert(arena.global_position.z-arena.scale.z*.74>bounds.end.z,"The belfry sits in front of the abbey walk")
  var frame=CombatCamera.frame_pair(center+Vector3.LEFT*1.6,center+Vector3.RIGHT*1.6,"wide",false,mounted)
  camera.position=frame.anchor;camera.fov=frame.lens;camera.look_at(frame.focus)
  for size in sizes:
   viewport.size=size;await process_frame
   var screen=camera.unproject_position(arena.to_global(Vector3(0,2.06,.62)))
   assert(Rect2(Vector2.ZERO,Vector2(size)).grow(-12).has_point(screen) and screen.y<size.y*.61,"The empty belfry window frames clear of the bottom HUD")
  stage.free()
 viewport.free();field.free()
 assert(game.save_data("camp")==saved and game.rng.state==rng)
 print("PASS: Hallow Abbey's empty belfry frames the missing bell in twelve tactical and arena projections")

func verify_belfry_frame(tower: Node3D):
 var arches=tower.find_children("BelfryArch*","MeshInstance3D",false,false)
 var piers=tower.find_children("BelfryPier*","MeshInstance3D",false,false)
 var roof=tower.find_children("BelfryRoof*","MeshInstance3D",false,false)
 assert([arches.size(),piers.size(),roof.size()]==[2,4,2])
 var bounds=func(node):return node.transform*node.mesh.get_aabb()
 var foundation=bounds.call(tower.get_node("BelfryFooting"))
 var trunk=bounds.call(tower.get_node("BelfryTrunk"))
 var sill=bounds.call(tower.get_node("BelfrySill"))
 var cornice=bounds.call(tower.get_node("BelfryCornice"))
 assert(foundation.intersects(trunk) and trunk.intersects(sill))
 for pier in piers:
  assert(bounds.call(pier).intersects(sill) and arches.any(func(arch):return bounds.call(arch).intersects(bounds.call(pier))))
 for arch in arches:assert(bounds.call(arch).intersects(cornice))
 assert(roof.all(func(slope):return bounds.call(slope).intersects(cornice)) and bounds.call(roof[0]).intersects(bounds.call(roof[1])))
 var yoke=bounds.call(tower.get_node("BelfryYoke"))
 assert(yoke.has_point(Vector3(0,2.43,0)))
 for part in tower.get_children():
  assert(bounds.call(part).intersects_segment(Vector3(0,2.08,-2),Vector3(0,2.08,2))==null,"No stone or timber fills the bay where the bell hung")

func verify_village_groves():
 var scenery=Scenery.new();scenery.batching_enabled=false
 var game=Rules.new();var rng=game.rng.state
 var center=Vector3(35,0,0)
 var near={"x":4,"y":0};var far={"x":4,"y":1}
 var normal=scenery.combat_context(game,near,far)
 var mirrored=scenery.combat_context(game,near,far,-1.0)
 assert(normal.environment=="village" and normal.landmarks.size()==2)
 assert(scenery.village_mill_site([Vector2(-9,-13)])==Scenery.MILL_ALTERNATE_SITE)
 assert(scenery.village_mill_site([Vector2(-9,-13),Vector2(-2,-15)])==Scenery.MILL_DISTANT_SITE)
 var map=Node3D.new();root.add_child(map);scenery.landscape(map,game)
 var map_mill=map.get_node("CinderfordMill")
 assert(map_mill.position==Scenery.MILL_MAP_SITE and map_mill.position.z<-.5)
 verify_mill(map_mill,-.15)
 map.queue_free();await process_frame
 var viewport=SubViewport.new();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var camera=Camera3D.new();viewport.add_child(camera);camera.current=true
 for context in [normal,mirrored,{"environment":"village","terrain":"p"}]:
  var stage=Node3D.new();root.add_child(stage);scenery.battle_landscape(stage,center,context)
  var mill=stage.get_node("CinderfordMill")
  assert(mill.position==center+Scenery.MILL_ARENA_SITE)
  var rotor=verify_mill(mill,center.y)
  var sails=rotor.find_children("MillSail","MeshInstance3D",true,false)
  var trees=stage.find_children("ArenaTree*","Node3D",false,false)
  var houses=stage.find_children("House*","Node3D",true,false).filter(func(node):return node.has_node("PlasterWall"))
  var landmarks=context.get("landmarks",[])
  var house_count=3 if landmarks.is_empty() else landmarks.filter(func(item):return item.kind=="house").size()
  assert(trees.size()>=9 and trees.size()<=15 and houses.size()==house_count,
   "Expected %d houses, got %d alongside %d trees"%[house_count,houses.size(),trees.size()])
  var silhouettes=[]
  for tree in trees:
   var offset=tree.position-center
   assert(is_zero_approx(offset.y) and (offset.z<-20 or absf(offset.x)>11),"The near groves leave a central view down the lane")
   for house in houses:
    var distance=tree.global_position-house.global_position
    assert(absf(distance.x)>=4.7 or distance.z<=-4.5,"A tree stays clear of every house frontage")
   for mesh in tree.find_children("*","MeshInstance3D",true,false):
    var bounds=mesh.global_transform*mesh.mesh.get_aabb()
    if bounds.end.z>center.z-20:silhouettes.append(bounds)
  var mill_obstacles=silhouettes.duplicate()
  for house in houses:
   for piece in house.find_children("*","MeshInstance3D",true,false):
    mill_obstacles.append(piece.global_transform*piece.mesh.get_aabb())
  for mounted in [false,true]:
   var frame=CombatCamera.frame_pair(center+Vector3.LEFT*1.6,center+Vector3.RIGHT*1.6,"wide",false,mounted)
   camera.position=frame.anchor;camera.fov=frame.lens;camera.look_at(frame.focus)
   for dimensions in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
    viewport.size=dimensions;await process_frame
    var visible=houses.any(func(house):
     var facade=house.to_global(Vector3(0,.85,.67))
     var screen_point=camera.unproject_position(facade)
     var framed=Rect2(Vector2.ZERO,Vector2(dimensions)).grow(-18).has_point(screen_point)
     return framed and not silhouettes.any(func(bounds):return bounds.intersects_segment(camera.global_position,facade)!=null))
    assert(visible,"One visible house frontage remains clear of every near trunk and canopy")
    var mill_window=Rect2(Vector2(20,20),Vector2(dimensions)-Vector2(40,174))
    for phase in [0.0,PI*.25]:
     rotor.rotation.z=phase
     assert(sails.any(func(sail):
      var blade=sail.to_global(Vector3(0,.46,.015))
      var clear=not mill_obstacles.any(func(bounds):return bounds.intersects_segment(camera.global_position,blade)!=null)
      return clear and not camera.is_position_behind(blade) and mill_window.has_point(camera.unproject_position(blade))
     ),"At least one sail clears the settlement in a wide shot")
  stage.queue_free();await process_frame
 viewport.queue_free();await process_frame
 scenery.batching_enabled=true
 var batched=Node3D.new();root.add_child(batched);scenery.battle_landscape(batched,center,normal)
 var rotating=batched.get_node("CinderfordMill/MillRotor")
 assert(rotating.get_script()!=null)
 assert(rotating.get_children().any(func(part):return part is MeshInstance3D and part.get_meta("static_batch",false)))
 var remaining=weakref(rotating);batched.queue_free();await process_frame
 assert(remaining.get_ref()==null)
 assert(game.rng.state==rng)
 print("PASS: two village groves and distant orchard, clear mapped and fallback house frontage in 18 wide-shot projections")
 print("PASS: grounded Cinderford mill with four braced moving sails, hidden clock suspension, local batching and 36 wide-shot sail projections")

func verify_mill(mill: Node3D,ground_y: float) -> Node3D:
 var footing=mill.get_node("MillFoundation")
 var ground=footing.global_transform*footing.mesh.get_aabb()
 assert(ground.position.y<ground_y and ground.end.y>ground_y)
 var fixed=[]
 for name in ["MillStoneTower","MillEave","MillRoof"]:
  var node=mill.get_node(name)
  fixed.append(node.transform*node.mesh.get_aabb())
 assert(fixed[0].intersects(fixed[1]) and fixed[1].intersects(fixed[2]))
 var axle=mill.get_node("MillAxle")
 var shaft=axle.transform*axle.mesh.get_aabb()
 assert(shaft.intersects(fixed[0]))
 var rotor=mill.get_node("MillRotor")
 rotor.set_process(false)
 var hub=rotor.get_node("MillHub")
 var joint=(rotor.transform*hub.transform)*hub.mesh.get_aabb()
 assert(joint.intersects(shaft))
 var arms=rotor.find_children("MillArm*","Node3D",false,false)
 assert(arms.size()==4)
 for index in arms.size():
  var arm=arms[index]
  assert(is_zero_approx(wrapf(arm.rotation.z-index*PI*.5,-PI,PI)))
  var spar=arm.get_node("MillSpar")
  var sail=arm.get_node("MillSail")
  var spar_bounds=spar.transform*spar.mesh.get_aabb()
  var sail_bounds=sail.transform*sail.mesh.get_aabb()
  assert(sail_bounds.intersects(spar_bounds))
  var ties=arm.find_children("MillSailTie*","MeshInstance3D",false,false)
  assert(ties.size()==2)
  for tie in ties:
   var bound=tie.transform*tie.mesh.get_aabb()
   assert(bound.intersects(sail_bounds) and bound.intersects(spar_bounds))
  for piece in arm.get_children():
   var blade=(rotor.transform*arm.transform*piece.transform)*piece.mesh.get_aabb()
   assert(fixed.all(func(bounds):return bounds.end.z<blade.position.z),"The rotor clears the tower and roof through its whole turn")
 rotor.rotation.z=TAU-.15
 rotor._process(1.0);assert(is_equal_approx(rotor.rotation.z,.13))
 mill.hide();rotor._process(5.0);assert(is_equal_approx(rotor.rotation.z,.13))
 mill.show();rotor.rotation.z=0
 return rotor

func verify_market_stall():
 var scenery=Scenery.new();scenery.batching_enabled=false
 var game=Rules.new();var saved=game.save_data("camp")
 var field=Node3D.new();root.add_child(field);scenery.landscape(field,game)
 var market=field.get_node("CinderfordMarketStall")
 var awning=market.get_node("StripedAwning")
 var mesh: ArrayMesh=awning.mesh
 var arrays=mesh.surface_get_arrays(0)
 var vertices=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL];var colors=arrays[Mesh.ARRAY_COLOR]
 var stripe_length=CinderfordMarket.ROWS.size()*6
 assert(vertices.size()==9*stripe_length and awning.material_override==CinderfordMarket.paint())
 for i in range(0,vertices.size(),3):
  var face=(vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i])
  assert(face.length()>.001 and face.normalized().dot(normals[i])<-.99)
 for band in range(9):
  assert((colors[band*stripe_length].g>.59)==(band%2==1))
  var x=lerpf(-.86,.86,(float(band)+.5)/9.0)
  var hit=barrel_hit(mesh,Vector3(x,2,.15),Vector3.DOWN)
  assert(hit!=null and is_equal_approx(hit.y,CinderfordMarket.roof_height(.15)))
 assert(CinderfordMarket.roof_height(0)<lerpf(1.68,1.38,.5)-.06,"The canvas drapes between its rails")
 var rails=market.find_children("CanopyRail*","MeshInstance3D",false,false)
 var supports=market.find_children("CounterRail*","MeshInstance3D",false,false)
 var posts=market.find_children("AwningPost*","MeshInstance3D",false,false)
 var boards=market.find_children("CounterBoard*","MeshInstance3D",false,false)
 var bounds=func(node):return node.transform*node.mesh.get_aabb()
 assert([rails.size(),supports.size(),posts.size(),boards.size()]==[2,2,4,4])
 for post in posts:
  var box=bounds.call(post)
  assert(is_zero_approx(box.position.y) and rails.any(func(rail):return box.intersects(bounds.call(rail))))
  var point=post.global_position
  var tile=Vector2(roundf(point.x),roundf(point.z))
  assert(Vector2(point.x,point.z).distance_to(tile)>.18 and game.terrain(Vector2i(tile)) in [".","p"])
 for rail in rails:
  var nearest=INF
  for vertex in rail.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
   var point=rail.transform*vertex
   var cloth=barrel_hit(mesh,Vector3(point.x,2,point.z),Vector3.DOWN)
   assert(cloth!=null and cloth.y>=point.y-.0001,"The rail stays under the canopy")
   nearest=minf(nearest,cloth.y-point.y)
  assert(nearest<.015,"The rails follow the pitch closely enough to seat the canvas")
 for rail in supports:
  var box=bounds.call(rail)
  assert(posts.filter(func(post):return box.intersects(bounds.call(post))).size()==2)
  assert(boards.all(func(board):return box.intersects(bounds.call(board))))
 var pottery=market.get_node("Earthenware")
 assert(pottery.mesh==CinderfordMarket.pottery_mesh() and pottery.material_override==CinderfordMarket.pottery_paint())
 assert(pottery.mesh.get_surface_count()==1 and pottery.material_override.vertex_color_use_as_albedo)
 var pottery_arrays=pottery.mesh.surface_get_arrays(0)
 var pottery_points=pottery_arrays[Mesh.ARRAY_VERTEX];var pottery_normals=pottery_arrays[Mesh.ARRAY_NORMAL]
 for index in range(0,pottery_points.size(),3):
  var face=(pottery_points[index+1]-pottery_points[index]).cross(pottery_points[index+2]-pottery_points[index])
  assert(face.length_squared()>1e-12 and face.normalized().dot(pottery_normals[index])<-.5)
 var pottery_bounds=bounds.call(pottery)
 assert(is_equal_approx(pottery_bounds.position.y,CinderfordMarket.COUNTER_TOP) and pottery_bounds.end.y<1.0)
 assert(pottery_bounds.position.x>-.766 and pottery_bounds.end.x<.766 and pottery_bounds.position.z>-.32 and pottery_bounds.end.z<.33)
 for ware in CinderfordMarket.WARES:
  var sample=Vector3(ware.spot.x,CinderfordMarket.COUNTER_TOP,ware.spot.y)
  assert(boards.any(func(board):return bounds.call(board).grow(.0001).has_point(sample)),"Each piece of pottery sits on a counter board")
  var mouth_hit=barrel_hit(pottery.mesh,sample+Vector3.UP*.6,Vector3.DOWN)
  var depth=.2 if ware.handle!=0 else .039
  assert(mouth_hit!=null and absf(mouth_hit.y-sample.y-depth*ware.scale)<.001,"The visible mouth opens to a recessed interior")
 var viewport=SubViewport.new();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var camera=Camera3D.new();viewport.add_child(camera);camera.current=true
 var focus=Vector3((game.board_size().x-1)*.5,0,(game.board_size().y-1)*.5)
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=maxf(16,game.board_size().x+2)
 camera.position=focus+Vector3(2.5,22,11.5);camera.look_at(focus);camera.h_offset=2
 var sizes=[Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]
 for size in sizes:
  viewport.size=size;await process_frame
  assert(Rect2(Vector2.ZERO,Vector2(size)).grow(-12).has_point(camera.unproject_position(market.to_global(Vector3(0,1.44,.38)))))
 camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.h_offset=0
 var center=Vector3(35,0,0)
 for mirror in [1.0,-1.0]:
  var stage=Node3D.new();root.add_child(stage)
  var context=scenery.combat_context(game,{"x":2,"y":3},{"x":3,"y":3},mirror)
  scenery.battle_landscape(stage,center,context)
  var close_market=stage.get_node("CinderfordMarketStall")
  var close_awning=close_market.get_node("StripedAwning")
  var close_wares=close_market.get_node("Earthenware")
  var canopy=close_awning.global_transform*mesh.get_aabb()
  assert(close_awning.mesh==mesh and close_awning.material_override==awning.material_override)
  assert(close_wares.mesh==pottery.mesh and close_wares.material_override==pottery.material_override,
   "The same painted pottery is visible on the tactical and arena counter")
  assert(canopy.end.x<center.x+3.0 and canopy.end.z<center.z-3.2)
  assert(canopy.position.z>center.z-4.8,"The awning clears the foreground and mapped houses")
  var frame=CombatCamera.frame_pair(center+Vector3.LEFT*1.6,center+Vector3.RIGHT*1.6,"wide",false,mirror<0)
  camera.position=frame.anchor;camera.fov=frame.lens;camera.look_at(frame.focus)
  for size in sizes:
   viewport.size=size;await process_frame
   var open=Rect2(Vector2(12,12),Vector2(size)-Vector2(24,164))
   var striped_edge=close_market.to_global(Vector3(0,1.31,.547))
   assert(not camera.is_position_behind(striped_edge) and open.has_point(camera.unproject_position(striped_edge)))
   for ware in CinderfordMarket.WARES:
    var item=close_market.to_global(Vector3(ware.spot.x,.75,ware.spot.y))
    assert(not camera.is_position_behind(item) and open.has_point(camera.unproject_position(item)))
  stage.free()
 viewport.free();field.free()
 assert(game.save_data("camp")==saved)
 print("PASS: nine Cinderford awning stripes, grounded supports and connected counter, shared map/arena mesh and nine camera views")
 print("PASS: four pieces of Cinderford earthenware share one mesh, stay on the counter and retain open mouths across both views")

func verify_reed_tollhouse():
 var scenery=Scenery.new();scenery.batching_enabled=false
 var game=Rules.new();game.chapter=1
 var saved=game.save_data("camp")
 var field=Node3D.new();root.add_child(field);scenery.landscape(field,game)
 var house=field.get_node("ReedTollhouse")
 assert(house.position==Vector3(12,0,2.5) and game.objective_position()==Vector2i(12,4))
 var arch=house.get_node("TollPassage")
 var roof=house.get_node("TollSlateRoof")
 var gables=house.get_node("OfficeGables")
 assert(gables.mesh==ReedTollhouse.gable_mesh())
 for x in [-.96,-.48,0,.48,.96]:
  var local_x=x/roof.scale.x
  var underside=barrel_hit(roof.mesh,Vector3(local_x,0,0),Vector3.UP)
  assert(underside!=null)
  var pitch=ReedTollhouse.RIDGE-absf(x)*Roof.SLOPE/roof.scale.x
  assert(is_equal_approx((roof.transform*underside).y,pitch),"The timber gables fit the actual slate roof")
 var bounds=func(node):return node.global_transform*node.mesh.get_aabb()
 for foothold in house.find_children("TollFooting*","MeshInstance3D",false,false):
  var box=bounds.call(foothold)
  assert(box.position.y<0 and box.end.y>0)
  assert(not box.has_point(Vector3(12,0,2.5)) and box.end.z<3.08)
 for eye in [Vector3(0,.65,2),Vector3(.32,1.00,2),Vector3(-.32,1.00,2)]:
  for child in house.get_children():
   var inverse=child.transform.affine_inverse()
   var local_eye=inverse*eye
   var direction=inverse.basis*Vector3.FORWARD
   var faces=child.mesh.get_faces()
   for i in range(0,faces.size(),3):
    assert(Geometry3D.ray_intersects_triangle(local_eye,direction,faces[i],faces[i+1],faces[i+2])==null,
     "The stone passage stays open through the building")
 var crown=Vector3(0,1.40,2)-arch.position
 assert(barrel_hit(arch.mesh,crown,Vector3.FORWARD)!=null,"The opening is topped by real arch masonry")
 var viewport=SubViewport.new();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var camera=Camera3D.new();viewport.add_child(camera);camera.current=true
 var focus=Vector3(6.5,0,4.5)
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=16
 camera.position=focus+Vector3(2.5,22,11.5);camera.look_at(focus);camera.h_offset=2
 var sizes=[Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]
 for size in sizes:
  viewport.size=size;await process_frame
  var sign_view=camera.unproject_position(house.get_node("TollSign").global_position)
  assert(Rect2(Vector2.ZERO,Vector2(size)).grow(-12).has_point(sign_view))
 camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.h_offset=0
 var center=Vector3(35,0,0)
 for sample in [[Vector2i(11,4),Vector2i(12,4),1.0,false],[Vector2i(12,5),Vector2i(12,4),-1.0,true],
  [Vector2i(7,2),Vector2i(6,2),1.0,false],[Vector2i(6,2),Vector2i(7,2),-1.0,true]]:
  var a=sample[0];var b=sample[1]
  var context=scenery.combat_context(game,{"x":a.x,"y":a.y},{"x":b.x,"y":b.y},sample[2])
  assert(context.has("tollhouse_x") and context.landmarks.size()==2)
  var arena=Node3D.new();root.add_child(arena);scenery.battle_landscape(arena,center,context)
  var backdrop=arena.get_node("ReedTollhouse")
  var props=[backdrop.get_node("TollSlateRoof"),backdrop.get_node("TollPassage"),backdrop.get_node("OfficeGables")]
  assert(props[0].mesh==roof.mesh and props[1].mesh==arch.mesh and props[2].mesh==gables.mesh)
  assert(bounds.call(props[0]).end.z<RiverBank.ARENA_FAR_START+.10 and is_zero_approx(backdrop.position.y))
  var occluders=[]
  for neighbor in arena.get_children():
   if not str(neighbor.name).begins_with("ArenaTree") and not str(neighbor.name).begins_with("ArenaLandmark"):continue
   for part in neighbor.find_children("*","MeshInstance3D",true,false):
    occluders.append(bounds.call(part))
  var frame=CombatCamera.frame_pair(center+Vector3.LEFT*1.6,center+Vector3.RIGHT*1.6,"wide",false,sample[3])
  camera.position=frame.anchor;camera.fov=frame.lens;camera.look_at(frame.focus)
  var sign_point=backdrop.get_node("TollSign").global_position
  assert(not occluders.any(func(box):return box.intersects_segment(camera.global_position,sign_point)!=null),
   "The mapped towers and far-bank trees leave a line to the tollhouse sign")
  for size in sizes:
   viewport.size=size;await process_frame
   var sign_view=camera.unproject_position(sign_point)
   var open=Rect2(Vector2(12,12),Vector2(size)-Vector2(24,164))
   assert(open.has_point(sign_view),"The tollhouse sign remains in the playable frame")
  arena.free()
 viewport.free();field.free()
 assert(game.save_data("camp")==saved)
 print("PASS: Reed Crossing's shared open stone passage and fitted slate roof in 15 tactical and arena projections")

func verify_trail_lanterns():
 var scenery=Scenery.new();scenery.batching_enabled=false
 var game=Rules.new();game.chapter=2
 var before=game.save_data("camp").duplicate(true)
 var world=Node3D.new();root.add_child(world);scenery.landscape(world,game)
 var lamps=world.find_children("TrailLantern*","Node3D",false,false)
 assert(lamps.size()==6 and world.find_children("*","Light3D",true,false).is_empty())
 var frame=lamps[0].get_node("LanternFrame")
 var paper=lamps[0].get_node("LanternPaper")
 var frame_shape: ArrayMesh=frame.mesh
 var bounds=frame_shape.get_aabb()
 assert(bounds.position.y<0 and bounds.end.y>1.40 and bounds.size.x<.8)
 var arrays=frame_shape.surface_get_arrays(0)
 var points=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL]
 assert(points.size()/3<300,"The full fixture stays within a fixed low triangle budget")
 for index in range(0,points.size(),3):
  var normal=(points[index+1]-points[index]).cross(points[index+2]-points[index]).normalized()
  assert(normal.dot(normals[index])<-.65,"Closed hardware retains its outward normal")
 assert(paper.material_override.emission_enabled and paper.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
 for lamp in lamps:
  var foot=lamp.to_global(Vector3(-.285,0,0))
  var tile=Vector2i(roundi(foot.x),roundi(foot.z))
  assert(not game.terrain(tile) in ["~","=","+","#"])
  assert(Vector2(foot.x-tile.x,foot.z-tile.y).length()>.35,"Lamp poles sit beside the route, away from unit feet")
  assert(lamp.get_node("LanternFrame").mesh==frame_shape)
  assert(lamp.get_node("LanternPaper").mesh==paper.mesh)
 var stage=Node3D.new();root.add_child(stage)
 var center=Vector3(35,0,0)
 var context=scenery.combat_context(game,{"x":2,"y":4},{"x":3,"y":4})
 scenery.battle_landscape(stage,center,context)
 var arena_lamps=stage.find_children("TrailLantern*","Node3D",false,false)
 assert(arena_lamps.size()==5 and stage.find_children("*","Light3D",true,false).is_empty())
 for lamp in arena_lamps:
  var housing=lamp.get_node("LanternFrame")
  var window=lamp.get_node("LanternPaper")
  assert(housing.mesh==frame_shape and window.mesh==paper.mesh)
  assert(housing.material_override==frame.material_override and window.material_override==paper.material_override)
  assert((housing.global_transform*housing.get_aabb()).end.z<-3.7 and is_zero_approx(lamp.global_position.y),
   "Arena fixtures are planted behind the combat lane")
 var tree_silhouettes=[]
 for tree in stage.find_children("ArenaTree*","Node3D",false,false):
  for tree_part in tree.find_children("*","MeshInstance3D",true,false):
   var silhouette=tree_part.global_transform*tree_part.get_aabb()
   if silhouette.end.z>center.z-6.5:tree_silhouettes.append(silhouette)
 var viewport=SubViewport.new();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var camera=Camera3D.new();viewport.add_child(camera);camera.current=true
 for mounted in [false,true]:
  var shot=CombatCamera.frame_pair(center+Vector3.LEFT*1.6,center+Vector3.RIGHT*1.6,"wide",false,mounted)
  camera.position=shot.anchor;camera.fov=shot.lens;camera.look_at(shot.focus)
  for dimensions in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
   viewport.size=dimensions;await process_frame
   var open_screen=Rect2(Vector2(16,16),Vector2(dimensions)-Vector2(32,164))
   var fixtures=arena_lamps.filter(func(lamp):
    var position=lamp.get_node("LanternPaper").global_position
    var clear=not tree_silhouettes.any(func(silhouette):return silhouette.intersects_segment(camera.global_position,position)!=null)
    return clear and not camera.is_position_behind(position) and open_screen.has_point(camera.unproject_position(position)))
   assert(fixtures.size()>=2,"At least two unoccluded lantern windows appear above the HUD in the wide shot")
 var frame_paint=frame.material_override;var paper_paint=paper.material_override
 scenery.batcher.combine(world)
 var frame_batches=world.get_children().filter(func(node):return node is MeshInstance3D and node.material_override==frame_paint)
 var paper_batches=world.get_children().filter(func(node):return node is MeshInstance3D and node.material_override==paper_paint)
 assert(frame_batches.size()==2 and paper_batches.size()==2,"Both materials batch into the two spatial groups along the road")
 var frame_vertices=0
 for batch in frame_batches:frame_vertices+=batch.mesh.surface_get_array_len(0)
 assert(frame_vertices==points.size()*lamps.size(),"Batching keeps all six housings and their colored surfaces")
 world.queue_free();stage.queue_free();viewport.queue_free();await process_frame
 assert(game.save_data("camp")==before,"Lamp placement never touches the campaign or RNG")
 print("PASS: six Greywood roadside fixtures, five reused arena lanterns, four shared map batches, no extra lights and six unoccluded wide-shot projections")

func verify_greywood_shelter():
 var scenery=Scenery.new();scenery.batching_enabled=false
 var game=Rules.new();game.chapter=2
 var snapshot=game.save_data("camp")
 var field=Node3D.new();root.add_child(field);scenery.landscape(field,game)
 var refuge=field.get_node("GreywoodShelter")
 var fabric=refuge.get_node("Canvas")
 var arrays=fabric.mesh.surface_get_arrays(0)
 var points=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL]
 assert(points.size()==78,"The single canvas uses 26 shallow triangles")
 for i in range(0,points.size(),3):
  var face=(points[i+1]-points[i]).cross(points[i+2]-points[i])
  assert(face.length()>.0001 and face.normalized().dot(normals[i])<-.90)
 var entry=barrel_hit(fabric.mesh,Vector3(.12,.20,1.0),Vector3.FORWARD)
 assert(entry!=null and entry.z<-.69,"The open front and covered rear read as a sheltered entrance")
 var tied=barrel_hit(fabric.mesh,Vector3(.38,.20,1.0),Vector3.FORWARD)
 assert(tied!=null and tied.z>.68,"Canvas flaps cover both sides of the entrance")
 for side in [-1.0,1.0]:
  var roof=barrel_hit(fabric.mesh,Vector3(side*.3,2,0),Vector3.DOWN)
  assert(roof!=null and absf(roof.y-lerpf(1.08,.045,.3/.66))<.0001)
 for child in refuge.get_children():
  if child==fabric:continue
  var support=child.transform*child.mesh.get_aabb()
  if child.name=="RidgePole":
   assert(support.end.y>1.07 and support.size.z>1.44)
  else:
   assert(absf(support.position.y)<.0001,"Both rails and uprights meet the ground")
 var covered=fabric.global_transform*fabric.mesh.get_aabb()
 for x in [3,4]:
  for z in [1,2]:
   assert(game.terrain(Vector2i(x,z))=="." and not covered.has_point(Vector3(x,.20,z)))
 var viewport=SubViewport.new();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var camera=Camera3D.new();viewport.add_child(camera);camera.current=true
 var center=Vector3((game.board_size().x-1)*.5,0,(game.board_size().y-1)*.5)
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=maxf(16,game.board_size().x+2)
 camera.position=center+Vector3(2.5,22,11.5);camera.look_at(center);camera.h_offset=2
 var sizes=[Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]
 for size in sizes:
  viewport.size=size;await process_frame
  var open_screen=Rect2(Vector2.ZERO,Vector2(size)).grow(-12)
  assert(shelter_ridge_visible(camera,refuge,field,open_screen))
 camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.h_offset=0
 center=Vector3(35,0,0)
 for mirror in [1.0,-1.0]:
  var context=scenery.combat_context(game,{"x":3,"y":3},{"x":4,"y":3},mirror)
  assert(context.landmarks[0].map_site==Vector2(3.5,1.5))
  var stage=Node3D.new();root.add_child(stage);scenery.battle_landscape(stage,center,context)
  var shelter=stage.find_children("GreywoodShelter","Node3D",true,false)[0]
  var arena_fabric=shelter.get_node("Canvas")
  assert(arena_fabric.mesh==fabric.mesh and arena_fabric.material_override==fabric.material_override)
  var frame=CombatCamera.frame_pair(center+Vector3.LEFT*1.6,center+Vector3.RIGHT*1.6,"wide",false,mirror<0)
  camera.position=frame.anchor;camera.fov=frame.lens;camera.look_at(frame.focus)
  for size in sizes:
   viewport.size=size;await process_frame
   var open_screen=Rect2(Vector2(12,12),Vector2(size)-Vector2(24,164))
   assert(shelter_ridge_visible(camera,shelter,stage,open_screen))
  stage.free()
 viewport.free();field.free()
 assert(game.save_data("camp")==snapshot)
 print("PASS: Greywood's map and close-up shelter share a pitched canvas, open entrance, grounded supports and nine projections")

func shelter_ridge_visible(camera: Camera3D,shelter: Node3D,landscape: Node3D,frame: Rect2) -> bool:
 var trees=landscape.find_children("Conifer*","MeshInstance3D",true,false)
 var clear=0
 for z in [.4,.52,.65]:
  var ridge=shelter.to_global(Vector3(0,1.08,z))
  var pixel=camera.unproject_position(ridge)
  if camera.is_position_behind(ridge) or not frame.has_point(pixel):continue
  var eye=camera.project_ray_origin(pixel)
  if not trees.any(func(tree):return (tree.global_transform*tree.mesh.get_aabb()).intersects_segment(eye,ridge)!=null):
   clear+=1
 return clear>=2

func verify_kingsroad_canal():
 var scenery=Scenery.new();scenery.batching_enabled=false
 var game=Rules.new();game.chapter=4;var rng=game.rng.state
 var normal=scenery.combat_context(game,{"x":9,"y":4},{"x":9,"y":3})
 var mirrored=scenery.combat_context(game,{"x":9,"y":4},{"x":9,"y":3},-1.0)
 var dry=scenery.combat_context(game,{"x":12,"y":0},{"x":13,"y":0})
 var deck=scenery.combat_context(game,{"x":4,"y":1},{"x":5,"y":1})
 var distant=scenery.combat_context(game,{"x":4,"y":3},{"x":5,"y":3})
 assert(normal.road_canal and mirrored.road_canal and not dry.road_canal)
 assert(deck.road_canal and deck.terrain=="=")
 assert(normal.road_hoist and mirrored.road_hoist and distant.road_canal and not distant.road_hoist)
 var field=Node3D.new();root.add_child(field);scenery.landscape(field,game)
 var map_hoist=field.get_node("KingsroadCargoHoist")
 assert(map_hoist.position==KingsroadHoist.MAP_SITE and map_hoist.scale==Vector3.ONE*KingsroadHoist.MAP_SCALE)
 inspect_hoist(map_hoist,2.5,1.5)
 var mast=map_hoist.get_node("HoistMast")
 var mast_bounds=mast.global_transform*mast.mesh.get_aabb()
 assert(not mast_bounds.has_point(Vector3(9,mast_bounds.get_center().y,3)),"The crane leaves the adjacent tactical cell center open")
 field.queue_free();await process_frame
 var center=Vector3(35,0,0)
 var viewport=SubViewport.new();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var camera=Camera3D.new();viewport.add_child(camera);camera.current=true
 for context in [normal,mirrored,dry,deck,distant]:
  var stage=Node3D.new();root.add_child(stage);scenery.battle_landscape(stage,center,context)
  var water=stage.get_node_or_null("KingsroadCanalWater")
  var hoist=stage.get_node_or_null("KingsroadCargoHoist")
  assert((hoist!=null)==(context==normal or context==mirrored))
  if hoist!=null:inspect_hoist(hoist,Scenery.ROAD_CANAL_NEAR,Scenery.ROAD_CANAL_FAR)
  if context==dry:
   assert(water==null and stage.get_node("ArenaGround").mesh.size==Vector2(70,70))
  elif context==deck:
   assert(water==null and stage.has_node("ArenaWater") and stage.has_node("ArenaDeck"))
  else:
   assert(water!=null and water.material_override==scenery.water_material("road"))
   var near_bank=stage.get_node("ArenaGround")
   var far_bank=stage.get_node("KingsroadFarBank")
   var near_bounds=near_bank.transform*near_bank.mesh.get_aabb()
   var far_bounds=far_bank.transform*far_bank.mesh.get_aabb()
   var water_bounds=water.transform*water.mesh.get_aabb()
   assert(near_bank.material_override==far_bank.material_override)
   assert(near_bounds.position.z==water_bounds.end.z and far_bounds.end.z==water_bounds.position.z,"Land and water share both exact channel edges")
   assert(near_bounds.position.z<=-5.0 and is_zero_approx(near_bounds.position.y) and is_zero_approx(far_bounds.position.y))
   var revetments=stage.find_children("CanalRevetment*","MeshInstance3D",false,false)
   var caps=stage.find_children("CanalCoping*","MeshInstance3D",false,false)
   assert(revetments.size()==2 and caps.size()==2)
   var wall_bounds=[]
   for index in 2:
    var wall=revetments[index].transform*revetments[index].mesh.get_aabb()
    var cap=caps[index].transform*caps[index].mesh.get_aabb()
    assert(wall.intersects(cap) and wall.position.y<water.position.y and wall.end.y>water.position.y)
    wall_bounds.append(wall.merge(cap))
   for anchor in stage.find_children("ArenaLandmark*","Node3D",false,false):
    var tower=anchor.get_node_or_null("FortifiedTower")
    if tower!=null:assert((tower.global_transform*tower.mesh.get_aabb()).end.z<=far_bounds.end.z,"Mapped tower remains planted on the far bank")
   for mounted in [false,true]:
    var shot=CombatCamera.frame_pair(center+Vector3.LEFT*1.6,center+Vector3.RIGHT*1.6,"wide",false,mounted)
    camera.position=shot.anchor;camera.fov=shot.lens;camera.look_at(shot.focus)
    for dimensions in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
     viewport.size=dimensions;await process_frame
     var safe=Rect2(Vector2(20,20),Vector2(dimensions)-Vector2(40,174))
     var wet=center+Vector3(-3,water.position.y,-8.4)
     assert(safe.has_point(camera.unproject_position(wet)) and not camera.is_position_behind(wet))
     assert(wall_bounds.all(func(wall):return wall.intersects_segment(camera.global_position,wet)==null),
      "The wide shot sees the water surface above the near coping")
     if hoist!=null:
      var head=hoist.to_global(KingsroadHoist.BOOM_TIP)
      var eye=hoist.get_node("HoistEye").global_position
      assert(not camera.is_position_behind(head) and safe.has_point(camera.unproject_position(head)))
      assert(safe.has_point(camera.unproject_position(eye)))
      var visible=absf(camera.unproject_position(head).x-camera.unproject_position(hoist.get_node("HoistMast").global_position).x)
      assert(visible>=24,"The projecting crane arm can be read in the wide shot")
  stage.queue_free();await process_frame
 viewport.queue_free();await process_frame
 assert(game.rng.state==rng)
 print("PASS: Kingsroad channel follows actual terrain, exact split banks and waterline, existing bridge/deck and dry cases, planted towers, the anchored cargo hoist and eighteen wide-shot projections")

func inspect_hoist(hoist: Node3D,bank: float,far_bank: float):
 var footing=hoist.get_node("HoistFooting")
 var cap=hoist.get_node("HoistCap")
 var post=hoist.get_node("HoistMast")
 var base=footing.global_transform*footing.mesh.get_aabb()
 var top=cap.global_transform*cap.mesh.get_aabb()
 var upright=post.global_transform*post.mesh.get_aabb()
 var pulley=hoist.get_node("HoistPulley")
 var eye=hoist.get_node("HoistEye")
 assert(base.position.y<0 and base.position.z>=bank and base.intersects(top) and top.intersects(upright))
 assert(eye.global_position.z<bank and eye.global_position.z>far_bank and eye.global_position.y>.5)
 assert(is_equal_approx(eye.global_position.z,pulley.global_position.z))
 var chain=hoist.find_children("HoistChainLink*","MeshInstance3D",false,false)
 assert(chain.size()==9 and chain.all(func(link):return link.mesh==KingsroadHoist.ring_shape()))
 var previous=pulley.global_transform*pulley.mesh.get_aabb()
 for link in chain+[eye]:
  var box=link.global_transform*link.mesh.get_aabb()
  assert(previous.intersects(box),"The chain reaches the pulley, overlaps its neighboring links and holds the lifting eye")
  previous=box

func verify_aqueduct_gallery():
 var scenery=Scenery.new();scenery.batching_enabled=false
 var game=Rules.new();game.chapter=7
 var context=scenery.combat_context(game,{"x":5,"y":5},{"x":6,"y":5})
 assert(context.environment=="aqueduct" and context.terrain=="p" and context.landmarks.size()==2)
 var center=Vector3(35,0,0)
 var viewport=SubViewport.new();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var camera=Camera3D.new();viewport.add_child(camera);camera.current=true
 var frame=CombatCamera.frame_pair(center+Vector3.LEFT*1.6,center+Vector3.RIGHT*1.6,"wide",false)
 camera.position=frame.anchor;camera.fov=frame.lens;camera.look_at(frame.focus)
 var spill_shape=Scenery.aqueduct_spill_mesh()
 var spill_material=preload("res://scripts/fountain.gd").stream_material()
 var mounted_frame=CombatCamera.frame_pair(center+Vector3.LEFT*1.6,center+Vector3.RIGHT*1.6,"wide",false,true)
 var field=Node3D.new();root.add_child(field);scenery.landscape(field,game)
 var map_wheel=field.get_node("AqueductWaterwheel")
 assert(map_wheel.position==AqueductWheel.MAP_SITE)
 assert(game.terrain(Vector2i(roundi(map_wheel.position.x),roundi(map_wheel.position.z)))=="~")
 inspect_aqueduct_wheel(map_wheel,-.07)
 for terrain in ["p","="]:
  context.terrain=terrain
  var arena=Node3D.new();root.add_child(arena);scenery.battle_landscape(arena,center,context)
  var gallery=arena.get_node("AqueductGallery")
  var water=arena.get_node("ArenaWater")
  var wheel=arena.get_node("AqueductWaterwheel")
  inspect_aqueduct_wheel(wheel,water.global_position.y)
  assert(is_equal_approx(wheel.position.x,gallery.position.x-6))
  assert(is_equal_approx(wheel.position.z,gallery.position.z+1.18))
  map_wheel.seek_phase(1.27);scenery.transfer_environment_motion(field,arena,"aqueduct")
  assert(is_equal_approx(wheel.rotor.rotation.x,map_wheel.rotor.rotation.x))
  wheel._process(.5);scenery.transfer_environment_motion(arena,field,"aqueduct")
  assert(is_equal_approx(map_wheel.phase,1.27+.5*AqueductWheel.TURN_RATE))
  wheel.hide();wheel._process(1.0)
  assert(is_equal_approx(wheel.phase,map_wheel.phase),"A hidden wheel suspends motion")
  wheel.show()
  var footings=gallery.find_children("GalleryFooting*","MeshInstance3D",false,false)
  var piers=gallery.find_children("GalleryPier*","MeshInstance3D",false,false)
  var capitals=gallery.find_children("GalleryCapital*","MeshInstance3D",false,false)
  var arches=gallery.find_children("MasonryArch*","MeshInstance3D",false,false)
  var channel=gallery.find_children("ChannelStone*","MeshInstance3D",false,false)
  assert(footings.size()==7 and piers.size()==7 and capitals.size()==7 and arches.size()==6 and channel.size()==6)
  assert(arches.all(func(arch):return arch.mesh==arches[0].mesh),"The aqueduct reuses one arch mesh across all its spans")
  for index in 7:
   var footing=footings[index];var pier=piers[index];var capital=capitals[index]
   var lower=footing.transform*footing.mesh.get_aabb()
   var shaft=pier.transform*pier.mesh.get_aabb()
   assert(lower.position.y+center.y<water.position.y and lower.end.y+center.y>water.position.y)
   assert(shaft.intersects(lower) and shaft.intersects(capital.transform*capital.mesh.get_aabb()),"Each pier connects its submerged footing and capital")
  var coping=gallery.get_node("ChannelCoping")
  var coping_bounds=coping.transform*coping.mesh.get_aabb()
  var falls=gallery.find_children("AqueductSpill*","MeshInstance3D",false,false)
  var lips=gallery.find_children("SpillwayLip*","MeshInstance3D",false,false)
  assert(falls.size()==2 and lips.size()==2)
  var flow=spill_shape.surface_get_arrays(0)
  var points=flow[Mesh.ARRAY_VERTEX];var uv=flow[Mesh.ARRAY_TEX_UV];var normals=flow[Mesh.ARRAY_NORMAL]
  assert(points.size()==72)
  for index in range(0,points.size(),3):
   var normal=(points[index+1]-points[index]).cross(points[index+2]-points[index]).normalized()
   assert(normal.dot(normals[index])<-.999,"The falling ribbons retain lit outward-facing surfaces")
  for index in falls.size():
   var fall=falls[index]
   assert(fall.mesh==spill_shape and fall.material_override==spill_material)
   assert(fall.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
   var lip=lips[index].global_transform*lips[index].mesh.get_aabb()
   assert(lip.position.z<gallery.global_position.z+.48 and lip.end.z>gallery.global_position.z+.70)
   for vertex in points.size():
    var point=fall.to_global(points[vertex])
    if is_zero_approx(uv[vertex].y):
     assert(is_equal_approx(point.y,lip.end.y) and is_equal_approx(point.z,lip.end.z),
      "The first row meets the stone lip exactly")
     assert(point.x>=lip.position.x and point.x<=lip.end.x)
    if is_equal_approx(uv[vertex].y,1):
     assert(is_equal_approx(point.y,water.global_position.y) and point.z>lip.end.z,
      "The last row meets the stage’s actual pool height")
  for index in 6:
   var arch=arches[index];var span=arch.transform*arch.mesh.get_aabb()
   var course=channel[index].transform*channel[index].mesh.get_aabb()
   for capital in [capitals[index],capitals[index+1]]:
    assert(span.intersects(capital.transform*capital.mesh.get_aabb()),"Each arch reaches both capitals")
   assert(span.intersects(course) and course.intersects(coping_bounds),"The channel spans the arches with a continuous coping")
  var shelf=arena.get_node("AqueductFarWalk")
  for anchor in arena.find_children("ArenaLandmark*","Node3D",false,false):
   assert(is_equal_approx(anchor.position.y,shelf.position.y) and anchor.position.z<shelf.position.z+shelf.mesh.size.y*.5-.65)
  assert(arena.has_node("AqueductParapet")== (terrain=="p") and arena.has_node("ArenaDeck")== (terrain=="="))
  for dimensions in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
   viewport.size=dimensions;await process_frame
   var crown=gallery.to_global(Vector3(-2,coping_bounds.end.y,0))
   var screen=camera.unproject_position(crown)
   assert(not camera.is_position_behind(crown) and Rect2(Vector2.ZERO,Vector2(dimensions)).grow(-10).has_point(screen),"The middle span and channel crest fit the default wide shot")
   var safe=Rect2(Vector2(20,20),Vector2(dimensions)-Vector2(40,176))
   assert(falls.any(func(fall):
    var flowing=fall.to_global(Scenery.spill_point(.5,.42))
    return not camera.is_position_behind(flowing) and safe.has_point(camera.unproject_position(flowing))),
    "A spillway is visible above the HUD in every wide shot")
   var wheel_top=wheel.to_global(Vector3(.46,AqueductWheel.AXLE_HEIGHT+.91,-.14))
   assert(not camera.is_position_behind(wheel_top) and safe.has_point(camera.unproject_position(wheel_top)),
    "The feeding wheel stays in shot above the combat HUD")
   camera.position=mounted_frame.anchor;camera.fov=mounted_frame.lens;camera.look_at(mounted_frame.focus)
   assert(not camera.is_position_behind(wheel_top) and safe.has_point(camera.unproject_position(wheel_top)))
   camera.position=frame.anchor;camera.fov=frame.lens;camera.look_at(frame.focus)
  arena.queue_free();await process_frame
 field.queue_free();viewport.queue_free();await process_frame
 print("PASS: six planted aqueduct spans, connected channel coping, dry and deck foregrounds, grounded map landmarks and six projected wide shots")
 print("PASS: two Aqueduct spillways share the same mesh and meet their stone lips and both pool heights in six wide shots")
 print("PASS: the shared Aqueduct waterwheel wets both rims, connects ten paddles and its axle, fits twelve wide shots and transfers phase between landscapes")

func inspect_aqueduct_wheel(wheel: Node3D,waterline: float):
 wheel.set_process(false);wheel.seek_phase(0.0)
 assert(is_equal_approx(wheel.position.y,waterline))
 var rims=wheel.rotor.find_children("WheelRim*","MeshInstance3D",false,false)
 var paddles=wheel.rotor.find_children("WheelPaddle*","MeshInstance3D",false,false)
 var spokes=wheel.rotor.find_children("WheelSpoke*","MeshInstance3D",false,false)
 assert(rims.size()==2 and paddles.size()==10 and spokes.size()==12)
 for rim in rims:
  var bounds=rim.global_transform*rim.mesh.get_aabb()
  assert(rim.mesh==AqueductWheel.rim() and bounds.position.y<waterline and bounds.end.y>waterline+1.0)
 for index in paddles.size():
  var paddle=paddles[index]
  assert(is_equal_approx(paddle.position.length(),.99) and is_equal_approx(paddle.rotation.x,index*TAU/10))
  var slab=paddle.transform*paddle.mesh.get_aabb()
  assert(rims.all(func(rim):return slab.intersects(rim.transform*rim.mesh.get_aabb())))
 var axle=wheel.rotor.get_node("WheelAxle")
 var axle_bounds=axle.global_transform*axle.mesh.get_aabb()
 var bearings=wheel.find_children("WheelBearing*","MeshInstance3D",false,false)
 var feet=wheel.find_children("WheelFooting*","MeshInstance3D",false,false)
 var piers=wheel.find_children("WheelPier*","MeshInstance3D",false,false)
 assert(bearings.size()==2 and feet.size()==2 and piers.size()==2)
 for side in 2:
  var base=feet[side].global_transform*feet[side].mesh.get_aabb()
  var pier=piers[side].global_transform*piers[side].mesh.get_aabb()
  var bearing=bearings[side].global_transform*bearings[side].mesh.get_aabb()
  assert(base.position.y<waterline and base.intersects(pier) and pier.intersects(bearing) and bearing.intersects(axle_bounds))

func verify_reddeep_furnaces():
 var scenery=Scenery.new();scenery.batching_enabled=false
 var game=Rules.new();game.chapter=9
 var rng_state=game.rng.state
 var map=Node3D.new();root.add_child(map);scenery.landscape(map,game)
 var landmarks=map.find_children("FurnaceHearth*","Node3D",false,false)
 var layout=game.info().landmarks
 assert(landmarks.size()==layout.size() and layout.size()==2,"Expected two Reddeep hearths, got %s at %s" % [landmarks,layout])
 for i in landmarks.size():
  assert(landmarks[i].position==Vector3(layout[i].position[0],0,layout[i].position[1]))
  verify_hearth(landmarks[i])
 var context=scenery.combat_context(game,{"x":4,"y":5},{"x":6,"y":5})
 var arena=Node3D.new();root.add_child(arena)
 var center=Vector3(35,0,0)
 scenery.battle_landscape(arena,center,context)
 var staged=arena.find_children("FurnaceHearth*","Node3D",true,false)
 assert(staged.size()==2 and context.landmarks.size()==2)
 for hearth in staged:
  verify_hearth(hearth)
  var anchor=hearth.get_parent() as Node3D
  var foundation=hearth.get_node("HearthFoundation")
  assert(anchor.position.y==center.y and anchor.position.z<center.z-6 and anchor.scale.is_equal_approx(Vector3.ONE*2.1))
  assert(foundation.mesh==landmarks[0].get_node("HearthFoundation").mesh)
  assert(hearth.get_node("MasonryArch").mesh==landmarks[0].get_node("MasonryArch").mesh)
  assert(foundation.material_override==landmarks[0].get_node("HearthFoundation").material_override)
 var fallback=Node3D.new();root.add_child(fallback)
 scenery.battle_landscape(fallback,center,{"environment":"furnace"})
 var extra=fallback.find_children("FurnaceHearth*","Node3D",false,false)
 assert(extra.size()==2 and extra.all(func(hearth):return hearth.position.z==center.z-8 and hearth.scale.is_equal_approx(Vector3.ONE*2.1)))
 verify_reddeep_service_sheds(map,arena,fallback,game.board_size())
 await verify_reddeep_gantry(arena,center,staged)
 await verify_reddeep_gantry(fallback,center,extra)
 assert(game.rng.state==rng_state)
 map.queue_free();arena.queue_free();fallback.queue_free();await process_frame
 print("PASS: two Reddeep map hearths, arched fireboxes, connected grates, open chimney flues and actual arena counterparts")
 print("PASS: five planted Reddeep gantry supports, four crossed spans, two connected hoists and twelve wide-shot projections")

func verify_reddeep_service_sheds(field: Node3D, arena: Node3D, fallback: Node3D, size: Vector2i):
 var board=Rect2(Vector2(-.5,-.5),Vector2(size))
 var apron=field.get_child(0) as MeshInstance3D
 assert(apron.material_override is StandardMaterial3D and apron.position.y<0)
 for part in field.find_children("ReddeepCoping*","MeshInstance3D",false,false)+field.find_children("ReddeepSlagPile*","MeshInstance3D",false,false):
  var bbox=part.transform*part.mesh.get_aabb()
  assert(not board.intersects(Rect2(Vector2(bbox.position.x,bbox.position.z),Vector2(bbox.size.x,bbox.size.z))))
  assert(bbox.position.y<apron.position.y and bbox.end.y>apron.position.y)
 var material: StandardMaterial3D
 var triangular_roof: ArrayMesh
 for site in [field,arena,fallback]:
  var sheds=site.get_node("ReddeepServiceSheds")
  var bounds=func(part):return sheds.transform*part.transform*part.mesh.get_aabb()
  var walls=sheds.find_children("ReddeepServiceWall*","MeshInstance3D",false,false)
  var roofs=sheds.find_children("ReddeepIronRoof*","MeshInstance3D",false,false)
  var gables=sheds.find_children("ReddeepGable*","MeshInstance3D",false,false)
  var lights=sheds.find_children("ReddeepVentLight*","MeshInstance3D",false,false)
  assert([walls.size(),roofs.size(),gables.size(),lights.size()]==[4,8,8,24])
  if material==null:material=lights[0].material_override
  if triangular_roof==null:triangular_roof=gables[0].mesh
  assert(material.emission_enabled and material.emission_energy_multiplier<1.0)
  assert(gables.all(func(part):return part.mesh==triangular_roof))
  assert(lights.all(func(part):return part.material_override==material))
  var edge=-.5 if site==field else site.get_node("ReddeepGantry").position.z-3.5
  for index in walls.size():
   assert(bounds.call(walls[index]).end.z<edge)
   assert(bounds.call(roofs[index*2]).intersects(bounds.call(gables[index*2])))
   assert(bounds.call(roofs[index*2+1]).intersects(bounds.call(gables[index*2])))
 var scenery=Scenery.new()
 var game=Rules.new();game.chapter=9
 var cached_field=Node3D.new();root.add_child(cached_field);scenery.landscape(cached_field,game)
 var cached_arena=Node3D.new();root.add_child(cached_arena)
 scenery.battle_landscape(cached_arena,Vector3(35,0,0),{"environment":"furnace"})
 var field_batches=cached_field.get_node("ReddeepServiceSheds").get_children()
 var arena_batches=cached_arena.get_node("ReddeepServiceSheds").get_children()
 assert(field_batches.size()==arena_batches.size() and field_batches.size()<=7)
 for index in field_batches.size():
  assert(field_batches[index].mesh==arena_batches[index].mesh and field_batches[index].material_override==arena_batches[index].material_override)
 cached_field.free();cached_arena.free()
 print("PASS: shared Reddeep service sheds, eight iron roof slopes and 24 warm vents beyond the board and both gantry layouts")

func verify_reddeep_cart():
 var scenery=Scenery.new();scenery.batching_enabled=false
 var game=Rules.new();game.chapter=9
 var rng_state=game.rng.state
 var near=scenery.combat_context(game,{"x":7,"y":5},{"x":7,"y":6})
 var reflected=scenery.combat_context(game,{"x":7,"y":5},{"x":7,"y":6},-1.0)
 var far=scenery.combat_context(game,{"x":1,"y":1},{"x":2,"y":1})
 var deck=scenery.combat_context(game,{"x":7,"y":7},{"x":6,"y":7})
 assert(near.slag_cart and reflected.slag_cart and not far.slag_cart and deck.terrain=="=" and not deck.has("slag_cart"))
 var map=Node3D.new();root.add_child(map);scenery.landscape(map,game)
 var cart=map.get_node("ReddeepSlagCart")
 assert(cart.position==ReddeepCart.MAP_SITE and cart.scale==Vector3.ONE*ReddeepCart.MAP_SCALE)
 inspect_reddeep_cart(cart)
 for part in cart.get_children():
  var bounds=part.global_transform*part.mesh.get_aabb()
  assert(bounds.position.x>6.5 and bounds.end.x<7.5,"The cart and rails fit on the paved bank")
  for tile in [Vector2i(7,5),Vector2i(7,6)]:
   assert(game.terrain(tile)=="p")
   var from_ground=Vector3(tile.x,0,tile.y)
   assert(bounds.intersects_segment(from_ground,from_ground+Vector3.UP)==null,"The centers of adjacent tactical tiles stay open")
 var viewport=SubViewport.new();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var camera=Camera3D.new();viewport.add_child(camera);camera.current=true
 var board_center=Vector3(6.5,0,4.5)
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=16
 camera.position=board_center+Vector3(2.5,22,11.5);camera.look_at(board_center);camera.h_offset=2
 var sizes=[Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]
 for dimensions in sizes:
  viewport.size=dimensions;await process_frame
  var bounds=project_cart(cart,camera)
  assert(bounds.size.x>=24 and bounds.size.y>=30 and bounds.position.y>118 and bounds.end.x<dimensions.x-325,"The rail cart stays visible beside the tactical controls")
 camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.h_offset=0
 var center=Vector3(35,0,0)
 for context in [near,reflected,far,deck]:
  var stage=Node3D.new();root.add_child(stage);scenery.battle_landscape(stage,center,context)
  var staged=stage.get_node_or_null("ReddeepSlagCart")
  assert((staged!=null)==context.get("slag_cart",false),"Only nearby stone exchanges show the slag cart")
  if staged!=null:
   inspect_reddeep_cart(staged)
   for part in ["CartHopper","CartSlag","CartHub"]:
    assert(staged.get_node(part).mesh==cart.get_node(part).mesh,"Tactical scenery and close-up share the same cart geometry")
   var floor=stage.get_children().filter(func(part):return part is MeshInstance3D and part.mesh is PlaneMesh and part.mesh.size==Vector2(70,70))[0]
   assert(staged.position.is_equal_approx(center+ReddeepCart.ARENA_SITE) and is_equal_approx(staged.position.y,floor.position.y))
   for mounted in [false,true]:
    var shot=CombatCamera.frame_pair(center+Vector3.LEFT*1.6,center+Vector3.RIGHT*1.6,"wide",false,mounted)
    camera.position=shot.anchor;camera.fov=shot.lens;camera.look_at(shot.focus)
    for dimensions in sizes:
     viewport.size=dimensions;await process_frame
     var bounds=project_cart(staged,camera)
     assert(bounds.size.x>=95 and bounds.size.y>=62 and bounds.end.x<dimensions.x*.4)
     assert(Rect2(Vector2(20,20),Vector2(dimensions)-Vector2(40,174)).encloses(bounds),"The cart stays clear of the duel and HUD")
  stage.queue_free();await process_frame
 assert(game.rng.state==rng_state)
 map.queue_free();viewport.queue_free();await process_frame
 print("PASS: Reddeep rail cart, four wheels seated on rails, open slag hopper, open tactical cell centers, three map and twelve arena projections")

func inspect_reddeep_cart(cart: Node3D):
 var rails=cart.find_children("CartRailHead*","MeshInstance3D",false,false)
 var sleepers=cart.find_children("CartSleeper*","MeshInstance3D",false,false)
 var wheels=cart.find_children("CartWheel*","MeshInstance3D",false,false).filter(func(part):return not str(part.name).begins_with("CartWheelFlange"))
 var axles=cart.find_children("CartAxle*","MeshInstance3D",false,false)
 assert(rails.size()==2 and sleepers.size()==7 and wheels.size()==4 and axles.size()==2)
 for part in wheels+axles+cart.find_children("CartRivet*","MeshInstance3D",false,false):
  assert(part.mesh==wheels[0].mesh and part.mesh.rings==0,"Axles, wheels and rivets share a low-poly radial mesh")
 for rail in rails:
  var base=cart.find_children("CartRailBase*","MeshInstance3D",false,false).filter(func(part):return part.position.x==rail.position.x)[0]
  var rail_bounds=rail.transform*rail.mesh.get_aabb()
  var base_bounds=base.transform*base.mesh.get_aabb()
  assert(rail_bounds.intersects(base_bounds))
  for sleeper in sleepers:
   var support=sleeper.transform*sleeper.mesh.get_aabb()
   assert(support.position.y<0 and support.intersects(base_bounds),"Sleeper is grounded and supports the rail")
  for wheel in wheels.filter(func(part):return part.position.x==rail.position.x):
   var lowest=INF
   for vertex in wheel.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:lowest=minf(lowest,(wheel.transform*vertex).y)
   assert(is_equal_approx(lowest,rail_bounds.end.y),"Actual tread vertices meet the rail head")
   var axle=axles.filter(func(part):return part.position.z==wheel.position.z)[0]
   assert((wheel.transform*wheel.mesh.get_aabb()).intersects(axle.transform*axle.mesh.get_aabb()))
 var hopper=cart.get_node("CartHopper").mesh
 var inside=barrel_hit(hopper,Vector3(-.17,2,0),Vector3.DOWN)
 var rim=barrel_hit(hopper,Vector3(0,2,-.87),Vector3.DOWN)
 assert(inside!=null and is_equal_approx(inside.y,.630) and rim!=null and is_equal_approx(rim.y,1.037),"The hopper has an open interior with a raised steel lip")
 assert(is_equal_approx(mesh_top(cart.get_node("CartSlag").mesh,Vector2(.02,-.184)),.766),"Slag rises from the open hopper floor")
 for piece in ["CartHopper","CartSlag"]:
  var surface=cart.get_node(piece).mesh.surface_get_arrays(0)
  var points=surface[Mesh.ARRAY_VERTEX];var normals=surface[Mesh.ARRAY_NORMAL]
  assert(points.size()/3<100)
  for index in range(0,points.size(),3):
   var face=(points[index+1]-points[index]).cross(points[index+2]-points[index])
   assert(face.length_squared()>.000001 and face.normalized().dot(normals[index])<-.999)

func project_cart(cart: Node3D,camera: Camera3D) -> Rect2:
 var bounds=Rect2(camera.unproject_position(cart.global_position),Vector2.ZERO)
 for part in cart.get_children():
  var local=part.mesh.get_aabb()
  for index in 8:
   var world=part.to_global(local.get_endpoint(index))
   assert(not camera.is_position_behind(world))
   bounds=bounds.expand(camera.unproject_position(world))
 return bounds

func verify_reddeep_gantry(stage: Node3D,center: Vector3,hearths: Array):
 var gantry=stage.get_node("ReddeepGantry")
 assert(gantry.position.z<=center.z-11.5)
 var footings=gantry.find_children("GantryFooting*","MeshInstance3D",false,false)
 var posts=gantry.find_children("GantryPost*","MeshInstance3D",false,false)
 var saddles=gantry.find_children("GantrySaddle*","MeshInstance3D",false,false)
 var chords=gantry.find_children("GantryChord*","MeshInstance3D",false,false)
 var braces=gantry.find_children("GantryDiagonal*","MeshInstance3D",false,false)
 assert(footings.size()==5 and posts.size()==5 and saddles.size()==5 and chords.size()==2 and braces.size()==8)
 var lower=chords[0].transform*chords[0].mesh.get_aabb()
 var upper=chords[1].transform*chords[1].mesh.get_aabb()
 for index in posts.size():
  var foot=footings[index].transform*footings[index].mesh.get_aabb()
  var post=posts[index].transform*posts[index].mesh.get_aabb()
  var saddle=saddles[index].transform*saddles[index].mesh.get_aabb()
  assert(foot.position.y<-.06 and foot.intersects(post) and post.intersects(saddle) and saddle.intersects(lower))
 for brace in braces:
  var bounds=brace.transform*brace.mesh.get_aabb()
  assert(bounds.intersects(lower) and bounds.intersects(upper),"Angled plates connect both truss chords")
 var drums=gantry.find_children("HoistDrum*","MeshInstance3D",false,false)
 var hangers=gantry.find_children("HoistHanger*","MeshInstance3D",false,false)
 var chain=gantry.find_children("HoistChain*","MeshInstance3D",false,false)
 var hooks=gantry.find_children("HoistHookBlock*","MeshInstance3D",false,false)
 assert(drums.size()==2 and hangers.size()==2 and chain.size()==4 and hooks.size()==2 and drums[0].mesh==drums[1].mesh)
 for index in drums.size():
  var drum_bounds=drums[index].transform*drums[index].mesh.get_aabb()
  var hanger_bounds=hangers[index].transform*hangers[index].mesh.get_aabb()
  var hook_bounds=hooks[index].transform*hooks[index].mesh.get_aabb()
  assert(drum_bounds.intersects(hanger_bounds) and hanger_bounds.intersects(lower))
  for hanging in [chain[index*2],chain[index*2+1]]:
   var bounds=hanging.transform*hanging.mesh.get_aabb()
   assert(bounds.intersects(drum_bounds) and bounds.intersects(hook_bounds),"Both chains connect the hoist drum to its block")
 var hearth_silhouettes=[]
 for hearth in hearths:
  var foundation=hearth.get_node("HearthFoundation")
  var base=foundation.global_transform*foundation.mesh.get_aabb()
  assert(base.position.z>gantry.global_position.z+.6,"The gantry stands behind each foundry hearth")
  for part in hearth.find_children("*","MeshInstance3D",true,false):
   hearth_silhouettes.append(part.global_transform*part.mesh.get_aabb())
 var viewport=SubViewport.new();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var camera=Camera3D.new();viewport.add_child(camera);camera.current=true
 for mounted in [false,true]:
  var shot=CombatCamera.frame_pair(center+Vector3.LEFT*1.6,center+Vector3.RIGHT*1.6,"wide",false,mounted)
  camera.position=shot.anchor;camera.fov=shot.lens;camera.look_at(shot.focus)
  for dimensions in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
   viewport.size=dimensions;await process_frame
   var safe=Rect2(Vector2(16,16),Vector2(dimensions)-Vector2(32,168))
   var visible=drums.filter(func(drum):
    var point=drum.global_position
    var clear=not hearth_silhouettes.any(func(part):return part.intersects_segment(camera.global_position,point)!=null)
    return clear and safe.has_point(camera.unproject_position(point)) and not camera.is_position_behind(point))
   assert(not visible.is_empty(),"At least one hoist remains clear of foreground hearths and the HUD")
 viewport.queue_free();await process_frame

func verify_hearth(hearth: Node3D):
 var foundation=hearth.get_node("HearthFoundation")
 var floor_bounds=foundation.transform*foundation.mesh.get_aabb()
 assert(floor_bounds.position.y<-.07 and floor_bounds.end.y>.1,"The foundation rises from the channel through the hearth floor")
 var arch=hearth.get_node("MasonryArch")
 var hood=hearth.get_node("HearthHood")
 assert((arch.transform*arch.mesh.get_aabb()).intersects(hood.transform*hood.mesh.get_aabb()),"The arch meets the hood")
 var crossbar=hearth.get_node("GrateCrossbar")
 var grate_bounds=crossbar.transform*crossbar.mesh.get_aabb()
 var grates=hearth.find_children("FurnaceGrate*","MeshInstance3D",false,false)
 assert(grates.size()==5)
 for bar in grates:
  var bounds=bar.transform*bar.mesh.get_aabb()
  assert(bounds.intersects(floor_bounds) and bounds.intersects(grate_bounds))
 var coals=hearth.find_children("HearthCoal*","MeshInstance3D",false,false)
 assert(coals.size()==7)
 var emission=coals[0].material_override
 for coal in coals:
  assert((coal.transform*coal.mesh.get_aabb()).end.z<grate_bounds.end.z and coal.material_override==emission and emission.emission_enabled)
 var chimney=hearth.find_children("ChimneySide*","MeshInstance3D",false,false)
 var lip=hearth.find_children("ChimneyLip*","MeshInstance3D",false,false)
 assert(chimney.size()==4 and lip.size()==4)
 var collar=hearth.get_node("FlueCollar")
 var collar_bounds=collar.transform*collar.mesh.get_aabb()
 for wall in chimney:
  var bounds=wall.transform*wall.mesh.get_aabb()
  assert(bounds.intersects(collar_bounds) and not bounds.has_point(Vector3(0,1.76,-.08)))
 for rim in lip:
  var bounds=rim.transform*rim.mesh.get_aabb()
  assert(chimney.any(func(wall):return bounds.intersects(wall.transform*wall.mesh.get_aabb())))
  assert(not bounds.has_point(Vector3(0,2.23,-.08)),"The flue stays open through the rim")

func verify_building_atlas(scenery):
 assert(scenery.building_atlas==null,"The atlas is loaded when a structure first needs it")
 var paints=[]
 for finish in range(4):
  var paint=scenery.building_material(finish)
  assert(paint==scenery.building_material(finish) and paint not in paints)
  assert(paint.get_shader_parameter("atlas_texture")==scenery.building_atlas and paint.get_shader_parameter("cell_origin")==Vector2(finish%2,finish/2)*.5)
  assert(paint.get_shader_parameter("tile_scale")>0 and paint.get_shader_parameter("paint_weight")>.5)
  paints.append(paint)
 var image=scenery.building_atlas.get_image()
 assert(image.get_size()==Vector2i(1254,1254) and image.has_mipmaps(),"The four diffuse swatches retain the measured atlas size and mipmaps")
 var averages=[]
 for finish in range(4):
  var start=Vector2i(finish%2,finish/2)*627
  var average=Color(0,0,0,0)
  for y in range(31,610,64):
   for x in range(31,610,64):
    var sample=image.get_pixel(start.x+x,start.y+y)
    assert(sample.a==1)
    average+=sample
  averages.append(average/100)
 assert(averages[0].g>averages[1].g and averages[1].g>averages[3].g and averages[3].g>averages[2].g)
 print("PASS: four original plaster and timber swatches load lazily in a single mipmapped atlas")

func verify_cloth():
 var world=Node3D.new();root.add_child(world);world.position=Vector3(35,.3,-2);world.rotation.y=.3;world.scale=Vector3.ONE*2
 var previous_material: ShaderMaterial
 for standard in [true,false]:
  var cloth=Cloth.new();world.add_child(cloth);cloth.set_process(false)
  var extent=Vector2(.45,.32) if standard else Vector2(1.3,1.4)
  cloth.configure(extent,Color("a54c47") if standard else Color("dcd4b9"),standard,Cloth.PERIOD-.01)
  assert(cloth.material!=previous_material,"Each cloth owns its paused motion phase")
  previous_material=cloth.material
  var arrays=cloth.cloth.mesh.surface_get_arrays(0);var points=arrays[Mesh.ARRAY_VERTEX];var uv=arrays[Mesh.ARRAY_TEX_UV];var normals=arrays[Mesh.ARRAY_NORMAL]
  assert(points.size()==432 and cloth.cloth.custom_aabb.size.z>0,"Cloth uses a fixed small grid with nonzero wind culling depth")
  var pinned=0;var fork=0
  for i in range(points.size()):
   assert(cloth.cloth.custom_aabb.grow(.0001).has_point(points[i]),"Rest geometry remains in the explicit deformation bounds")
   for depth in [-extent.x*.06,extent.x*.06]:
    assert(cloth.cloth.custom_aabb.grow(.0001).has_point(points[i]+Vector3(0,-extent.y*.045,depth)),"Culling bounds cover the full documented wind and sag envelope")
   if is_zero_approx(uv[i].x):
    assert(points[i].x==0 and points[i].z==0,"The full attachment edge lies on the mast plane")
    assert(cloth.to_global(points[i]).distance_to(world.to_global(Vector3(0,points[i].y,0)))<.0001,"Attachment survives a rotated and scaled parent")
    pinned+=1
   if is_equal_approx(uv[i].x,1) and is_equal_approx(uv[i].y,.5):
    assert(is_equal_approx(points[i].x,extent.x*(.87 if standard else 1)),"Standards have a forked edge; sails remain rectangular")
    fork+=1
  assert(pinned>0 and fork>0)
  for i in range(0,points.size(),3):assert((points[i+1]-points[i]).cross(points[i+2]-points[i]).normalized().dot(normals[i])<-.999,"Canvas has consistent front faces and normals")
  assert(cloth.material.get_shader_parameter("linen_atlas")==Cloth.LINEN and cloth.material.get_shader_parameter("dimensions")==extent,"Shared painted linen and local dimensions reach the shader")
  cloth._process(.02);assert(absf(cloth.phase-.01)<.00001,"Wind clock wraps at its common wave period")
  var phase=cloth.phase;world.hide();cloth._process(4)
  assert(cloth.phase==phase and cloth.material.get_shader_parameter("phase")==phase,"Hidden map/stage cloth stops updating")
  world.show();cloth._process(.2);assert(cloth.phase>phase)
  var batching=preload("res://scripts/static_batch.gd").new().combine(world)
  assert(batching.sources==0 and cloth.cloth.get_parent()==cloth,"Static batching preserves shader-local cloth geometry")
  cloth.queue_free();await process_frame
 world.queue_free();await process_frame
 var game=Rules.new();var scenery=Scenery.new();var flags=0;var sails=0;var state=game.rng.state
 var shapes={};var private_materials={}
 for chapter in range(12):
  game.chapter=chapter;world=Node3D.new();root.add_child(world);scenery.landscape(world,game)
  var pieces=world.find_children("*","Node3D",true,false).filter(func(node):return node is Cloth)
  for piece in pieces:
   shapes[piece.cloth.mesh]=true
   private_materials[piece.material.get_instance_id()]=true
   assert(piece.cloth.mesh==Cloth.mesh_for(piece.dimensions,piece.standard))
  var expected_flags=0;var expected_sails=0
  for row in game.info().map:expected_flags+=row.count("o")
  if game.info().environment=="castle":expected_flags+=2
  for landmark in game.info().landmarks:
   if landmark.kind=="boat":
    expected_sails+=1
    var at=landmark.position;var context=scenery.combat_context(game,{"x":int(at[0])-1,"y":int(at[1])},{"x":int(at[0]),"y":int(at[1])})
    var arena=Node3D.new();root.add_child(arena);scenery.battle_landscape(arena,Vector3(35,0,0),context)
    var arena_sails=arena.find_children("*","Node3D",true,false).filter(func(node):return node is Cloth and not node.standard)
    assert(arena_sails.size()==context.landmarks.filter(func(item):return item.kind=="boat").size(),"Nearby boats keep their cloth sails in actual combat backdrops")
    arena.queue_free()
  assert(pieces.filter(func(piece):return piece.standard).size()==expected_flags and pieces.filter(func(piece):return not piece.standard).size()==expected_sails,"All objective flags, gate standards and boat sails survive scene batching")
  flags+=expected_flags;sails+=expected_sails
  var references=pieces.map(func(piece):return weakref(piece));world.queue_free();await process_frame
  for reference in references:assert(reference.get_ref()==null,"Cloth resources release with their map")
 assert(flags==14 and sails==2 and game.rng.state==state,"All campaign cloth is bounded and independent of gameplay RNG")
 assert(shapes.size()==3 and private_materials.size()==16,"Map flags, standards and sails share three shapes and own their own materials")
 var original_meshes=Cloth.cloth_meshes.duplicate()
 for n in range(Cloth.MAX_CACHED_MESHES+3):
  Cloth.mesh_for(Vector2(3+n*.13,.52),true)
 assert(Cloth.cloth_meshes.size()==Cloth.MAX_CACHED_MESHES,"Temporary variants cannot grow the shared geometry cache")
 for key in original_meshes:
  assert(Cloth.cloth_meshes.get(key)==original_meshes[key],"Frequent campaign shapes keep their shared resources")
 var transient=Vector2(12.30,.64)
 assert(Cloth.mesh_for(transient,true)!=Cloth.mesh_for(transient,true),"One-off shapes stay usable after the cache fills")
 print("PASS: recurring flags and sails reuse source meshes, keep private material phases and bound the cache")

func verify_harbor_boats():
 var hull=HarborBoat.hull()
 assert(hull==HarborBoat.hull(),"Both harbor boats share the same cached geometry")
 var data=hull.surface_get_arrays(0)
 var points=data[Mesh.ARRAY_VERTEX]
 var normals=data[Mesh.ARRAY_NORMAL]
 var colors=data[Mesh.ARRAY_COLOR]
 var edges={}
 var palette={}
 var volume=0.0
 assert(points.size()/3==140 and colors.size()==points.size())
 for index in range(0,points.size(),3):
  var a=points[index];var b=points[index+1];var c=points[index+2]
  var cross=(b-a).cross(c-a)
  assert(cross.length()>.0001 and cross.normalized().dot(normals[index])<-.999,"The hull has outward-facing nondegenerate triangles")
  volume-=a.dot(b.cross(c))/6.0
  palette[colors[index]]=true
  for endpoints in [[a,b],[b,c],[c,a]]:
   var left=str(endpoints[0]);var right=str(endpoints[1])
   var key=left+"/"+right if left<right else right+"/"+left
   edges[key]=edges.get(key,0)+1
 assert(volume>1.2 and volume<1.3 and palette.size()>=12)
 for usage in edges.values():assert(usage==2,"The timber hull and deck close around every edge")
 var bounds=hull.get_aabb()
 assert(bounds.size.x<1.6 and bounds.size.z<3.2 and bounds.position.y<-.30 and bounds.end.y>.34)
 assert(HarborBoat.point(8,0).y>HarborBoat.point(0,0).y and absf(HarborBoat.point(8,0).x)<absf(HarborBoat.point(0,0).x),"The prow rises and tightens beyond the wider squared stern")

 var scenery=Scenery.new()
 scenery.batching_enabled=false
 var game=Rules.new();game.chapter=5
 var before=game.rng.state
 var map=Node3D.new();root.add_child(map)
 scenery.landscape(map,game)
 var map_hulls=map.find_children("HarborHull*","MeshInstance3D",true,false)
 assert(map_hulls.size()==2)
 for piece in map_hulls:
  var cell=Vector2i(roundi(piece.position.x),roundi(piece.position.z))
  assert(game.terrain(cell)=="~")
  verify_mooring(piece,-.07)
  var context=scenery.combat_context(game,{"x":cell.x-1,"y":cell.y},{"x":cell.x,"y":cell.y})
  var arena=Node3D.new();root.add_child(arena)
  scenery.battle_landscape(arena,Vector3(35,0,0),context)
  var boats=arena.find_children("HarborHull*","MeshInstance3D",true,false)
  assert(boats.size()==context.landmarks.filter(func(item):return item.kind=="boat").size() and not boats.is_empty())
  for boat in boats:verify_mooring(boat,arena.get_node("ArenaWater").global_position.y)
  arena.free()
 assert(game.rng.state==before,"Harbor scenery leaves campaign rolls intact")
 map.free()
 await process_frame
 print("PASS: closed 140-triangle timber hull, fitted sail, and four deck-anchored stays on every map and arena boat")

func verify_mooring(piece: MeshInstance3D,water_level: float):
 var wood=piece.material_override as StandardMaterial3D
 assert(piece.mesh==HarborBoat.hull() and wood!=null and wood.vertex_color_use_as_albedo)
 var bounds=piece.global_transform*piece.mesh.get_aabb()
 assert(bounds.position.y<water_level and bounds.end.y>water_level,"The hull crosses the actual water plane")
 var sail: Cloth
 var mast: MeshInstance3D
 var yard: MeshInstance3D
 for node in piece.get_parent().get_children():
  if not node is Node3D:continue
  if node is Cloth and not node.standard and (node.position-piece.position).is_equal_approx(Vector3(0,1.5,0)):sail=node
  if node.name.begins_with("BoatMast") and (node.position-piece.position).is_equal_approx(Vector3(0,1.18,0)):mast=node
  if node.name.begins_with("BoatYardarm") and (node.position-piece.position).is_equal_approx(Vector3(.62,2.2,0)):yard=node
 assert(sail!=null and mast!=null and yard!=null,"Every hull retains its mast, sail and yardarm")
 var mast_mesh=mast.mesh as CylinderMesh
 var yard_mesh=yard.mesh as CylinderMesh
 assert(mast.position.y-mast_mesh.height*.5<piece.position.y+.195,"The mast meets the deck")
 assert(is_equal_approx(yard.position.y,sail.position.y+sail.dimensions.y*.5),"The sail's upper edge meets the yardarm")
 var span=yard.basis.y*yard_mesh.height*.5
 assert(yard.position.x-span.x<sail.position.x and yard.position.x+span.x>sail.position.x+sail.dimensions.x)
 var ropes=piece.get_parent().get_children().filter(func(node):
  return node is MeshInstance3D and str(node.name).begins_with("BoatStay")
 )
 var ties=piece.get_parent().get_children().filter(func(node):
  return node is MeshInstance3D and str(node.name).begins_with("BoatCleat")
 )
 assert(HarborBoat.RIGGING.size()==4)
 assert(ropes.all(func(rope):return rope.mesh==ropes[0].mesh),"Every stay uses the same cylindrical mesh")
 for line in HarborBoat.RIGGING:
  var top=piece.position+line[0];var anchor=piece.position+line[1]
  var attached=ropes.filter(func(rope):return rope.position.is_equal_approx((top+anchor)*.5))
  var fixed=ties.filter(func(block):return block.position.is_equal_approx(anchor-Vector3.UP*.04))
  assert(attached.size()==1 and fixed.size()==1,"One stay joins each deck cleat to the mast")
  var rope=attached[0]
  var half=rope.transform.basis.y*rope.mesh.height*.5
  assert((rope.position+half).distance_to(top)<.00002 and (rope.position-half).distance_to(anchor)<.00002)
  var cleat=fixed[0].transform*fixed[0].mesh.get_aabb()
  var deck_y=piece.position.y+mesh_top(piece.mesh,Vector2(line[1].x,line[1].z))
  assert(cleat.position.y<deck_y and cleat.end.y>deck_y and cleat.has_point(anchor),"The cleat meets the actual curved deck")
  var mast_height=top.y-(mast.position.y-mast_mesh.height*.5)
  var mast_radius=lerpf(mast_mesh.bottom_radius,mast_mesh.top_radius,mast_height/mast_mesh.height)
  assert(mast_height>0 and mast_height<mast_mesh.height and Vector2(line[0].x,line[0].z).length()<mast_radius)

func verify_harbor_quay():
 var scenery=Scenery.new();scenery.batching_enabled=false
 var game=Rules.new();game.chapter=5;var before=game.rng.state
 var field=Node3D.new();root.add_child(field);scenery.landscape(field,game)
 var map_rack=field.get_node("HarborNetRack")
 var map_net=map_rack.get_node("HangingNet")
 var map_gulls=field.get_node("AmbientDrift/HarborGulls")
 var map_breakwater=field.get_node("HarborBreakwater")
 var outer_wall=map_breakwater.global_transform*map_breakwater.mesh.get_aabb()
 assert(outer_wall.position.z>game.board_size().y+1.0 and outer_wall.position.y<-.12 and outer_wall.end.y>-.12)
 assert(map_breakwater.mesh==HarborBreakwater.shape())
 verify_harbor_breakwater(map_breakwater.mesh)
 var map_signal=field.get_node("HarborSignal")
 var map_frame=map_signal.get_node("SignalFrame")
 var map_lens=map_signal.get_node("SignalLens")
 var frame_points=map_frame.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 assert(map_frame.mesh==HarborSignal.frame_shape() and frame_points.size()<=720 and frame_points.size()%3==0)
 assert(map_lens.position==HarborSignal.LENS_CENTER and map_lens.material_override.emission_enabled)
 assert(map_lens.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
 var signal_bounds=map_frame.global_transform*map_frame.mesh.get_aabb()
 assert(signal_bounds.position.y<0 and signal_bounds.end.y>1.1 and signal_bounds.end.z<4.50)
 for x in [signal_bounds.position.x,signal_bounds.end.x]:
  assert(game.terrain(Vector2i(roundi(x),roundi(map_signal.position.z)))=="p","The signal stands on the paved quay")
 verify_harbor_net(map_rack,map_net)
 for footing in map_rack.find_children("NetRackFoot*","MeshInstance3D",false,false):
  var edge=footing.global_transform*footing.mesh.get_aabb()
  assert(edge.position.y<0 and edge.end.y>0 and edge.position.z>4.10 and edge.end.z<4.5)
  var point=footing.global_position
  assert(game.terrain(Vector2i(roundi(point.x),roundi(point.z)))=="p")
 var near_a={"x":5,"y":4};var near_b={"x":6,"y":4}
 var near=scenery.combat_context(game,near_a,near_b)
 var mirror=scenery.combat_context(game,near_a,near_b,-1)
 var inland=scenery.combat_context(game,{"x":8,"y":1},{"x":9,"y":1})
 var pier=scenery.combat_context(game,{"x":4,"y":7},{"x":4,"y":8})
 assert(near.harbor_quay and mirror.harbor_quay and near.terrain=="p")
 assert(inland.terrain=="p" and not inland.harbor_quay and inland.landmarks.all(func(item):return item.kind!="boat"))
 assert(pier.terrain=="=" and not pier.harbor_quay)
 var center=Vector3(35,.4,2)
 var viewport=SubViewport.new();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var camera=Camera3D.new();viewport.add_child(camera);camera.current=true
 var dimensions_to_check=[Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]
 var anchor=Vector3(6.5,0,4.5)
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=16
 camera.position=anchor+Vector3(2.5,22,11.5);camera.look_at(anchor);camera.h_offset=2
 for dimensions in dimensions_to_check:
  viewport.size=dimensions;await process_frame
  var map_line=map_rack.to_global(Vector3(0,1.10,.08))
  assert(Rect2(Vector2.ZERO,Vector2(dimensions)).grow(-12).has_point(camera.unproject_position(map_line)))
  assert(Rect2(Vector2.ZERO,Vector2(dimensions)).grow(-12).has_point(camera.unproject_position(map_lens.global_position)))
 camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.h_offset=0
 for context in [near,mirror,inland,pier]:
  var arena=Node3D.new();root.add_child(arena);scenery.battle_landscape(arena,center,context)
  var rack=arena.get_node_or_null("HarborNetRack")
  assert((rack!=null)==context.harbor_quay,"Only shore fights carry the rack into the arena")
  var beacon=arena.get_node_or_null("HarborSignal")
  assert((beacon!=null)==context.harbor_quay,"The quay signal is visible in shore fights")
  var harbor_wall=arena.get_node_or_null("HarborBreakwater")
  var water=arena.get_node_or_null("ArenaWater")
  var deck=arena.get_node_or_null("ArenaDeck")
  var floor=arena.get_node_or_null("ArenaGround")
  assert((harbor_wall!=null)==(water!=null),"The outer harbor is visible from the quay and piers")
  var gulls=arena.get_node_or_null("AmbientDrift/HarborGulls")
  assert((gulls!=null)==(water!=null),"The gulls stay over water in waterfront fights")
  if gulls!=null:assert(gulls.multimesh.mesh==map_gulls.multimesh.mesh)
  if harbor_wall!=null:
   assert(harbor_wall.mesh==map_breakwater.mesh and harbor_wall.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
   assert(is_equal_approx(harbor_wall.position.y,water.position.y))
   assert((harbor_wall.transform*harbor_wall.mesh.get_aabb()).end.z<center.z-16)
  if context==inland:
   assert(water==null and deck==null and floor.mesh.size==Vector2(70,70))
   assert(is_equal_approx(floor.position.y,center.y) and floor.material_override.get_shader_parameter("blend_edges"))
  elif context==pier:
   assert(deck!=null and water!=null and is_equal_approx(water.position.y,center.y-.055))
   assert(arena.find_children("HarborHull*","MeshInstance3D",true,false).size()>0)
  else:
   assert(deck==null and water!=null and arena.get_meta("arena_surface")==1)
   assert(floor.material_override==scenery.ground_material(1) and is_equal_approx(floor.position.y,center.y))
   var land=floor.transform*floor.mesh.get_aabb()
   var sea=water.transform*water.mesh.get_aabb()
   var wall=arena.get_node("QuayWall")
   var coping=arena.get_node("QuayCoping")
   var face=wall.transform*wall.mesh.get_aabb()
   var rim=coping.transform*coping.mesh.get_aabb()
   assert(is_equal_approx(land.position.z,sea.end.z),"Paving and sea meet at the quay")
   assert(face.intersects(rim) and face.position.y<sea.position.y and face.end.y>sea.position.y)
   var frame=beacon.get_node("SignalFrame")
   var lens=beacon.get_node("SignalLens")
   var signal_footing=frame.global_transform*frame.mesh.get_aabb()
   assert(frame.mesh==map_frame.mesh and lens.mesh==map_lens.mesh and lens.material_override==map_lens.material_override)
   assert(signal_footing.position.y<center.y and signal_footing.position.z>rim.end.z,"The signal’s support is embedded in the land behind the coping")
   var net=rack.get_node("HangingNet")
   assert(net.mesh==map_net.mesh and net.material_override==map_net.material_override)
   for footing in rack.find_children("NetRackFoot*","MeshInstance3D",false,false):
    var edge=footing.global_transform*footing.mesh.get_aabb()
    assert(edge.position.y<center.y and edge.end.y>center.y and edge.position.z>rim.end.z)
   var bollards=arena.find_children("QuayBollard*","MeshInstance3D",false,false)
   assert(bollards.size()==10)
   for index in range(0,bollards.size(),2):
    var post=bollards[index].transform*bollards[index].mesh.get_aabb()
    var cap=bollards[index+1].transform*bollards[index+1].mesh.get_aabb()
    assert(post.intersects(rim) and post.intersects(cap),"Every bollard sits in the coping and carries an attached cap")
   var warehouse=arena.find_children("House","Node3D",true,false)[0].get_node("PlasterWall")
   var foundation=warehouse.global_transform*warehouse.mesh.get_aabb()
   assert(foundation.position.z>rim.end.z and is_equal_approx(foundation.position.y,center.y),"The visible warehouse stands fully on the shore")
   assert(signf(warehouse.global_position.x-center.x)==(1.0 if context==near else -1.0))
   var boats=arena.find_children("HarborHull*","MeshInstance3D",true,false)
   assert(not boats.is_empty())
   for boat in boats:
    assert((boat.global_transform*boat.mesh.get_aabb()).end.z<sea.end.z)
    verify_mooring(boat,water.position.y)
   for mounted in [false,true]:
    var shot=CombatCamera.frame_pair(center+Vector3.LEFT*1.6,center+Vector3.RIGHT*1.6,"wide",false,mounted)
    camera.position=shot.anchor;camera.fov=shot.lens;camera.look_at(shot.focus)
    for dimensions in dimensions_to_check:
     viewport.size=dimensions;await process_frame
     var safe=Rect2(Vector2(20,20),Vector2(dimensions)-Vector2(40,174))
     var wet=center+Vector3(0,Scenery.HARBOR_QUAY_LEVEL,-8)
     assert(safe.has_point(camera.unproject_position(wet)) and rim.intersects_segment(camera.global_position,wet)==null,"The wide shot sees water above the coping")
     assert(bollards.any(func(post):return safe.has_point(camera.unproject_position(post.global_position))))
     assert(safe.has_point(camera.unproject_position(rack.to_global(Vector3(0,1.10,.13)))),
      "The rack and suspended ropes remain in the frame above the health plates")
     assert(safe.has_point(camera.unproject_position(lens.global_position)),"The signal lens is in frame above the health plates")
     for head in [Vector3(-4,.64,1.2),Vector3(4,.64,1.8)]:
      assert(safe.has_point(camera.unproject_position(harbor_wall.to_global(head))),"The two breakwater heads leave a visible passage")
  arena.free()
 viewport.free();field.free()
 assert(game.rng.state==before)
 print("PASS: Glass Harbor separates inland ground, a planted stone quay and timber piers, with twelve waterfront projections")
 print("PASS: Glass Harbor’s shared 316-triangle net, attached floats, grounded rack and fifteen map and arena projections")
 print("PASS: Glass Harbor’s signal shares %d frame triangles and a warm insert across fifteen shoreline projections"%(frame_points.size()/3))

func verify_harbor_breakwater(shape: ArrayMesh):
 var attributes=shape.surface_get_arrays(0)
 var points=attributes[Mesh.ARRAY_VERTEX];var normals=attributes[Mesh.ARRAY_NORMAL]
 var edges={};var volume=0.0
 assert(points.size()/3==352)
 for index in range(0,points.size(),3):
  var a=points[index];var b=points[index+1];var c=points[index+2]
  var cross=(b-a).cross(c-a)
  assert(cross.length_squared()>1e-9 and cross.normalized().dot(normals[index])<-.999)
  volume-=a.dot(b.cross(c))/6.0
  for point in [a,b,c]:assert(absf(point.x)>3.5,"Both stone arms stop short of the open approach")
  for pair in [[a,b],[b,c],[c,a]]:
   var first=str(pair[0]);var second=str(pair[1])
   var key=first+"/"+second if first<second else second+"/"+first
   edges[key]=edges.get(key,0)+1
 assert(volume>30 and edges.values().all(func(count):return count==2),"Both arms form closed shore silhouettes")
 print("PASS: one 352-triangle breakwater, closed stone arms and an open entrance in the harbor water")

func verify_harbor_net(rack: Node3D,net: MeshInstance3D):
 var shape=HarborNet.shape()
 assert(net.mesh==shape and net.material_override.cull_mode==BaseMaterial3D.CULL_DISABLED)
 var arrays=shape.surface_get_arrays(0)
 var points=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL]
 assert(points.size()==948)
 for i in range(0,points.size(),3):
  var cross=(points[i+1]-points[i]).cross(points[i+2]-points[i])
  assert(cross.length()>.0001 and cross.normalized().dot(normals[i])<-.999)
 var hole=HarborNet.site_at(.025,.5/HarborNet.ROWS)
 var thread=HarborNet.site_at(0,0).lerp(HarborNet.site_at(.1,1.0/HarborNet.ROWS),.5)
 assert(barrel_hit(shape,hole+Vector3.BACK,Vector3.FORWARD)==null)
 assert(barrel_hit(shape,thread+Vector3.BACK,Vector3.FORWARD)!=null)
 var floats=rack.find_children("CorkFloat*","MeshInstance3D",false,false)
 assert(floats.size()==4)
 var knots=[1,3,6,8]
 for index in floats.size():
  var cord=HarborNet.site_at(float(knots[index])/HarborNet.COLUMNS,1.0/HarborNet.ROWS)
  var float_knot=floats[index].transform.affine_inverse()*cord
  assert(absf(float_knot.y)<.0375 and Vector2(float_knot.x,float_knot.z).length()<.029,
   "Every float seats on a woven junction")

func verify_towers():
 var masonry=preload("res://scripts/fortification.gd")
 var shape=masonry.tower();assert(shape==masonry.tower(),"Repeated towers share the same stone mesh")
 var data=shape.surface_get_arrays(0);var points=data[Mesh.ARRAY_VERTEX];var normals=data[Mesh.ARRAY_NORMAL]
 assert(points.size()/3<=2200 and shape.get_aabb().size.x<=1.401 and shape.get_aabb().end.y<=2.541,"Tower detail keeps the blocked footprint and a bounded triangle budget")
 assert(masonry.material().vertex_color_use_as_albedo and masonry.material().vertex_color_is_srgb)
 for index in range(0,points.size(),3):
  var cross=(points[index+1]-points[index]).cross(points[index+2]-points[index])
  assert(cross.length_squared()>1e-12 and cross.normalized().dot(normals[index])<-.999,"Every masonry face has nondegenerate clockwise winding and correct outward lighting")
 for sample in [[Vector2(.58,0),2.54],[Vector2(cos(PI/8+.04),sin(PI/8+.04))*.58,2.20],[Vector2(.2,.1),2.12]]:
  var highest=-INF
  for index in range(0,points.size(),3):
   var hit=Geometry3D.ray_intersects_triangle(Vector3(sample[0].x,4,sample[0].y),Vector3.DOWN,points[index],points[index+1],points[index+2])
   if hit!=null:highest=maxf(highest,hit.y)
  assert(absf(highest-sample[1])<.001,"Actual tower rays distinguish raised battlements, open gaps and the inset roof deck")
 var game=Rules.new();var scenery=Scenery.new();scenery.batching_enabled=false;var count=0
 for chapter in range(12):
  game.chapter=chapter
  for item in game.info().landmarks:
   if item.kind!="tower":continue
   var world=Node3D.new();root.add_child(world)
   var point=Vector3(item.position[0],0,item.position[1]);scenery.landmark(world,point,item.kind)
   var tower=world.get_node("FortifiedTower")
   assert(tower.mesh==shape and tower.position==point and tower.material_override==masonry.material(),"Authored towers use the shared detailed mesh at their existing positions")
   var context=scenery.combat_context(game,{"x":int(point.x)-1,"y":int(point.z)},{"x":int(point.x),"y":int(point.z)})
   var arena=Node3D.new();root.add_child(arena);scenery.battle_landscape(arena,Vector3(35,0,0),context)
   var visible=arena.find_children("FortifiedTower","MeshInstance3D",true,false)
   assert(visible.size()==context.landmarks.filter(func(value):return value.kind=="tower").size(),"Nearby combat scenery keeps the same fortified identity")
   for node in visible:assert(node.mesh==shape)
   world.queue_free();arena.queue_free();await process_frame;count+=1
 assert(count==6,"Every authored castle tower is covered")

func mesh_top(shape: ArrayMesh,point: Vector2) -> float:
 var vertices=shape.surface_get_arrays(0)[Mesh.ARRAY_VERTEX];var highest=-INF
 for i in range(0,vertices.size(),3):
  var hit=Geometry3D.ray_intersects_triangle(Vector3(point.x,3,point.y),Vector3.DOWN,vertices[i],vertices[i+1],vertices[i+2])
  if hit!=null:highest=maxf(highest,hit.y)
 return highest

func verify_fountain():
 var fountain=preload("res://scripts/fountain.gd")
 var stone=fountain.stone();var pools=fountain.pools();var streams=fountain.flows()
 assert(stone==fountain.stone() and pools==fountain.pools() and streams==fountain.flows(),"Repeated town/combat fountains share their immutable meshes")
 var triangles=0
 for shape in [stone,pools,streams]:
  var arrays=shape.surface_get_arrays(0);var vertices=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL];triangles+=vertices.size()/3
  for i in range(0,vertices.size(),3):
   var cross=(vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i])
   assert(cross.length_squared()>1e-12 and cross.normalized().dot(normals[i])<-.9999,"Basin and water faces have nondegenerate geometry and matching clockwise normals")
  for point in vertices:assert(Vector2(point.x,point.z).length()<.5 and point.y>=0 and point.y<.8,"All fountain detail remains inside its existing occupied tile")
 var tangents=pools.surface_get_arrays(0)[Mesh.ARRAY_TANGENT]
 assert(tangents!=null and tangents.size()==pools.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()*4,"Water ripples have a real tangent frame")
 for index in range(0,tangents.size(),4):assert(absf(tangents[index])>.999 and absf(tangents[index+1])+absf(tangents[index+2])<.001,"Pool UVs orient the water normal map consistently")
 assert(triangles<1200,"Small landmark stays within its fixed geometry budget")
 for point in [Vector2(.28,.01),Vector2(.14,.01)]:
  assert(mesh_top(pools,point)>mesh_top(stone,point)+.01,"Actual water disks sit above each basin floor")
 assert(mesh_top(stone,Vector2(.4,.01))>.24 and mesh_top(stone,Vector2(.22,.01))>.76,"Both basin rims remain above their water surface")
 for jet in range(4):
  var top=fountain.jet_point(0,jet*PI*.5);var bottom=fountain.jet_point(1,jet*PI*.5)
  assert(top.y>.70 and absf(bottom.y-.18)<.001 and Vector2(bottom.x,bottom.z).length()<.335,"Each narrow jet lands just above the lower pool")
 assert("fog_disabled" in fountain.stream_material().shader.code and not "depth_test_disabled" in fountain.stream_material().shader.code,"Transparent jets retain depth testing without painting fog on faded edges")
 var game=Rules.new();var scenery=Scenery.new();scenery.batching_enabled=false
 var item=game.info().landmarks.filter(func(value):return value.kind=="fountain")[0]
 var world=Node3D.new();root.add_child(world);var point=Vector3(item.position[0],0,item.position[1]);scenery.landmark(world,point,"fountain")
 var node=world.get_node("TieredFountain")
 assert(node.get_child_count()==3 and node.get_node("CarvedStone").mesh==stone and node.get_node("BasinWater").mesh==pools,"Actual town landmark uses stone, water and falling-stream meshes")
 var context=scenery.combat_context(game,{"x":int(point.x)-1,"y":int(point.z)},{"x":int(point.x),"y":int(point.z)})
 var arena=Node3D.new();root.add_child(arena);scenery.battle_landscape(arena,Vector3(35,0,0),context)
 var backdrop=arena.find_child("TieredFountain",true,false)
 assert(backdrop!=null and backdrop.get_node("CarvedStone").mesh==stone,"Nearby combat preserves the town fountain identity")
 world.queue_free();arena.queue_free();await process_frame

func verify_gate():
 var masonry=preload("res://scripts/fortification.gd")
 var shape=masonry.gate_wall();assert(shape==masonry.gate_wall())
 var arrays=shape.surface_get_arrays(0);var points=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL]
 assert(points.size()/3<=240,"Gatehouse masonry has a small fixed geometry budget")
 for i in range(0,points.size(),3):
  var cross=(points[i+1]-points[i]).cross(points[i+2]-points[i])
  assert(cross.length_squared()>1e-12 and cross.normalized().dot(normals[i])<-.999,"Gate masonry uses closed, outward-lit clockwise faces")
 for sample in [[Vector2(0,1),false],[Vector2(0,4.2),true],[Vector2(1,2.8),false],[Vector2(1,3.1),true],[Vector2(1.8,1),true]]:
  var blocked=false
  for i in range(0,points.size(),3):
   if Geometry3D.ray_intersects_triangle(Vector3(sample[0].x,sample[0].y,2),Vector3.FORWARD,points[i],points[i+1],points[i+2])!=null:blocked=true
  assert(blocked==sample[1],"Actual masonry leaves an arched passage below its header and between its piers")
 var scenery=Scenery.new();scenery.batching_enabled=false
 var arena=Node3D.new();root.add_child(arena)
 scenery.battle_landscape(arena,Vector3(35,0,0),{"environment":"castle"})
 var gates=arena.find_children("CastleGate","Node3D",true,false)
 assert(gates.size()==1 and gates[0].position==Vector3(35,0,-9),"Castle combat replaces the old flat wall at the same background depth")
 var gate=gates[0];assert(gate.get_node("GateMasonry").mesh==shape)
 var bars=gate.get_children().filter(func(node):return str(node.name).begins_with("PortcullisBar"))
 assert(bars.size()==11,"The gate contains a recessed open iron grille")
 for bar in bars:
  var top=(bar.transform*bar.get_aabb()).end.y
  assert(bar.position.z<0 and top<2+sqrt(1.96-bar.position.x*bar.position.x),"Portcullis bars fit below the curved stone opening")
 var supports=gate.get_children().filter(func(node):return str(node.name).begins_with("Buttress"))
 assert(supports.size()==6)
 for support in supports:assert(absf(support.position.x)>=4 and support.position.z<1,"Castle supports engage the side walls and keep the gate approach clear")
 var bounds=AABB();var first=true
 for node in gate.get_children():
  if node is MeshInstance3D:
   var box=node.transform*node.get_aabb()
   bounds=box if first else bounds.merge(box);first=false
 assert(bounds.position.x>=-17.501 and bounds.end.x<=17.501 and bounds.end.y<=5.101,"Detailed castle wall keeps its fixed battlefield backdrop footprint")
 await verify_gate_standards(gate)
 arena.queue_free();await process_frame
 await verify_crown_passage(scenery,masonry)

func verify_crown_passage(scenery,masonry):
 var game=Rules.new();game.chapter=10
 var field=Node3D.new();root.add_child(field);scenery.landscape(field,game)
 var gate=field.get_node("CastleGate")
 assert(gate.position==masonry.MAP_GATE_SITE and gate.get_node("GateMasonry").mesh==masonry.gate_wall())
 for row in [4,5]:
  assert(game.terrain(Vector2i(8,row))=="p")
  for height in [.15,.60,1.2]:
   assert(not gate_obstructs(gate,Vector3(6.7,height,row),Vector3(9.2,height,row)),"Both walkable lanes fit through the stone and raised grille")
 assert(gate_obstructs(gate,Vector3(6.7,.9,3.20),Vector3(9.2,.9,3.20)),"Masonry frames the two routes through the gate")
 var near=scenery.combat_context(game,{"x":7,"y":4},{"x":8,"y":4})
 var distant=scenery.combat_context(game,{"x":2,"y":4},{"x":3,"y":4})
 assert(near.raised_gate and not distant.raised_gate)
 var stage=Node3D.new();root.add_child(stage);scenery.battle_landscape(stage,Vector3(35,0,0),near)
 var other=stage.get_node("CastleGate")
 assert(other.get_node("GateMasonry").mesh==gate.get_node("GateMasonry").mesh)
 for entry in [gate,other]:
  var bars=entry.find_children("PortcullisBar*","MeshInstance3D",false,false)
  assert(bars.size()==11 and bars.all(func(bar):return (bar.transform*bar.mesh.get_aabb()).position.y>=3.199))
 for side in ["WindStandardLeft","WindStandardRight"]:
  var local=gate.get_node(side);var staged=other.get_node(side)
  assert(local.cloth.mesh==staged.cloth.mesh and local.material!=staged.material)
  local.seek_phase(1.3 if side.ends_with("Left") else 5.9)
 scenery.transfer_environment_motion(field,stage,"castle")
 assert(is_equal_approx(other.get_node("WindStandardLeft").phase,1.3) and is_equal_approx(other.get_node("WindStandardRight").phase,5.9))
 other.get_node("WindStandardLeft").seek_phase(3.1);other.get_node("WindStandardRight").seek_phase(6.2)
 scenery.transfer_environment_motion(stage,field,"castle")
 assert(is_equal_approx(gate.get_node("WindStandardLeft").phase,3.1) and is_equal_approx(gate.get_node("WindStandardRight").phase,6.2))
 var viewport=SubViewport.new();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var camera=Camera3D.new();viewport.add_child(camera);camera.current=true
 var center=Vector3(6.5,0,4.5)
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=16
 camera.position=center+Vector3(2.5,22,11.5);camera.look_at(center)
 for pixels in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
  viewport.size=pixels;await process_frame
  var banner=gate.get_node("WindStandardLeft")
  var point=banner.to_global(Vector3(.60,0,0))
  assert(Rect2(Vector2.ZERO,Vector2(pixels)).grow(-10).has_point(camera.unproject_position(point)))
  assert(not gate_obstructs(gate,camera.global_position,point))
 field.queue_free();stage.queue_free();viewport.queue_free();await process_frame
 print("PASS: Crown Approach’s shared passage fits both tactical lanes, preserves separately moving standards and remains visible in three tactical projections")

func gate_obstructs(gate: Node3D,start: Vector3,finish: Vector3) -> bool:
 for child in gate.get_children():
  if not child is MeshInstance3D:continue
  var from=child.to_local(start);var to=child.to_local(finish)
  if child.mesh.get_aabb().intersects_segment(from,to)==null:continue
  var surface=child.mesh.surface_get_arrays(0)
  var vertices=surface[Mesh.ARRAY_VERTEX];var indices=surface[Mesh.ARRAY_INDEX]
  var order=indices if indices!=null and not indices.is_empty() else range(vertices.size())
  for index in range(0,order.size(),3):
   if Geometry3D.segment_intersects_triangle(from,to,vertices[order[index]],vertices[order[index+1]],vertices[order[index+2]])!=null:return true
 return false

func verify_gate_standards(gate: Node3D):
 var banners=gate.get_children().filter(func(node):return node is Cloth)
 var rails=gate.find_children("StandardRail*","MeshInstance3D",false,false)
 var brackets=gate.find_children("StandardBracket*","MeshInstance3D",false,false)
 assert(banners.size()==2 and rails.size()==2 and brackets.size()==4)
 assert(banners[0].cloth.mesh==banners[1].cloth.mesh,"Castle standards share their matching geometry")
 assert(banners[0].material!=banners[1].material and not is_equal_approx(banners[0].phase,banners[1].phase))
 for index in banners.size():
  var banner=banners[index]
  var rail=rails[index]
  var support=rail.transform*rail.mesh.get_aabb()
  assert(banner.standard and banner.material.get_shader_parameter("emblem"))
  assert(banner.dimensions==Vector2(2.12,.95))
  for mount in [brackets[index*2],brackets[index*2+1]]:
   var contact=mount.transform*mount.mesh.get_aabb()
   assert(contact.intersects(support) and contact.position.z<=.351,"The rail brackets start at the wall and reach the rail")
  var volume=banner.transform*banner.cloth.custom_aabb
  assert(volume.position.z>.4 and (volume.position.x>2.2 or volume.end.x<-2.2),"Cloth waves stay clear of stone and the gate opening")
  var surface=banner.cloth.mesh.surface_get_arrays(0)
  var points=surface[Mesh.ARRAY_VERTEX];var uv=surface[Mesh.ARRAY_TEX_UV]
  for vertex in points.size():
   if is_zero_approx(uv[vertex].x):
    var pin=banner.transform*points[vertex]
    assert(is_equal_approx(pin.y,rail.position.y) and support.grow(.001).has_point(pin),"The pinned upper edge sits on the rail")
 var viewport=SubViewport.new();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var camera=Camera3D.new();viewport.add_child(camera);camera.current=true
 var center=Vector3(35,0,0)
 for mounted in [false,true]:
  var frame=CombatCamera.frame_pair(center+Vector3.LEFT*1.6,center+Vector3.RIGHT*1.6,"wide",false,mounted)
  camera.position=frame.anchor;camera.fov=frame.lens;camera.look_at(frame.focus)
  for dimensions in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
   viewport.size=dimensions;await process_frame
   var safe=Rect2(Vector2(20,20),Vector2(dimensions)-Vector2(40,172))
   var in_frame=banners.any(func(banner):
    return [Vector3.ZERO,Vector3.RIGHT*1.42].all(func(point):
     var position=banner.to_global(point)
     return not camera.is_position_behind(position) and safe.has_point(camera.unproject_position(position))))
   assert(in_frame,"A banner hangs in view above the HUD in the wide shot")
 var phases=banners.map(func(node):return node.phase)
 gate.hide();await create_timer(.06).timeout
 assert(phases==banners.map(func(node):return node.phase),"Hidden arena banners suspend their cloth phases")
 gate.show();await create_timer(.06).timeout
 assert(phases!=banners.map(func(node):return node.phase))
 viewport.queue_free();await process_frame
 print("PASS: two Crown Approach standards with attached upper edges, private cloth phases, wall and opening clearance, and six wide-shot projections")

func wheel_hit(shape: Mesh,point: Vector2) -> bool:
 var points=shape.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 for i in range(0,points.size(),3):
  if Geometry3D.ray_intersects_triangle(Vector3(point.x,-1,point.y),Vector3.UP,points[i],points[i+1],points[i+2])!=null:return true
 return false

func verify_cart():
 var wheel=preload("res://scripts/cart_wheel.gd");var shape=wheel.mesh()
 assert(shape==wheel.mesh() and wheel.material()==wheel.material(),"Road carts share wheel geometry and material")
 var arrays=shape.surface_get_arrays(0);var points=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL]
 assert(points.size()==696,"Six spokes, wooden rim and iron tire use 232 triangles")
 for i in range(0,points.size(),3):
  var normal=(points[i+1]-points[i]).cross(points[i+2]-points[i])
  assert(normal.length()>.000001 and normal.normalized().dot(normals[i])<-.999,"All wheel faces have matching outward normals and clockwise winding")
 for i in range(6):
  var spoke=Vector2.from_angle(i*TAU/6);var gap=Vector2.from_angle((i+.5)*TAU/6)
  assert(wheel_hit(shape,spoke*.13) and wheel_hit(shape,gap*.22),"Actual rays hit every spoke and the surrounding rim")
  assert(not wheel_hit(shape,gap*.13),"Every spoke gap is physically open rather than painted on a solid disc")
 var scenery=Scenery.new();var world=Node3D.new();root.add_child(world)
 world.position=Vector3(35,.2,3);world.rotation.y=.4;world.scale=Vector3.ONE*1.7
 scenery.cart(world,Vector3.ZERO)
 var cart=world.get_node("RoadCart")
 var wheels=cart.get_children().filter(func(node):return str(node.name).begins_with("SpokedWheel"))
 var axles=cart.get_children().filter(func(node):return str(node.name).begins_with("WheelAxle"))
 var bearings=cart.get_children().filter(func(node):return str(node.name).begins_with("AxleBearing"))
 assert(wheels.size()==4 and axles.size()==2 and bearings.size()==4,"All four wheels share two supported axles")
 for node in wheels:
  var lowest=INF
  for vertex in node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:lowest=minf(lowest,node.to_global(vertex).y)
  assert(absf(lowest-world.global_position.y)<.00001,"Iron tire touches the cart's ground plane under a rotated/scaled parent")
  var axle=axles.filter(func(part):return is_equal_approx(part.position.z,node.position.z))[0]
  assert(is_equal_approx(axle.position.y,node.position.y) and axle.scale.x*.5>absf(node.position.x),"Axle crosses the wheel centers and reaches their hubs")
 for bearing in bearings:
  assert(bearing.position.y-bearing.scale.y*.5<.251 and bearing.position.y+bearing.scale.y*.5>.35,"Bearings join the axle to the underside of the bed")
 world.queue_free();await process_frame

func barrel_hit(shape: Mesh,position: Vector3,direction: Vector3) -> Variant:
 var points=shape.surface_get_arrays(0)[Mesh.ARRAY_VERTEX];var closest=null;var distance=INF
 for i in range(0,points.size(),3):
  var hit=Geometry3D.ray_intersects_triangle(position,direction,points[i],points[i+1],points[i+2])
  if hit!=null and position.distance_squared_to(hit)<distance:closest=hit;distance=position.distance_squared_to(hit)
 return closest

func verify_barrels():
 var barrel=preload("res://scripts/barrel_visuals.gd");var total=0
 for part in ["wood","hoops","lid_marks"]:
  var shape=barrel.mesh(part);assert(shape==barrel.mesh(part),"Repeated barrels share immutable source geometry")
  var arrays=shape.surface_get_arrays(0);var points=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL];var edges={}
  total+=points.size()/3
  for i in range(0,points.size(),3):
   var cross=(points[i+1]-points[i]).cross(points[i+2]-points[i])
   assert(cross.length()>.000001 and cross.normalized().dot(normals[i])<-.98,"Barrel faces remain nondegenerate with outward normals and clockwise winding")
   for j in range(3):
    var point=points[i+j]
    assert(point.y>=0 and point.y<=.40001 and Vector2(point.x,point.z).length()<=.16801,"New barrel stays inside the former body/hoop footprint")
    var a=str(point.snapped(Vector3.ONE*.000001));var b=str(points[i+(j+1)%3].snapped(Vector3.ONE*.000001))
    var edge=a+":"+b if a<b else b+":"+a;edges[edge]=edges.get(edge,0)+1
  if part=="wood":
   for count in edges.values():assert(count==2,"Bowed wooden shell, lip, recessed lid and bottom form one closed solid")
 assert(total==222,"Three barrel parts share a fixed 222-triangle budget")
 var body=barrel.mesh("wood")
 var lid=barrel_hit(body,Vector3(0,1,0),Vector3.DOWN);var lip=barrel_hit(body,Vector3(.138,1,0),Vector3.DOWN)
 assert(lid!=null and lip!=null and absf(lid.y-.392)<.00001 and absf(lip.y-.4)<.00001,"Actual rays find a recessed lid below the surrounding wooden lip")
 var middle=barrel_hit(body,Vector3(1,.2,0),Vector3.LEFT);var end=barrel_hit(body,Vector3(1,.03,0),Vector3.LEFT)
 assert(middle!=null and end!=null and middle.x>end.x+.015,"Actual side profile bows outward through the middle")
 for y in [.06,.34]:
  var wood=barrel_hit(body,Vector3(1,y,0),Vector3.LEFT);var hoop=barrel_hit(barrel.mesh("hoops"),Vector3(1,y,0),Vector3.LEFT)
  assert(wood!=null and hoop!=null and hoop.x-wood.x>.002 and hoop.x-wood.x<.003,"Both iron hoops sit just outside the curved wood")
 var scenery=Scenery.new();var world=Node3D.new();root.add_child(world);scenery.barrel(world,Vector3(3,.4,2),.75)
 var prop=world.get_node("Barrel")
 assert(prop.position==Vector3(3,.4,2) and prop.scale==Vector3.ONE*.75 and prop.get_child_count()==3,"Warehouse and cart callers retain their existing placements with three material pieces")
 world.queue_free();await process_frame
