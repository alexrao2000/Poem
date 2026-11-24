extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
# The readout shares profiles with simulation. Exercise actual cover, healing,
# hover/keyboard inspection, off-board hiding and cinematic visibility restore.
const Rules=preload("res://scripts/rules.gd")
const MapSurface=preload("res://scripts/map_surface.gd")
const MapOverlay=preload("res://scripts/map_overlay.gd")
const Scenery=preload("res://scripts/scenery.gd")
const RiverBank=preload("res://scripts/river_bank.gd")
const MapGround=preload("res://scripts/map_ground.gd")
const SanctuaryPlinth=preload("res://scripts/sanctuary_plinth.gd")
const PassEscarpment=preload("res://scripts/pass_escarpment.gd")
const StarfallTerrain=preload("res://scripts/starfall_terrain.gd")
const AqueductReservoir=preload("res://scripts/aqueduct_reservoir.gd")
func _initialize():call_deferred("run")
func surface_geometry():
 var scenery=Scenery.new();var parent=Node3D.new();root.add_child(parent)
 scenery.bridge(parent,Vector3.ZERO)
 for plank in parent.get_child(0).get_children().slice(0,7):
  var bounds=plank.mesh.get_aabb()
  assert(is_equal_approx(plank.position.y+bounds.end.y*plank.scale.y,MapSurface.height_for("=")),"Bridge deck matches walkable height")
 var shrine=Node3D.new();parent.add_child(shrine);scenery.sanctuary(shrine,Vector3.ZERO)
 verify_sanctuary(shrine.get_node("SanctuaryPlinth"))
 var path=[Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(3,0)]
 var heights=func(point):return [0.0,MapSurface.BRIDGE_HEIGHT,MapSurface.SANCTUARY_HEIGHT,0.0][point.x]
 var overlay=MapOverlay.tiles(parent,path,Color.BLUE,.032,"RaisedRange",heights)
 for vertex in overlay.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
  assert(vertex.y>=heights.call(Vector2i(roundi(vertex.x),0))+.0319,"Each range cell clears its physical tile")
 var route=MapOverlay.route(parent,path,heights)
 for vertex in route.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
  var cell=clampi(roundi(vertex.x),0,3)
  assert(vertex.y>=heights.call(Vector2i(cell,0))+.0569,"Route ramps clear the higher side at tile boundaries")
 parent.free()

func verify_bridge_support(scenery):
 var anchor=Node3D.new();root.add_child(anchor)
 for vertical in [false,true]:
  var origin=Vector3(4,.12,6)
  scenery.bridge(anchor,origin,vertical)
  var bridge=anchor.get_child(anchor.get_child_count()-1)
  var expected=PI*.5 if vertical else 0.0
  assert(is_equal_approx(bridge.rotation.y,expected))
  var boards=bridge.find_children("BridgePlank*","MeshInstance3D",false,false)
  var stringers=bridge.find_children("BridgeStringer*","MeshInstance3D",false,false)
  var piles=bridge.find_children("BridgePile*","MeshInstance3D",false,false)
  var crossbeams=bridge.find_children("BridgeCrossbeam*","MeshInstance3D",false,false)
  assert([boards.size(),stringers.size(),piles.size(),crossbeams.size()]==[7,2,4,2])
  var bounds=func(mesh):return mesh.transform*mesh.mesh.get_aabb()
  for board in boards:
   var plank=bounds.call(board)
   assert(is_equal_approx(plank.end.y,MapSurface.BRIDGE_HEIGHT))
   for stringer in stringers:
    var beam=bounds.call(stringer)
    assert(beam.intersects(plank) and beam.position.y<-.07 and beam.end.y>-.07)
  for crossbeam in crossbeams:
   assert(stringers.all(func(beam):return bounds.call(crossbeam).intersects(bounds.call(beam))))
   var supports=piles.filter(func(pile):return bounds.call(crossbeam).intersects(bounds.call(pile)))
   assert(supports.size()==2)
  for pile in piles:
   var post=bounds.call(pile)
   assert(post.position.y<-.2 and post.end.y>-.07 and post.end.y<0)
  for board in boards:
   var envelope=board.global_transform*board.mesh.get_aabb()
   assert(is_equal_approx(envelope.end.y,origin.y+MapSurface.BRIDGE_HEIGHT))
 anchor.free()
 print("PASS: both tactical bridge orientations seat all seven boards on two stringers, four piles and two crossbeams across the waterline")

func verify_sanctuary(plinth: MeshInstance3D):
 var bounds=plinth.transform*plinth.mesh.get_aabb()
 var height=MapSurface.height_for("+")
 assert(is_equal_approx(bounds.position.y,0) and is_equal_approx(bounds.end.y,height))
 assert(bounds.size.x<.9 and bounds.size.z<.9,"The whole stone fits inside its own tile")
 assert(plinth.mesh==SanctuaryPlinth.mesh() and plinth.material_override==SanctuaryPlinth.material())
 assert(plinth.material_override.vertex_color_use_as_albedo and plinth.material_override.vertex_color_is_srgb)
 var arrays=plinth.mesh.surface_get_arrays(0)
 var points=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL];var paints=arrays[Mesh.ARRAY_COLOR]
 assert(points.size()==432)
 var edge_uses={};var volume=0.0;var top_paints={};var hit_height=-INF
 for i in range(0,points.size(),3):
  var a=points[i];var b=points[i+1];var c=points[i+2]
  var cross=(b-a).cross(c-a)
  assert(cross.length()>.0001 and cross.normalized().dot(normals[i])<-.999)
  volume-=a.dot(b.cross(c))/6.0
  for edge in [[a,b],[b,c],[c,a]]:
   var first=str(edge[0]);var second=str(edge[1]);var key=first+"/"+second if first<second else second+"/"+first
   edge_uses[key]=edge_uses.get(key,0)+1
  var hit=Geometry3D.ray_intersects_triangle(Vector3(.04,.5,.02),Vector3.DOWN,a,b,c)
  if hit!=null:hit_height=maxf(hit_height,hit.y)
  if normals[i].dot(Vector3.UP)>.999:top_paints[paints[i]]=true
 assert(volume>.03 and volume<.06 and edge_uses.values().all(func(uses):return uses==2),"The beveled stone and inlay form a closed mesh")
 assert(is_equal_approx(hit_height,height) and top_paints.size()==6,"The brass ring, stone field and four inlay faces meet the walkable surface")

func verify_perimeter():
 var game=Rules.new()
 var scenery=Scenery.new();scenery.batching_enabled=false
 for fixture in [[2,Vector2i(14,10)],[2,Vector2i(50,14)],[2,Vector2i(18,52)],[1,Vector2i(18,34)]]:
  var board: Vector2i=fixture[1]
  game.chapter=fixture[0]
  var rows=[]
  for y in board.y:rows.append(".".repeat(board.x))
  game.info().map=rows;game.info().landmarks=[]
  var ground_state=game.save_data("camp")
  var field=Node3D.new();root.add_child(field)
  scenery.landscape(field,game)
  var base=field.get_child(0)
  assert(base.mesh is PlaneMesh and base.position.is_equal_approx(Vector3(board.x*.5,-.15,board.y*.5)))
  var origin=Vector2(base.position.x,base.position.z)
  var apron=Rect2(origin-base.mesh.size*.5,base.mesh.size)
  var battlefield=Rect2(Vector2(-.5,-.5),Vector2(board))
  assert(apron.encloses(battlefield.grow(24)),"A continuous ground plane extends beyond every battlefield edge")
  assert(base.mesh.size.x>=72 and base.mesh.size.y>=72,"Even small boards have room for the wide zoomed-out view")
  if game.info().environment=="forest":
   var trunks=field.find_children("ConiferTrunk*","MeshInstance3D",false,false)
   assert(trunks.size()==25)
   for trunk in trunks:
    assert(not battlefield.has_point(Vector2(trunk.position.x,trunk.position.z)),
     "Background trees stay outside the authored tiles")
  else:
   var river=field.get_child(1)
   assert(river.mesh is PlaneMesh and river.mesh.size==Vector2(2,base.mesh.size.y))
   assert(river.position.is_equal_approx(Vector3(5.5,-.07,base.position.z)))
  assert(game.save_data("camp")==ground_state)
  field.free()
 print("PASS: large battlefield perimeters keep the ground, river and all background trees beyond the authored tiles")

func run():
 surface_geometry()
 verify_perimeter()
 await verify_aqueduct_reservoir()
 verify_bridge_support(Scenery.new())
 verify_arena_ground()
 await verify_river_arena()
 verify_water_styles()
 verify_ridges()
 verify_starfall_terrain()
 await verify_pass_escarpment()
 verify_rocks()
 var game=Rules.new();var seen={}
 var scenery=Scenery.new();scenery.batching_enabled=false
 var previous_paint: ShaderMaterial
 var bridge_water=0;var sanctuaries=0
 for chapter in range(12):
  game.chapter=chapter;var state=game.rng.state;var board=game.board_size();var theme=game.info().environment
  var world=Node3D.new();root.add_child(world);scenery.landscape(world,game)
  var floors=world.get_children().filter(func(node):return node is MeshInstance3D and node.name.begins_with("MapGround"))
  assert(not floors.is_empty())
  var paint=floors[0].material_override
  assert(paint!=previous_paint,"Each chapter owns its terrain control texture")
  previous_paint=paint
  assert(paint.get_shader_parameter("blend_edges")==true,"Tactical ground uses the blending shader")
  assert(paint.get_shader_parameter("wang_enabled")==true,"All chapter floors enable edge-matched texture variation")
  assert((paint.get_shader_parameter("ash_paving")==true)==(theme=="furnace"),"Only Reddeep tints the tactical paving with ash")
  var wang=paint.get_shader_parameter("wang_texture")
  assert(wang is Texture2D and wang.get_size()==Vector2(576,1152),"Each chapter binds the padded natural-ground Wang atlas")
  assert(wang.get_image().has_mipmaps(),"Natural ground retains mipmaps for distant map views")
  var control=paint.get_shader_parameter("surface_weights").get_image()
  assert(control.get_size()==board+Vector2i.ONE*4,"Control map includes grass padding around the board")
  assert(control.get_pixel(0,0)==Color(1,0,0,0) and control.get_pixel(control.get_width()-1,control.get_height()-1)==Color(1,0,0,0),"Landscape beyond the board resolves to grass")
  var floor_cells={};var water_cells={}
  var shrine_cells={}
  for plinth in world.find_children("SanctuaryPlinth*","MeshInstance3D",false,false):
   assert(plinth.mesh==SanctuaryPlinth.mesh() and plinth.material_override==SanctuaryPlinth.material())
   var cell=Vector2i(roundi(plinth.position.x),roundi(plinth.position.z))
   assert(not shrine_cells.has(cell),"A tile gets one sanctuary plinth")
   shrine_cells[cell]=true
  sanctuaries+=shrine_cells.size()
  for floor in floors:
   assert(floor.material_override==paint,"All ground cells share one batchable material")
   floor_cells[Vector2i(roundi(floor.position.x),roundi(floor.position.z))]=true
  for water in world.get_children().filter(func(node):return node is MeshInstance3D and node.name.begins_with("MapWater")):
   water_cells[Vector2i(roundi(water.position.x),roundi(water.position.z))]=water.position.y
  for y in range(board.y):
   for x in range(board.x):
    var cell=Vector2i(x,y);var symbol=game.terrain(cell);var weights=control.get_pixel(x+2,y+2)
    assert(shrine_cells.has(cell)==(symbol=="+"),"Every sanctuary and only a sanctuary gets an inlaid crest")
    if symbol in ["~","="]:
     assert(not floor_cells.has(cell) and is_equal_approx(water_cells[cell],-.07),"Water and bridge cells have water below the deck, without grass sealing the opening")
     if symbol=="=":bridge_water+=1
     assert(weights==(Color(0,0,1,0) if theme in MapGround.NATURAL else Color(0,0,0,0)),"Natural shores blend to earth; masonry water contributes no ground color")
    else:
     assert(floor_cells.has(cell) and weights.r+weights.g+weights.b+weights.a==1,"Every land tile has one intact dominant ground painting")
     if symbol=="h":assert(weights.b==1,"Hills retain earth")
     elif symbol=="p":assert(weights.a==1 if theme in ["observatory","engine","furnace"] else weights.g==1,"Roads retain their chapter's stone painting")
  assert(game.rng.state==state,"Ground painting does not consume campaign randomness")
  world.free()
 assert(bridge_water==38,"All authored bridge tiles reveal water beneath the planks")
 assert(sanctuaries==24)
 print("PASS: 24 sanctuary plinths share one closed beveled mesh and preserve the raised walkable surface")
 var banks=0;var exposed=0
 for chapter in range(12):
  game.chapter=chapter;var seams={};var state=game.rng.state
  for y in range(game.board_size().y):
   for x in range(game.board_size().x):
    var cell=Vector2i(x,y)
    if game.terrain(cell)!="~":continue
    var bank=RiverBank.build(game,cell)
    if bank==null:continue
    banks+=1;var arrays=bank.surface_get_arrays(0)
    assert(arrays[Mesh.ARRAY_VERTEX].size()==pow(RiverBank.STEPS+1,2))
    assert(arrays[Mesh.ARRAY_INDEX].size()==RiverBank.STEPS*RiverBank.STEPS*6)
    for vertex in arrays[Mesh.ARRAY_VERTEX]:
     assert(vertex.y>=RiverBank.BED_HEIGHT-.0001 and vertex.y<=.0001,"Shore stays below walkable terrain and above the river bed")
     var point=Vector2(vertex.x+x,vertex.z+y).snapped(Vector2.ONE*.00001)
     if seams.has(point):assert(absf(seams[point]-vertex.y)<.0001,"Adjacent bank tiles share matching edge and corner heights")
     seams[point]=vertex.y
     if vertex.y>-.07 and vertex.y<-.001:exposed+=1
     for land in RiverBank.nearby_land(game,cell):
      if (point-land).abs().x<=.5 and (point-land).abs().y<=.5:assert(is_zero_approx(vertex.y),"Bank meets neighboring land without a lip")
    for normal in arrays[Mesh.ARRAY_NORMAL]:assert(normal.y>.5,"Bank lighting normals face above the water")
  assert(game.rng.state==state,"Shore generation does not consume gameplay randomness")
 assert(banks>10 and exposed>100,"Campaign water includes visible sloped shore geometry")
 print("PASS: sampled shoreline grids preserve their vertices, joined edges and upward lighting normals")
 for chapter in range(12):
  game.chapter=chapter;game.start_battle()
  var a=game.units[0].duplicate(true);var b=game.living("enemy")[0].duplicate(true)
  a.weapon="sword";b.weapon="sword";a.item="iron_sword";b.item="iron_sword";a.pow=20;b.defense=3;a.speed=8;b.speed=8
  game.units=[a,b]
  for y in range(game.board_size().y):
   for x in range(game.board_size().x):
    var p=Vector2i(x,y);var symbol=game.terrain(p);var profile=game.terrain_profile(p)
    seen[symbol]=true
    assert(profile.move==(0 if symbol in ["#","~"] else 2 if symbol in ["f","h"] else 1),"Terrain readout preserves movement costs")
    assert(profile.cover==(2 if symbol in ["f","h","o"] else 0) and profile.avoid==profile.cover*5,"Terrain readout preserves combat cover")
    assert(profile.heal==(6 if symbol in ["+","o"] else 0),"Terrain readout preserves recovery")
    b.x=x;b.y=y;a.x=x-1;a.y=y;b.hp=1;b.max_hp=30
    var forecast=game.forecast(a,b)
    assert(forecast.hit==85-profile.avoid,"Displayed avoidance is used by real forecasts")
    assert(forecast.damage==game.attack_power(a)-b.defense-profile.cover,"Displayed cover reduces real damage")
    game.next_player_turn();assert(b.hp==1+profile.heal,"Displayed recovery is applied at turn start")
 assert(seen.size()==9,"All authored terrain symbols checked")
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-terrain-test.json";root.add_child(app);await process_frame
 app.game.start_battle();app.make_map();app.show_battle();await process_frame
 var terrain_icons={}
 for chapter in range(12):
  app.game.chapter=chapter
  for y in range(app.game.board_size().y):
   for x in range(app.game.board_size().x):
    var point=Vector2i(x,y);var symbol=app.game.terrain(point)
    if terrain_icons.has(symbol):continue
    terrain_icons[symbol]=true;app.terrain_card.inspect(app.game,point)
    assert(app.terrain_card.icon.texture.resource_path.ends_with("/"+app.game.terrain_profile(point).name.to_lower()+".svg"),"Real tile inspection chooses the emblem matching its terrain profile")
    await process_frame;await process_frame
    assert(app.terrain_card.icon.get_global_rect().end.x<=app.terrain_card.heading.get_global_rect().position.x,"Terrain emblem does not overlap its name")
 assert(terrain_icons.size()==9,"Every campaign terrain has an original readout emblem")
 app.game.chapter=0
 var actor=app.game.units[0];var tested={}
 for chapter in range(12):
  app.game.chapter=chapter
  for y in range(app.game.board_size().y):
   for x in range(app.game.board_size().x):
    var point=Vector2i(x,y);var symbol=app.game.terrain(point)
    if symbol not in ["=","+"] or tested.has(symbol):continue
    tested[symbol]=true;actor.x=x;actor.y=y;app.refresh_pieces()
    assert(app.unit_nodes[actor.id].position==app.map_position(point),"Refreshed units stand on raised scenery")
    app.cursor_tile=point;app.draw_map_cursor()
    assert(is_equal_approx(app.markers.get_children()[-1].position.y,MapSurface.height_for(symbol)),"Selection corners follow surface height")
    var neighbor=point+Vector2i.LEFT
    await app.animate_map_move(actor,[neighbor,point])
    assert(app.unit_nodes[actor.id].position==app.map_position(point),"Animation ends on the raised surface")
    await app.animate_map_move(actor,[point,neighbor])
    assert(app.unit_nodes[actor.id].position==app.map_position(neighbor),"Animation descends back to the neighboring surface")
 assert(tested.size()==2,"Both raised terrain types occur in campaign maps")
 app.game.chapter=0;app.game.start_battle();app.make_map();app.show_battle();await process_frame
 app.move_map_cursor(Vector2i.RIGHT)
 assert(app.terrain_card.tile==app.cursor_tile,"Keyboard cursor updates terrain")
 for y in range(app.game.board_size().y):
  for x in range(app.game.board_size().x):
   app.preview_route(Vector2i(x,y))
   assert(app.terrain_card.heading.text==app.game.terrain_profile(Vector2i(x,y)).name.to_upper(),"Mouse route preview updates terrain even without a selection")
 app.preview_route(Vector2i(-1,-1));assert(not app.terrain_card.visible,"Off-board pointer hides stale terrain")
 var a=app.game.units[0];var b=app.game.living("enemy")[0];a.x=8;a.y=4;b.x=9;b.y=4
 await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"damage":1,"remaining":19,"hit":true,"crit":false}],{a.id:20,b.id:20})
 assert(not app.terrain_card.visible,"Combat returns each tactical panel to its prior visibility")
 for dimensions in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions
  app.terrain_card.inspect(app.game,Vector2i(0,0));await process_frame;await process_frame
  assert(app.terrain_card.get_rect().end.x<dimensions.x-325 and app.terrain_card.get_rect().end.y<dimensions.y-84,"Terrain card remains clear of command and help panels")
  for label in [app.terrain_card.heading,app.terrain_card.values,app.terrain_card.detail]:
   assert(label.get_global_rect().end.x<=app.terrain_card.get_global_rect().end.x and label.get_global_rect().end.y<=app.terrain_card.get_global_rect().end.y,"Terrain labels fit their frame")
 for player in app.sfx_players:player.stop()
 app.music.stop();await create_timer(.15).timeout
 await Shutdown.dispose(app);await process_frame
 print("PASS: nine terrain profiles across twelve maps, real movement/cover/healing values, cursor readout and visibility restoration")
 quit()

func verify_ridges():
 var ridges=preload("res://scripts/arena_ridges.gd")
 var game=Rules.new();var rng=game.rng.state;var signatures=[]
 for mountain in [false,true]:
  for layer in range(3):
   var mesh=ridges.mesh(layer,mountain);assert(mesh==ridges.mesh(layer,mountain),"Distant relief reuses cached source meshes")
   var arrays=mesh.surface_get_arrays(0);var points=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL];var colors=arrays[Mesh.ARRAY_COLOR]
   assert(points.size()==ridges.COLUMNS*ridges.ROWS*6,"Each ridge has a fixed 768-triangle budget")
   var shared={};var heights=[]
   for i in range(points.size()):
    var point=points[i];var key=Vector2(point.x,point.z)
    assert(point.z<=-26 and point.y>=-.061 and point.y<18,"Relief remains behind the landmarks and out of combat space")
    assert(absf(normals[i].length()-1)<.001 and normals[i].y>0,"Terrain lighting normals remain normalized and upward")
    assert(colors[i].a==1 and colors[i].r>.79 and colors[i].r<1.07,"Ridge color variation remains opaque and restrained")
    if shared.has(key):assert(shared[key]==point.y,"Adjacent heightfield cells share exact seam elevations")
    shared[key]=point.y
    if is_equal_approx(point.z,ridges.DEPTHS[layer].x) or is_equal_approx(point.z,ridges.DEPTHS[layer].y) or is_equal_approx(absf(point.x),ridges.WIDTH*.5):
     assert(is_equal_approx(point.y,-.06),"Every boundary settles continuously to the distant ground plane")
   for i in range(0,points.size(),3):
    var cross=(points[i+1]-points[i]).cross(points[i+2]-points[i])
    assert(cross.length()>.001 and cross.y<0,"No collapsed or downward-wound terrain triangles")
   for column in range(ridges.COLUMNS+1):
    var x=-ridges.WIDTH*.5+float(column)/ridges.COLUMNS*ridges.WIDTH
    heights.append(ridges.height_at(x,lerpf(ridges.DEPTHS[layer].x,ridges.DEPTHS[layer].y,.45),layer,mountain))
   var signature=str(heights).sha256_text();assert(signature not in signatures,"Every hill/mountain layer has its own authored skyline")
   signatures.append(signature)
 var scenery=Scenery.new();scenery.batching_enabled=false
 var skylines={}
 for theme in ["mountain","road","forest","river","village","observatory","harbor","castle"]:
  var stage=Node3D.new();root.add_child(stage);var center=Vector3(35,0,0)
  scenery.battle_landscape(stage,center,{"environment":theme})
  var layers=stage.get_children().filter(func(node):return node.name.begins_with("ArenaRidge"))
  assert(layers.size()==(0 if theme in ["harbor","castle"] else 3),"Only outdoor land arenas receive layered terrain")
  if not layers.is_empty():
   var look=ridges.LANDSCAPES[theme]
   var heights=[]
   for index in layers.size():
    var layer=layers[index]
    var framed=layer.transform*layer.mesh.get_aabb()
    var level=center.y if theme in MapGround.CONTINUOUS_ARENAS else center.y-.06
    assert(is_equal_approx(framed.position.y,level) and framed.end.z<=center.z-26,"The landscape maintains the ground seam and the fighting lane's clearance")
    assert(layer.mesh==ridges.mesh(index,theme in ["mountain","observatory"]) and layer.material_override==ridges.material(index,theme))
    assert(layer.material_override.albedo_color==look.near.lerp(look.distant,index*.15),"Each layer takes its place-specific color")
    assert(layer.material_override.vertex_color_use_as_albedo and layer.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
    assert(is_equal_approx(layer.position.x-center.x,look.offset*(index+1)) and is_equal_approx(layer.scale.y,look.height))
    heights.append(framed.end.y-center.y)
   skylines[theme]=heights
   scenery.batcher.combine(stage)
   for index in layers.size():
    var themed_surface=ridges.material(index,theme)
    assert(stage.get_children().any(func(node):return node is MeshInstance3D and node.material_override==themed_surface),"The authored palette survives actual scenery batching")
  stage.free()
 assert(skylines.size()==6 and game.rng.state==rng,"Distant landscape generation consumes no campaign random state")
 for index in 3:
  assert(skylines.river[index]<skylines.road[index] and skylines.road[index]<skylines.village[index])
  assert(skylines.village[index]<skylines.forest[index] and skylines.forest[index]<skylines.mountain[index])
  assert(skylines.observatory[index]<skylines.mountain[index])
 print("PASS: six arena skylines with distinct heights and palettes, planted boundaries, shared meshes and independent campaign RNG")

func verify_starfall_terrain():
 var game=Rules.new();game.chapter=8
 var saved=game.save_data("camp").duplicate(true)
 var scenery=Scenery.new();scenery.batching_enabled=false
 var field=Node3D.new();root.add_child(field);scenery.landscape(field,game)
 var floor=field.get_node("StarfallSlateApron")
 var rim=field.find_children("StarfallBrokenSlate*","MeshInstance3D",false,false)
 var rock=field.find_children("StarfallScree*","MeshInstance3D",false,false)
 var board=Rect2(Vector2(-.5,-.5),Vector2(game.board_size()))
 var foundation=field.get_node("ObservatoryFoundations")
 var ledge=foundation.transform*foundation.mesh.get_aabb()
 assert(is_equal_approx(ledge.end.y,-.015) and ledge.position.y<floor.position.y)
 assert(Rect2(Vector2(ledge.position.x,ledge.position.z),Vector2(ledge.size.x,ledge.size.z)).encloses(board))
 assert(rim.size()==3 and rock.size()==8 and floor.mesh==StarfallTerrain.apron())
 for part in rim+rock:
  var bounds=part.transform*part.mesh.get_aabb()
  assert(not board.intersects(Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z))))
  assert(bounds.position.y<=floor.position.y+.0001 and bounds.end.y>floor.position.y+.10)
 var stage=Node3D.new();root.add_child(stage)
 var center=Vector3(35,0,0)
 var context=scenery.combat_context(game,{"x":9,"y":1},{"x":10,"y":1})
 scenery.battle_landscape(stage,center,context)
 var apron=stage.get_node("StarfallSlateApron")
 var close_rim=stage.get_node("StarfallBrokenSlate")
 var terrace=stage.get_node("ObservatoryTerrace")
 assert(apron.mesh==floor.mesh and apron.material_override==floor.material_override and close_rim.mesh==rim[0].mesh)
 var arena_bounds=close_rim.transform*close_rim.mesh.get_aabb()
 assert(arena_bounds.end.z<center.z-15.5 and is_equal_approx(arena_bounds.position.y,apron.position.y))
 var terrace_edge=terrace.position.z-terrace.mesh.size.y*.5
 assert(absf(terrace_edge-arena_bounds.end.z)<.35 and terrace.position.y>apron.position.y)
 assert(stage.find_children("StarfallScree*","MeshInstance3D",false,false).size()==7)
 scenery.batcher.combine(field);scenery.batcher.combine(stage)
 for group in [field,stage]:
  assert(group.get_children().any(func(part):return part is MeshInstance3D and part.material_override==StarfallTerrain.material()))
 assert(game.save_data("camp")==saved)
 field.free();stage.free()
 print("PASS: shared Starfall slate and rocks stay rooted outside the playable board and close-up fighting lane")

func verify_pass_escarpment():
 var game=Rules.new();game.chapter=6
 var snapshot=game.save_data("camp")
 var scenery=Scenery.new();scenery.batching_enabled=false
 var map=Node3D.new();root.add_child(map);scenery.landscape(map,game)
 var map_slope=map.get_node("PassEscarpment")
 var map_bounds=map_slope.transform*map_slope.mesh.get_aabb()
 assert(map_bounds.end.z<-.5 and is_equal_approx(map_bounds.position.y,-.15),"Rock rises beyond the tactical cells and joins their extended ground")
 var talus=map.get_node("PassTalus")
 var talus_bounds=talus.transform*talus.mesh.get_aabb()
 assert(talus_bounds.position.z>game.board_size().y and talus_bounds.position.y<-.15 and talus_bounds.end.y<.30,
  "Both scree deposits are seated in the ground beyond the board")
 assert(talus.mesh.get_surface_count()==1 and talus.material_override==map_slope.material_override)
 assert(talus.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
 var arrays=map_slope.mesh.surface_get_arrays(0)
 var points=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL]
 assert(points.size()==1344 and map_slope.material_override.vertex_color_use_as_albedo)
 var seams={};var paint={}
 for i in range(0,points.size(),3):
  var cross=(points[i+1]-points[i]).cross(points[i+2]-points[i])
  assert(cross.y<-.7 and cross.normalized().dot(normals[i])<-.998,"All rock faces have outward winding and upward normals")
  for index in range(i,i+3):
   var point=points[index];var key=Vector2(point.x,point.z)
   if seams.has(key):assert(seams[key]==point.y)
   seams[key]=point.y;paint[arrays[Mesh.ARRAY_COLOR][index]]=true
   if point.z in [0.0,-10.5] or absf(point.x)==22.0:assert(is_zero_approx(point.y))
 assert(seams.size()==264 and paint.size()>40,"The rock courses join continuously and retain a varied stone palette")
 var center=Vector3(35,0,0)
 var context=scenery.combat_context(game,{"x":4,"y":5},{"x":5,"y":5})
 assert(context.landmarks.size()==1)
 var stage=Node3D.new();root.add_child(stage);scenery.battle_landscape(stage,center,context)
 var slope=stage.get_node("PassEscarpment")
 assert(not stage.has_node("PassTalus"))
 var bounds=slope.transform*slope.mesh.get_aabb()
 assert(slope.mesh==map_slope.mesh and slope.material_override==map_slope.material_override)
 assert(is_equal_approx(bounds.position.y,center.y) and bounds.end.z<-10 and bounds.position.z>-26)
 for landmark in stage.find_children("ArenaLandmark*","Node3D",false,false):
  for stone in landmark.find_children("*","MeshInstance3D"):
   assert((stone.global_transform*stone.mesh.get_aabb()).position.z>bounds.end.z,"The old pass ruin stands in front of the escarpment")
 var arena_flames=verify_pass_beacons(stage,slope)
 var map_flames=verify_pass_beacons(map,map_slope)
 var map_boulders=[]
 for stone in map.find_children("Boulder*","MeshInstance3D",false,false):
  map_boulders.append({"local":stone.global_transform.affine_inverse(),"points":stone.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]})
 scenery.batcher.combine(stage);scenery.batcher.combine(map)
 for flame in arena_flames+map_flames:
  assert(flame.get_child_count()==2,"Animating flames retain both parts after static batching")
 assert(stage.get_node("PassEscarpment")==slope and map.get_node("PassEscarpment")==map_slope,"Scenery retains the same slope mesh after batching")
 var viewport=SubViewport.new();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var camera=Camera3D.new();viewport.add_child(camera);camera.current=true
 var director=preload("res://scripts/combat_camera.gd")
 for mounted in [false,true]:
  var frame=director.frame_pair(center+Vector3.LEFT*1.6,center+Vector3.RIGHT*1.6,"wide",false,mounted)
  camera.position=frame.anchor;camera.fov=frame.lens;camera.look_at(frame.focus)
  for size in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
   viewport.size=size;await process_frame
   var crest=slope.to_global(PassEscarpment.vertex(9,4))
   var screen=camera.unproject_position(crest)
   assert(Rect2(Vector2.ZERO,Vector2(size)).grow(-12).has_point(screen) and screen.y<size.y*.60,"Windscar's ridge appears behind the fighters in the default opening shot")
   var safe=Rect2(12,12,size.x-24,size.y*.64-12)
   assert(arena_flames.any(func(flame):return clear_pass_flame(flame,slope,points,camera,safe)),
    "A Windscar beacon should be visible above the rock and clear of the combat HUD")
 var map_center=Vector3((game.board_size().x-1)*.5,0,(game.board_size().y-1)*.5)
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=maxf(16,game.board_size().x+2)
 camera.position=map_center+Vector3(2.5,22,11.5);camera.look_at(map_center)
 camera.h_offset=2.0
 for size in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
  viewport.size=size;await process_frame
  var safe=Rect2(Vector2.ZERO,Vector2(size)).grow(-12)
  for local in [Vector3(-5.8,.2,1.4),Vector3(4.75,.2,1.54)]:
   assert(safe.has_point(camera.unproject_position(talus.to_global(local))),"Both foreground deposits are visible at Home")
  for row in game.board_size().y:
   for column in game.board_size().x:
    var cell=Vector3(column,0,row)
    var origin=camera.project_ray_origin(camera.unproject_position(cell))
    assert(talus_bounds.intersects_segment(origin,cell)==null,"Even the combined scree bounds leave every tile center in view")
  for flame in map_flames:
   assert(clear_pass_flame(flame,map_slope,points,camera,safe),"The Windscar overview frames both beacons above the rock")
   var target=flame.to_global(Vector3(0,.34,0))
   var start=camera.project_ray_origin(camera.unproject_position(target))
   assert(not map_boulders.any(func(stone):
    return rock_blocks_flame(stone.local*start,stone.local*target,stone.points)
   ),"The individual rocks leave both map flames visible")
 viewport.free();stage.free();map.free()
 assert(game.save_data("camp")==snapshot,"The new scenery leaves the campaign snapshot and RNG unchanged")
 print("PASS: continuous Windscar escarpment, 448 lit triangles, shared geometry, clear ruins and six wide-shot projections")
 print("PASS: two Windscar scree deposits in one mesh stay visible without covering any tile center")
 print("PASS: both Windscar maps seat two independent beacons, with animated flames retained after batching and nine clear arena/map projections")

func verify_pass_beacons(parent: Node3D,slope: MeshInstance3D) -> Array:
 var beacons=parent.find_children("PassBeacon*","Node3D",false,false)
 assert(beacons.size()==2 and parent.find_children("*","Light3D",true,false).is_empty())
 var flames=[]
 for beacon in beacons:
  assert(is_equal_approx(beacon.position.y,PassEscarpment.height_at(slope,beacon.position)))
  var foundation=beacon.get_node("BeaconFooting")
  var base=foundation.global_transform*foundation.mesh.get_aabb()
  for offset in [Vector3.ZERO,Vector3.LEFT*.25,Vector3.RIGHT*.25,Vector3.FORWARD*.25,Vector3.BACK*.25]:
   var point=beacon.to_global(offset)
   var y=PassEscarpment.height_at(slope,point)
   assert(base.position.y<y and base.end.y>y,"The stone foundation seats across the actual slope")
  var names=["BeaconFooting","BeaconPedestal","BeaconBowl","BeaconRim","BeaconCoal"]
  var previous=AABB()
  for name in names:
   var part=beacon.get_node(name)
   var bounds=part.transform*part.mesh.get_aabb()
   if name!=names[0]:assert(bounds.intersects(previous))
   previous=bounds
  var flame=beacon.get_node("BeaconFlame")
  flame.set_process(false)
  assert(is_equal_approx(flame.position.y,.92))
  for tongue in flame.get_children():
   assert(tongue.material_override.emission_enabled and tongue.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
   var bounds=(flame.transform*tongue.transform)*tongue.mesh.get_aabb()
   assert(bounds.intersects(previous),"The tongues emerge from the coal bed")
  var initial=flame.phase
  flame._process(.3)
  assert(flame.phase!=initial and flame.scale.y>=.78 and flame.scale.y<=1.22)
  var visible_phase=flame.phase;var visible_shape=flame.scale
  beacon.hide();flame._process(4)
  assert(flame.phase==visible_phase and flame.scale==visible_shape)
  beacon.show();flames.append(flame)
 assert(flames[0].phase!=flames[1].phase)
 return flames

func clear_pass_flame(flame: Node3D,slope: MeshInstance3D,points: PackedVector3Array,camera: Camera3D,safe: Rect2) -> bool:
 var target=flame.to_global(Vector3(0,.34,0))
 var screen=camera.unproject_position(target)
 if camera.is_position_behind(target) or not safe.has_point(screen):return false
 return not rock_blocks_flame(slope.to_local(camera.project_ray_origin(screen)),slope.to_local(target),points)

func rock_blocks_flame(start: Vector3,finish: Vector3,points: PackedVector3Array) -> bool:
 var span=finish-start
 var direction=span.normalized();var reach=span.length_squared()
 for index in range(0,points.size(),3):
  var hit=Geometry3D.ray_intersects_triangle(start,direction,points[index],points[index+1],points[index+2])
  if hit!=null and Vector3(hit).distance_squared_to(start)<reach:return true
 return false

func verify_rocks():
 var forms=preload("res://scripts/rock_forms.gd");var signatures=[]
 for variant in range(3):
  var shape=forms.mesh(variant);assert(shape==forms.mesh(variant+3),"Bounded rock variants reuse shared geometry")
  var arrays=shape.surface_get_arrays(0);var points=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL];var uv=arrays[Mesh.ARRAY_TEX_UV]
  assert(points.size()==216,"Each fractured rock uses 72 closed triangles")
  var edges={}
  for i in range(0,points.size(),3):
   var cross=(points[i+1]-points[i]).cross(points[i+2]-points[i])
   assert(cross.length()>.00001 and cross.normalized().dot(normals[i])<-.999,"Faceted stone has nondegenerate faces and outward clockwise winding")
   var center=(points[i]+points[i+1]+points[i+2])/3
   assert(center.dot(normals[i])>0,"Every rock face points out from its interior")
   for j in range(3):
    var point=points[i+j]
    assert(Vector2(point.x,point.z).length()<=1.00001 and point.y>-.75 and point.y<1.0,"Fractured silhouettes retain the former rock's footprint and top envelope")
    assert(uv[i+j].x>=0 and uv[i+j].x<=1 and uv[i+j].y>=0 and uv[i+j].y<=1,"Face-projected stone UVs stay in the original material tile")
    var a=str(point.snapped(Vector3.ONE*.00001));var b=str(points[i+(j+1)%3].snapped(Vector3.ONE*.00001))
    var edge=a+":"+b if a<b else b+":"+a;edges[edge]=edges.get(edge,0)+1
  for count in edges.values():assert(count==2,"Rock surfaces have no open edges")
  var signature=str(points).sha256_text();assert(signature not in signatures,"The three rocks have distinct actual fracture silhouettes")
  signatures.append(signature)
 var scenery=Scenery.new();var stage=Node3D.new();root.add_child(stage)
 var seen={}
 for index in range(12):
  var point=Vector3(index*.7,.2,-3-index%3);var radius=.32 if index%2 else 2.5
  var rock=scenery.boulder(stage,point,radius);seen[forms.variant_at(point)]=true
  assert(rock.mesh==forms.mesh(forms.variant_at(point)) and rock.position==point and rock.scale==Vector3(radius,radius*.6,radius*.8),"Map and arena rocks keep their existing placement, material scale and grounded attachment")
 assert(seen.size()==3,"Deterministic placement distributes all stone variants")
 stage.free()

func verify_arena_ground():
 var scenery=Scenery.new();var game=Rules.new();var count=0
 verify_arena_paint(scenery)
 for chapter in range(12):
  game.chapter=chapter;var before=game.rng.state
  var rainy=game.info().environment=="forest"
  var furnace=game.info().environment=="furnace"
  var tactical=MapGround.material(game,scenery.atlas)
  assert((tactical.get_shader_parameter("rain_soaked")==true)==rainy)
  assert(scenery.ground_material(0).get_shader_parameter("rain_soaked")!=true,"Greywood cannot change the shared dry grass")
  for tile in [0,2]:
   var material=scenery.ground_material(tile)
   assert(material==scenery.ground_material(tile),"Repeated arena terrain retains shared material identity")
   assert(material.get_shader_parameter("wang_enabled")==true and material.get_shader_parameter("blend_edges")!=true,"Standalone natural surfaces use the varied atlas without sampling a missing tactical control map")
   assert(material.get_shader_parameter("natural_surface")== (0 if tile==0 else 1),"Grass and dirt choose their own sixteen edge-matched paintings")
   for parameter in ["wang_texture","wang_scale","atlas_texture"]:
    assert(material.get_shader_parameter(parameter)==tactical.get_shader_parameter(parameter),"Map and close-up ground share painting and physical detail scale")
  for tile in [1,3]:
   assert(scenery.ground_material(tile).get_shader_parameter("wang_enabled")!=true,"Cobblestone, rock and slate retain their existing painting")
  for symbol in [".","f","h","p","+","="]:
   var arena=Node3D.new();root.add_child(arena);scenery.batching_enabled=false
   scenery.battle_landscape(arena,Vector3(35,0,0),{"chapter":chapter,"environment":game.info().environment,"terrain":symbol})
   var natural={};var sheets=0
   var wet_floor: Material
   var ash_sheets=0
   for node in arena.get_children():
    if not node is MeshInstance3D or not node.mesh is PlaneMesh:continue
    var paint=node.material_override
    if node.name=="AbbeyGardenLawn":
     assert(game.info().environment=="abbey" and paint==scenery.ground_material(0))
     assert(node.position.z+node.mesh.size.y*.5<-11.5,"The garden paint begins beyond the fighting floor")
     continue
    if paint is ShaderMaterial and paint.shader==tactical.shader:sheets+=1
    if paint is ShaderMaterial and paint.get_shader_parameter("ash_paving")==true:
     ash_sheets+=1
     assert(paint==scenery.ground_material(3,false,true) and paint.get_shader_parameter("quadrant")==Vector2(.5,.5))
     assert(paint.get_shader_parameter("atlas_texture")==tactical.get_shader_parameter("atlas_texture"))
    if paint is ShaderMaterial and paint.get_shader_parameter("rain_soaked")==true:
     assert(wet_floor==null and paint.shader==tactical.shader)
     wet_floor=paint
    if paint is ShaderMaterial and paint.shader==tactical.shader and paint.get_shader_parameter("wang_enabled")==true:
     var kind=0 if paint.get_shader_parameter("blend_edges")==true else paint.get_shader_parameter("natural_surface")
     natural[kind]=paint
     assert(kind in [0,1] and (is_zero_approx(node.position.y) or is_equal_approx(node.position.y,-.06)),"Natural arena painting stays on intact ground sheets at the intended levels")
   var stone=game.info().environment in MapGround.STONE
   var wood=symbol=="="
   var continuous=not wood and game.info().environment in MapGround.CONTINUOUS_ARENAS
   var expected=maxi(0,MapGround.surface_for(symbol,game.info().environment))
   assert(ash_sheets==(1+int(not wood and expected==3) if furnace else 0),
    "Reddeep recolors its background and slate fighting lane, including the slate banks beside an unchanged wooden deck")
   assert(scenery.ground_material(3).get_shader_parameter("ash_paving")!=true,"Reddeep leaves shared slate intact")
   assert(arena.get_meta("arena_surface")==expected,"Combat retains the selected tactical tile's actual grass, earth or paving instead of replacing a whole chapter with slate")
   assert(natural.has(0)==(not stone or (not wood and expected==0)),"Natural chapters retain varied grass around the fighting lane")
   if continuous:
    var floor=arena.get_node("ArenaGround")
    assert(sheets==1 and floor.mesh.size==Vector2(70,70) and is_zero_approx(floor.position.y),"The walking surface extends continuously through the meadow")
    var paint=floor.material_override
    assert((paint.get_shader_parameter("blend_edges")==true)==(expected!=0))
    if expected!=0:
     assert(paint.get_shader_parameter("surface_weights")==MapGround.arena_controls[expected])
     assert(paint.get_shader_parameter("control_origin")==Vector2(35,0)-Vector2(MapGround.ARENA_CONTROL_RADIUS))
   else:
    assert(natural.has(1)==(not wood and expected==2),"Hill combat retains varied dirt at the fighters' feet")
   scenery.batcher.combine(arena)
   assert((wet_floor!=null)==rainy,"Only Greywood's arena ground gets wet, including the banks below a deck")
   if rainy:
    assert(arena.get_children().any(func(node):return node is MeshInstance3D and node.material_override==wet_floor),
     "Static batching keeps the rain treatment")
   if furnace:
    var ash=scenery.ground_material(3,false,true)
    assert(arena.get_children().any(func(node):return node is MeshInstance3D and node.get_meta("static_batch",false) and node.material_override==ash),
     "Static batching keeps Reddeep's shared ash material")
   for paint in natural.values():
    var present=false
    for node in arena.get_children():
     if node is MeshInstance3D and node.get_meta("static_batch",false) and node.material_override==paint:present=true
    assert(present,"Static batching preserves the actual arena ground binding")
   count+=1;arena.free()
  assert(game.rng.state==before,"Ground presentation consumes no campaign RNG")
 print("PASS: %d raw/batched arena floors share tactical natural texture variety and scale while preserving stone, deck and water"%count)
 print("PASS: Greywood alone keeps a rain-soaked material on the map and across all six arena floor layouts")
 print("PASS: Reddeep alone tints its slate paving with ash across the map and six raw/batched arena layouts")

func verify_arena_paint(scenery):
 var radius=MapGround.ARENA_CONTROL_RADIUS
 for kind in [1,2]:
  var image=MapGround.arena_control_image(kind)
  assert(image.get_size()==radius*2+Vector2i.ONE)
  var shoulder={}
  for row in image.get_height():
   for column in image.get_width():
    var pixel=image.get_pixel(column,row)
    assert(absf(pixel.r+pixel[kind]-1)<.005 and pixel.a==0)
    if column in [0,image.get_width()-1] or row in [0,image.get_height()-1]:
     assert(pixel==MapGround.WEIGHTS[0],"The entire mask boundary is pure grass")
    if absi(column-radius.x)<=7 and row==radius.y:
     assert(pixel==MapGround.WEIGHTS[kind],"The complete engagement line keeps the selected tactical surface")
    if pixel[kind]>0 and pixel[kind]<1:shoulder[pixel[kind]]=true
  assert(shoulder.size()>35,"The irregular shoulder has a gradual transition instead of a hard edge")
  var first=MapGround.arena_material(kind,Vector3(35,0,0),scenery.atlas)
  var later=MapGround.arena_material(kind,Vector3(-9,.7,7),scenery.atlas)
  var texture=first.get_shader_parameter("surface_weights")
  assert(texture==later.get_shader_parameter("surface_weights") and texture.get_image().get_data()==image.get_data())
  assert(later.get_shader_parameter("control_origin")==Vector2(-9,7)-Vector2(radius),"One shared mask follows the arena at a different world origin")
 print("PASS: continuous outdoor lanes, grass borders, two gradual control masks, exact footing and shared paint at translated origins")

func verify_river_arena():
 for far_bank in [false,true]:
  var strip=RiverBank.arena_strip(far_bank)
  assert(strip==RiverBank.arena_strip(far_bank),"The banks reuse two fixed meshes")
  var data=strip.surface_get_arrays(0)
  var vertices=data[Mesh.ARRAY_VERTEX]
  var normals=data[Mesh.ARRAY_NORMAL]
  var triangles=data[Mesh.ARRAY_INDEX]
  assert(vertices.size()==(RiverBank.ARENA_COLUMNS+1)*(RiverBank.ARENA_ROWS+1))
  assert(triangles.size()==RiverBank.ARENA_COLUMNS*RiverBank.ARENA_ROWS*6)
  var dry_edge=RiverBank.ARENA_FAR_START if far_bank else RiverBank.ARENA_NEAR_START
  var dry_points=0
  var bed_points=0
  var shore_min=INF
  var shore_max=-INF
  for index in vertices.size():
   var point=vertices[index]
   assert(data[Mesh.ARRAY_TEX_UV][index].is_equal_approx(Vector2(point.x,point.z)))
   assert(normals[index].y>.94 and point.y<=0 and point.y>=RiverBank.BED_HEIGHT-.0001,"Slopes have upward normals and bounded depth")
   if is_zero_approx(point.y):
    assert(is_equal_approx(point.z,dry_edge),"Every dry edge point meets the adjacent level floor")
    dry_points+=1
   if is_equal_approx(point.y,RiverBank.BED_HEIGHT):bed_points+=1
   if is_equal_approx(point.y,RiverBank.BED_HEIGHT*.25):
    shore_min=minf(shore_min,point.z)
    shore_max=maxf(shore_max,point.z)
  assert(dry_points==RiverBank.ARENA_COLUMNS+1 and bed_points==dry_points)
  assert(shore_max-shore_min>.6,"The waterline follows an irregular bank")

 var scenery=Scenery.new()
 scenery.batching_enabled=false
 var game=Rules.new()
 game.chapter=1
 var before=game.rng.state
 var origin=Vector3(35,.65,0)
 var context=scenery.combat_context(game,{"x":9,"y":4},{"x":10,"y":4})
 assert(context.landmarks.size()==2)
 var field=Node3D.new();root.add_child(field);scenery.landscape(field,game)
 var banks={}
 for bank in field.find_children("RiverBank*","MeshInstance3D",false,false):banks[bank.position]=bank.mesh
 var field_foam=field.find_children("RiverFoam*","MeshInstance3D",false,false)
 assert(not field_foam.is_empty())
 for foam in field_foam:
  assert(banks.has(foam.position))
  verify_foam_strip(foam,banks[foam.position],Scenery.MAP_WATER_LEVEL,Vector2.DOWN)
 var field_chain=field.get_node("CrossingChain")
 var field_middle=verify_crossing_chain(field_chain,0,-.07)
 var field_shape=field_chain.get_node("IronLinks").multimesh.mesh
 for plinth in field_chain.find_children("ChainPlinth*","MeshInstance3D",false,false):
  var bounds=plinth.global_transform*plinth.mesh.get_aabb()
  assert(bounds.end.x<4.5 or bounds.position.x>6.5,"Both map plinths stand outside the channel")
 var viewport=SubViewport.new();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var camera=Camera3D.new();viewport.add_child(camera);camera.current=true
 var director=preload("res://scripts/combat_camera.gd")
 var sizes=[Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]
 var board_center=Vector3((game.board_size().x-1)*.5,0,(game.board_size().y-1)*.5)
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=maxf(16,game.board_size().x+2)
 camera.position=board_center+Vector3(2.5,22,11.5);camera.look_at(board_center);camera.h_offset=2.0
 for dimensions in sizes:
  viewport.size=dimensions;await process_frame
  assert(Rect2(Vector2.ZERO,Vector2(dimensions)).grow(-12).has_point(camera.unproject_position(field_middle)))
 camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.h_offset=0
 for tile in [".","f","h","p","="]:
  var arena=Node3D.new();root.add_child(arena)
  context.terrain=tile
  scenery.battle_landscape(arena,origin,context)
  var bridge=tile=="="
  var water=arena.get_node("ArenaWater")
  var level=water.position.y-origin.y
  var foam=arena.find_children("RiverFoam*","MeshInstance3D",false,false)
  assert(foam.size()==(1 if bridge else 2))
  for index in foam.size():
   var far_bank=index==0
   var cached_level=-.055 if bridge else RiverBank.ARENA_WATER_LEVEL
   assert(foam[index].position==origin and foam[index].mesh==RiverBank.arena_foam_strip(far_bank,cached_level))
   verify_foam_strip(foam[index],RiverBank.arena_strip(far_bank),level,Vector2.RIGHT)
  var chain=arena.get_node("CrossingChain")
  var middle=verify_crossing_chain(chain,origin.y,water.position.y)
  assert(chain.get_node("IronLinks").multimesh.mesh==field_shape,"The field and close-up use the same iron links")
  var footing=chain.find_children("ChainPlinth*","MeshInstance3D",false,false)
  var near=footing[0].global_transform*footing[0].mesh.get_aabb()
  var far=footing[1].global_transform*footing[1].mesh.get_aabb()
  assert(near.position.z>origin.z+(-2.49 if bridge else RiverBank.ARENA_NEAR_START))
  assert(far.end.z<origin.z+RiverBank.ARENA_FAR_START)
  if tile in [".","="]:
   var frame=director.frame_pair(origin+Vector3.LEFT*1.6,origin+Vector3.RIGHT*1.6,"wide",false,bridge)
   camera.position=frame.anchor;camera.fov=frame.lens;camera.look_at(frame.focus)
   for size in sizes:
    viewport.size=size;await process_frame
    var screen=camera.unproject_position(middle)
    assert(Rect2(12,12,size.x-24,size.y*.71-12).has_point(screen),"The chain arcs across the river behind the fighters")
  var far_ground=arena.get_node("ArenaFarBankGround")
  assert(arena.get_node("ArenaFarBank").mesh==RiverBank.arena_strip(true))
  assert(is_equal_approx(far_ground.position.z+far_ground.mesh.size.y*.5,RiverBank.ARENA_FAR_START))
  assert(is_equal_approx(far_ground.position.y,origin.y))
  assert(arena.has_node("ArenaRailing")==bridge and arena.has_node("ArenaNearBank")!=bridge)
  var reeds=arena.find_children("ArenaBankReed*","MeshInstance3D",true,false)
  assert(reeds.size()==(0 if bridge else 14))
  if not bridge:
   assert(is_equal_approx(water.position.y,origin.y+RiverBank.ARENA_WATER_LEVEL) and is_equal_approx(water.position.z+water.mesh.size.y*.5,-3))
   var near_bank=arena.get_node("ArenaNearBank")
   assert(near_bank.mesh==RiverBank.arena_strip(false) and near_bank.position==origin)
   assert(near_bank.material_override==scenery.ground_material(arena.get_meta("arena_surface")))
  for reed in reeds:
   var offset=reed.position-origin
   assert(offset.is_equal_approx(RiverBank.arena_point(offset.x,3.0/RiverBank.ARENA_ROWS,false)) and reed.position.y>water.position.y)
   assert(reed.get_meta("plant_kind")==2 and reed.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
  for group in arena.get_children():
   if group.name.begins_with("ArenaTree") or group.name.begins_with("ArenaLandmark"):
    assert(is_equal_approx(group.position.y,origin.y) and group.position.z<RiverBank.ARENA_FAR_START,"Trees and towers stand on the far shore")
  var landmarks=arena.find_children("ArenaLandmark*","Node3D",false,false)
  assert(landmarks.size()==context.landmarks.size())
  for index in landmarks.size():
   assert(is_equal_approx(landmarks[index].position.x-origin.x,context.landmarks[index].x),"Planted towers retain their horizontal map relation")
  arena.free()
 viewport.free();field.free()
 assert(game.rng.state==before,"The river stage leaves the combat roll unchanged")
 print("PASS: two grounded Reed Crossing banks, 14 planted reeds, preserved bridge and water levels, and map-relative towers on dry ground")
 print("PASS: Reed Crossing’s interleaved iron links join both shore posts, clear the water and fit nine tactical and arena projections")
 print("PASS: Reed Crossing foam matches the source shoreline triangles on the map and in five arena floor configurations")

func verify_foam_strip(foam: MeshInstance3D,bank: ArrayMesh,level: float,flow: Vector2):
 assert(foam.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
 var paint=foam.material_override
 assert(paint.shader.resource_path=="res://assets/shaders/river_foam.gdshader")
 assert(paint.get_shader_parameter("flow_direction")==flow and is_equal_approx(paint.get_shader_parameter("foam_depth"),RiverBank.FOAM_DEPTH))
 var source=bank.surface_get_arrays(0)
 var vertices=source[Mesh.ARRAY_VERTEX]
 var heights={}
 for point in vertices:heights[Vector2(point.x,point.z)]=point.y
 var strip=foam.mesh.surface_get_arrays(0)
 var points=strip[Mesh.ARRAY_VERTEX]
 var samples=strip[Mesh.ARRAY_TEX_UV]
 var indices=strip[Mesh.ARRAY_INDEX]
 assert(not points.is_empty())
 for i in points.size():
  var point=points[i]
  assert(is_equal_approx(point.y,level+RiverBank.FOAM_HEIGHT_ABOVE_WATER))
  assert(is_equal_approx(samples[i].x,level-heights[Vector2(point.x,point.z)]))
 for offset in range(0,indices.size(),3):
  var a=samples[indices[offset]].x;var b=samples[indices[offset+1]].x;var c=samples[indices[offset+2]].x
  assert(maxf(a,maxf(b,c))>=-.00001 and minf(a,minf(b,c))<=RiverBank.FOAM_DEPTH+.00001)

func verify_crossing_chain(chain: Node3D,grade: float,water: float) -> Vector3:
 var batch=chain.get_node("IronLinks")
 var instances=batch.multimesh
 var anchors=chain.find_children("ChainAnchor*","MeshInstance3D",false,false)
 var posts=chain.find_children("ChainPost*","MeshInstance3D",false,false)
 var plinths=chain.find_children("ChainPlinth*","MeshInstance3D",false,false)
 assert([anchors.size(),posts.size(),plinths.size()]==[2,2,2])
 var local_bounds=func(node):return node.transform*node.mesh.get_aabb()
 for index in 2:
  var foot=plinths[index].global_transform*plinths[index].mesh.get_aabb()
  assert(foot.position.y<grade and foot.end.y>grade)
  assert(local_bounds.call(plinths[index]).intersects(local_bounds.call(posts[index])))
  assert(local_bounds.call(posts[index]).intersects(local_bounds.call(anchors[index])))
 var data=instances.buffer
 assert(instances.instance_count>=12 and instances.instance_count<=48 and data.size()==instances.instance_count*12)
 var previous=AABB();var previous_up=Vector3.ZERO;var middle=Vector3.ZERO
 for index in instances.instance_count:
  var offset=index*12
  var basis=Basis(Vector3(data[offset],data[offset+4],data[offset+8]),
   Vector3(data[offset+1],data[offset+5],data[offset+9]),Vector3(data[offset+2],data[offset+6],data[offset+10]))
  var position=Vector3(data[offset+3],data[offset+7],data[offset+11])
  var bound=Transform3D(basis,position)*instances.mesh.get_aabb()
  assert(basis.determinant()>0 and instances.custom_aabb.encloses(bound))
  assert(chain.global_position.y+bound.position.y>water)
  if index>0:
   assert(bound.intersects(previous) and absf(basis.y.normalized().dot(previous_up))<.13,"Neighboring links overlap and turn through a quarter turn")
  if index==0:assert(local_bounds.call(anchors[0]).has_point(position))
  if index==instances.instance_count-1:assert(local_bounds.call(anchors[1]).has_point(position))
  if index==instances.instance_count/2:middle=chain.to_global(position)
  previous=bound;previous_up=basis.y.normalized()
 assert(middle.y<anchors[0].global_position.y and middle.y<anchors[1].global_position.y)
 return middle

func verify_water_styles():
 var scenery=Scenery.new()
 scenery.batching_enabled=false
 var game=Rules.new()
 var baseline=scenery.water_material()
 var colors={}
 for theme in Scenery.WATER_STYLES:
  var style=Scenery.WATER_STYLES[theme]
  var paint=scenery.water_material(theme)
  assert(paint!=baseline and paint.shader==baseline.shader and paint==scenery.water_material(theme))
  for parameter in style:
   assert(paint.get_shader_parameter(parameter)==style[parameter],"Each water material receives the chapter's authored parameters")
  assert(is_equal_approx(style.flow_direction.length(),1.0) and style.wave_scale.x>0 and style.wave_scale.y>0)
  assert(style.crest_strength>0 and style.crest_strength+.15<1 and style.wave_speed>0)
  colors[style.deep_color]=true
 assert(colors.size()==6 and scenery.water_material("village")==baseline)
 assert(Scenery.WATER_STYLES.river.wave_speed>Scenery.WATER_STYLES.harbor.wave_speed and Scenery.WATER_STYLES.harbor.wave_speed>Scenery.WATER_STYLES.aqueduct.wave_speed)
 assert(Scenery.WATER_STYLES.harbor.wave_scale.y<Scenery.WATER_STYLES.river.wave_scale.y,"Harbor swells are broader and slower than river ripples")
 var sea=Scenery.WATER_STYLES.harbor
 var current=Scenery.WATER_STYLES.river
 assert(sea.wave_speed/sea.wave_scale.y<current.wave_speed/current.wave_scale.y)

 var wet_cells=0
 var arenas=0
 var before=game.rng.state
 for chapter in game.content.chapters.size():
  game.chapter=chapter
  var theme=game.info().environment
  var expected=scenery.water_material(theme)
  var map=Node3D.new();root.add_child(map);scenery.landscape(map,game)
  var markers=map.find_children("MapWater*","MeshInstance3D",true,false)
  var wet_map=0
  var crossings=0
  for row in game.info().map:
   wet_map+=row.count("~")
   crossings+=row.count("=")
  assert(markers.size()==wet_map+crossings)
  var deck=scenery.building_material(Scenery.BuildingFinish.DECK_WOOD)
  var planks=map.find_children("BridgePlank*","MeshInstance3D",true,false)
  assert(planks.size()==crossings*7 and planks.all(func(node):return node.material_override==deck),"Every tactical bridge uses the painted deck wood swatch")
  for node in markers:
   assert(node.material_override==expected and is_equal_approx(node.position.y,-.07),"Map tiles share water material while retaining their physical level")
  wet_cells+=markers.size()
  map.free()
  var samples=[]
  if theme in ["river","harbor","aqueduct"]:samples.append(".")
  if crossings>0:samples.append("=")
  for tile in samples:
   var arena=Node3D.new();root.add_child(arena)
   scenery.battle_landscape(arena,Vector3(35,0,0),{"environment":theme,"terrain":tile,"harbor_quay":theme=="harbor" and tile=="."})
   var water=arena.get_node("ArenaWater")
   assert(water.material_override==expected,"A combat cutaway uses its map's exact water resource")
   scenery.batcher.combine(arena)
   assert(arena.get_children().any(func(node):return node is MeshInstance3D and node.material_override==expected),"The material survives static batching")
   arena.free()
   arenas+=1
 assert(game.rng.state==before and wet_cells==250 and arenas==8)
 print("PASS: six chapter water palettes, ",wet_cells," tactical water cells, ",arenas," actual arena bindings and unchanged physical levels")
func verify_aqueduct_reservoir():
 var game=Rules.new();game.chapter=7
 var before=game.save_data("camp");var rng=game.rng.state
 var scenery=Scenery.new();scenery.batching_enabled=false
 var map=Node3D.new();root.add_child(map);scenery.landscape(map,game)
 var bank_group=map.get_node("AqueductReservoir")
 var water=bank_group.get_node("ReservoirWater")
 var size=game.board_size()
 var bounds=water.global_transform*water.mesh.get_aabb()
 var water_paint=scenery.water_material("aqueduct")
 assert(bounds.size.x>=72 and bounds.size.z>=72 and water.material_override==water_paint)
 assert(is_equal_approx(water.position.y,AqueductReservoir.WATER_LEVEL))
 var map_water=map.find_children("MapWater*","MeshInstance3D",false,false)
 assert(not map_water.is_empty())
 for cell in map_water:
  assert(cell.position.y>water.position.y and cell.material_override==water_paint)
 var silhouettes: Array[AABB]=[]
 var shore_points: Array[Vector3]=[]
 for side in [-1,1]:
  var bank=bank_group.get_node("WestBank" if side<0 else "EastBank")
  var grass=bank.get_node("GrassyBank")
  var mud=bank.get_node("WetShore")
  assert(grass.material_override==scenery.ground_material(0) and mud.material_override==scenery.ground_material(2))
  assert(grass.mesh==AqueductReservoir.bank_mesh(side,true) and mud.mesh==AqueductReservoir.bank_mesh(side,false))
  assert(is_equal_approx(bank.position.x,-.5 if side<0 else size.x-.5))
  var shoreline={}
  for part in [grass,mud]:
   var edges=part.mesh.surface_get_arrays(0)
   var points: PackedVector3Array=edges[Mesh.ARRAY_VERTEX]
   var normals: PackedVector3Array=edges[Mesh.ARRAY_NORMAL]
   assert(normals.size()==points.size() and edges[Mesh.ARRAY_INDEX].size()==6*AqueductReservoir.ROWS*(5 if part==grass else 2))
   for i in points.size():
    assert(normals[i].y>.90 and points[i].x*side>.75,"The gently sloped banks face up and stay outside the grid")
    if is_equal_approx(points[i].y,.045):
     if part==grass:shoreline[points[i]]=true
     else:assert(shoreline.has(points[i]),"The soil and grass mesh share the exact shoreline seam")
   var envelope=part.global_transform*part.mesh.get_aabb()
   assert(envelope.size.z>=76)
   silhouettes.append(envelope)
  for tree in bank.find_children("Conifer*","MeshInstance3D",false,false):
   silhouettes.append(tree.global_transform*tree.mesh.get_aabb())
  var trunks=bank.find_children("ConiferTrunk*","MeshInstance3D",false,false)
  assert(trunks.size()==3)
  var land=grass.mesh.surface_get_arrays(0)
  var triangles=land[Mesh.ARRAY_INDEX]
  var vertices=land[Mesh.ARRAY_VERTEX]
  for tree in trunks:
   var foot=tree.global_position-Vector3.UP*tree.mesh.height*.5
   var ray=foot+Vector3.UP
   var planted=false
   for i in range(0,triangles.size(),3):
    var hit=Geometry3D.ray_intersects_triangle(ray,Vector3.DOWN,grass.to_global(vertices[triangles[i]]),
     grass.to_global(vertices[triangles[i+1]]),grass.to_global(vertices[triangles[i+2]]))
    if hit!=null and hit.y>=foot.y and hit.y<foot.y+.095:planted=true
   assert(planted,"Each conifer's trunk intersects the grassy surface")
  shore_points.append(bank.to_global(AqueductReservoir.bank_point(0,AqueductReservoir.GRASS[0],side)))
 var camera_view=SubViewport.new();camera_view.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(camera_view)
 var camera=Camera3D.new();camera_view.add_child(camera);camera.current=true
 var center=Vector3((size.x-1)*.5,0,(size.y-1)*.5)
 var tactical=preload("res://scripts/tactical_camera.gd")
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.position=center+Vector3(2.5,22,11.5);camera.look_at(center)
 for dimensions in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
  camera_view.size=dimensions;await process_frame
  camera.size=16;camera.h_offset=2;camera.v_offset=0
  tactical.fit_home(camera,size)
  for point in shore_points:assert(camera_view.get_visible_rect().has_point(camera.unproject_position(point)))
  for row in size.y:
   for column in size.x:
    var tile=Vector3(column,0,row)
    var origin=camera.project_ray_origin(camera.unproject_position(tile))
    assert(silhouettes.all(func(box):return box.intersects_segment(origin,tile)==null),
     "The bank and trees leave a clear view to all tactical tile centers")
 var larger=Node3D.new();root.add_child(larger)
 AqueductReservoir.build(scenery,larger,Vector2i(18,42),168)
 var larger_bank=larger.get_node("AqueductReservoir/EastBank/GrassyBank")
 assert(larger_bank.mesh==AqueductReservoir.bank_mesh(1,true) and larger_bank.scale.z>2)
 assert(larger.get_node("AqueductReservoir/ReservoirWater").mesh.size==Vector2(168,168))
 scenery.batcher.combine(map)
 assert(map.get_children().filter(func(node):return node is MeshInstance3D and node.get_meta("static_batch",false) and node.material_override==water_paint).size()>=2)
 assert(game.save_data("camp")==before and game.rng.state==rng)
 camera_view.free();map.free();larger.free()
 print("PASS: Old Aqueduct's sloped reservoir banks join the field without blocking tile centers, scale to larger maps and reuse four ground meshes")
