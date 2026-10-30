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
func _initialize():call_deferred("run")
func surface_geometry():
 var scenery=Scenery.new();var parent=Node3D.new();root.add_child(parent)
 scenery.bridge(parent,Vector3.ZERO)
 for plank in parent.get_child(0).get_children().slice(0,7):
  var bounds=plank.mesh.get_aabb()
  assert(is_equal_approx(plank.position.y+bounds.end.y*plank.scale.y,MapSurface.height_for("=")),"Bridge deck matches walkable height")
 var shrine=Node3D.new();parent.add_child(shrine);scenery.sanctuary(shrine,Vector3.ZERO)
 for cross in shrine.get_children().slice(1):
  assert(is_equal_approx(cross.position.y+cross.mesh.get_aabb().end.y*cross.scale.y,MapSurface.height_for("+")),"Sanctuary crest matches walkable height")
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
func run():
 surface_geometry()
 verify_ridges()
 verify_rocks()
 var game=Rules.new();var seen={}
 var scenery=Scenery.new();scenery.batching_enabled=false
 var previous_paint: ShaderMaterial
 var bridge_water=0
 for chapter in range(12):
  game.chapter=chapter;var state=game.rng.state;var board=game.board_size();var theme=game.info().environment
  var world=Node3D.new();root.add_child(world);scenery.landscape(world,game)
  var floors=world.get_children().filter(func(node):return node is MeshInstance3D and node.name.begins_with("MapGround"))
  assert(not floors.is_empty())
  var paint=floors[0].material_override
  assert(paint!=previous_paint,"Each chapter owns its terrain control texture")
  previous_paint=paint
  assert(paint.get_shader_parameter("blend_edges")==true,"Tactical ground uses the blending shader")
  var control=paint.get_shader_parameter("surface_weights").get_image()
  assert(control.get_size()==board+Vector2i.ONE*4,"Control map includes grass padding around the board")
  assert(control.get_pixel(0,0)==Color(1,0,0,0) and control.get_pixel(control.get_width()-1,control.get_height()-1)==Color(1,0,0,0),"Landscape beyond the board resolves to grass")
  var floor_cells={};var water_cells={}
  for floor in floors:
   assert(floor.material_override==paint,"All ground cells share one batchable material")
   floor_cells[Vector2i(roundi(floor.position.x),roundi(floor.position.z))]=true
  for water in world.get_children().filter(func(node):return node is MeshInstance3D and node.name.begins_with("MapWater")):
   water_cells[Vector2i(roundi(water.position.x),roundi(water.position.z))]=water.position.y
  for y in range(board.y):
   for x in range(board.x):
    var cell=Vector2i(x,y);var symbol=game.terrain(cell);var weights=control.get_pixel(x+2,y+2)
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
 for theme in ["mountain","road","forest","river","village","harbor","castle"]:
  var stage=Node3D.new();root.add_child(stage);var center=Vector3(35,0,0)
  scenery.battle_landscape(stage,center,{"environment":theme})
  var layers=stage.get_children().filter(func(node):return node.name.begins_with("ArenaRidge"))
  assert(layers.size()==(0 if theme in ["harbor","castle"] else 3),"Only outdoor land arenas receive layered terrain")
  for layer in layers:assert(layer.position==center and layer.material_override.vertex_color_use_as_albedo and layer.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Distant terrain aligns with the arena and avoids consuming fighter shadow-map coverage")
  stage.free()
 assert(game.rng.state==rng,"Distant landscape generation consumes no campaign random state")

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
