extends SceneTree
# The readout shares profiles with simulation. Exercise actual cover, healing,
# hover/keyboard inspection, off-board hiding and cinematic visibility restore.
const Rules=preload("res://scripts/rules.gd")
const MapSurface=preload("res://scripts/map_surface.gd")
const MapOverlay=preload("res://scripts/map_overlay.gd")
const Scenery=preload("res://scripts/scenery.gd")
const RiverBank=preload("res://scripts/river_bank.gd")
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
 var game=Rules.new();var seen={}
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
 app.queue_free();await process_frame
 print("PASS: nine terrain profiles across twelve maps, real movement/cover/healing values, cursor readout and visibility restoration")
 quit()
