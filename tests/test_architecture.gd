extends SceneTree
const Cloth=preload("res://scripts/wind_cloth.gd")
const Roof=preload("res://scripts/architecture.gd")
const Scenery=preload("res://scripts/scenery.gd")
const Rules=preload("res://scripts/rules.gd")
const HarborBoat=preload("res://scripts/harbor_boat.gd")
const CombatCamera=preload("res://scripts/combat_camera.gd")
func _initialize():call_deferred("run")
func run():
 await verify_gate()
 await verify_towers()
 await verify_fountain()
 await verify_harbor_boats()
 await verify_reddeep_furnaces()
 await verify_aqueduct_gallery()
 await verify_abbey_arcade()
 await verify_ruined_columns()
 await verify_village_groves()
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
 print("PASS: arched castle gate/portcullis, tiered fountain basins/jets, six shared fortified towers, battlement/deck rays, three cached roofs, 204 gable intersections, ",cases," house identities, 14 pinned cloth resources, bounded motion parameters and cleanup")
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
 var context=scenery.combat_context(game,{"x":6,"y":8},{"x":6,"y":7})
 assert(context.environment=="abbey" and not context.landmarks.is_empty())
 var viewport=SubViewport.new();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var camera=Camera3D.new();viewport.add_child(camera);camera.current=true
 for terrain in ["p","="]:
  var center=Vector3(35,0 if terrain=="p" else .7,0)
  context.terrain=terrain
  var stage=Node3D.new();root.add_child(stage);scenery.battle_landscape(stage,center,context)
  var arcade=stage.get_node("AbbeyArcade")
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
 viewport.queue_free();await process_frame
 assert(game.save_data("camp")==snapshot)
 print("PASS: seven seated abbey piers, six open arches in shared stone, planted walk and six camera projections")

func verify_village_groves():
 var scenery=Scenery.new();scenery.batching_enabled=false
 var game=Rules.new();var rng=game.rng.state
 var center=Vector3(35,0,0)
 var near={"x":4,"y":0};var far={"x":4,"y":1}
 var normal=scenery.combat_context(game,near,far)
 var mirrored=scenery.combat_context(game,near,far,-1.0)
 assert(normal.environment=="village" and normal.landmarks.size()==2)
 var viewport=SubViewport.new();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var camera=Camera3D.new();viewport.add_child(camera);camera.current=true
 for context in [normal,mirrored,{"environment":"village","terrain":"p"}]:
  var stage=Node3D.new();root.add_child(stage);scenery.battle_landscape(stage,center,context)
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
  stage.queue_free();await process_frame
 viewport.queue_free();await process_frame
 assert(game.rng.state==rng)
 print("PASS: two village groves and distant orchard, clear mapped and fallback house frontage in 18 wide-shot projections")

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
 for terrain in ["p","="]:
  context.terrain=terrain
  var arena=Node3D.new();root.add_child(arena);scenery.battle_landscape(arena,center,context)
  var gallery=arena.get_node("AqueductGallery")
  var water=arena.get_node("ArenaWater")
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
  arena.queue_free();await process_frame
 viewport.queue_free();await process_frame
 print("PASS: six planted aqueduct spans, connected channel coping, dry and deck foregrounds, grounded map landmarks and six projected wide shots")

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
 assert(game.rng.state==rng_state)
 map.queue_free();arena.queue_free();fallback.queue_free();await process_frame
 print("PASS: two Reddeep map hearths, arched fireboxes, connected grates, open chimney flues and actual arena counterparts")

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
 for chapter in range(12):
  game.chapter=chapter;world=Node3D.new();root.add_child(world);scenery.landscape(world,game)
  var pieces=world.find_children("*","Node3D",true,false).filter(func(node):return node is Cloth)
  var expected_flags=0;var expected_sails=0
  for row in game.info().map:expected_flags+=row.count("o")
  for landmark in game.info().landmarks:
   if landmark.kind=="boat":
    expected_sails+=1
    var at=landmark.position;var context=scenery.combat_context(game,{"x":int(at[0])-1,"y":int(at[1])},{"x":int(at[0]),"y":int(at[1])})
    var arena=Node3D.new();root.add_child(arena);scenery.battle_landscape(arena,Vector3(35,0,0),context)
    var arena_sails=arena.find_children("*","Node3D",true,false).filter(func(node):return node is Cloth and not node.standard)
    assert(arena_sails.size()==context.landmarks.filter(func(item):return item.kind=="boat").size(),"Nearby boats keep their cloth sails in actual combat backdrops")
    arena.queue_free()
  assert(pieces.filter(func(piece):return piece.standard).size()==expected_flags and pieces.filter(func(piece):return not piece.standard).size()==expected_sails,"All objective standards and boat sails survive scene batching")
  flags+=expected_flags;sails+=expected_sails
  var references=pieces.map(func(piece):return weakref(piece));world.queue_free();await process_frame
  for reference in references:assert(reference.get_ref()==null,"Cloth resources release with their map")
 assert(flags==12 and sails==2 and game.rng.state==state,"All campaign cloth is bounded and independent of gameplay RNG")

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
 print("PASS: closed 140-triangle timber hull, raised prow, fitted yardarm, and both moored boats on the map and in combat")

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
 arena.queue_free();await process_frame

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
