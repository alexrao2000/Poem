extends SceneTree
const Rules=preload("res://scripts/rules.gd")
func _initialize():call_deferred("run")
func run():
 var g=Rules.new();var paths=0
 for chapter in range(12):
  g.chapter=chapter;g.start_battle()
  for unit in g.units:
   var before=g.rng.state;var position=g.pos(unit);var reachable=g.reachable(unit)
   for destination in reachable:
    var occupied=g.at(destination);var path=g.movement_path(unit,destination)
    if occupied!=null and occupied.id!=unit.id:
     assert(path.is_empty(),"A route cannot end on another unit");continue
    assert(not path.is_empty() and path[0]==position and path[-1]==destination)
    var cost=0
    for i in range(1,path.size()):
     assert(absi(path[i].x-path[i-1].x)+absi(path[i].y-path[i-1].y)==1,"Every step is orthogonal")
     assert(g.terrain(path[i]) not in ["#","~"],"Never travels through impassable terrain")
     var occupant=g.at(path[i]);assert(occupant==null or occupant.team==unit.team,"Never travels through enemy occupancy")
     cost+=2 if g.terrain(path[i]) in ["f","h"] else 1
    assert(cost==reachable[destination] and cost<=unit.move,"Route uses minimum weighted movement cost")
    paths+=1
   assert(g.rng.state==before and g.pos(unit)==position,"Route queries are pure")
   assert(g.movement_path(unit,Vector2i(-1,-1)).is_empty())
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/ashen-movement-ui.json";root.add_child(app);await process_frame
 app.game.new_campaign();app.game.start_battle();app.make_map();app.show_battle();await process_frame
 var unit=app.game.units[0];var start=app.game.pos(unit);var destination=start
 for tile in app.game.reachable(unit):
  if app.game.at(tile)==null and app.game.movement_path(unit,tile).size()>=3:destination=tile;break
 assert(destination!=start)
 app.selected=unit;app.preview_route(destination)
 assert(app.route_preview.get_child_count()==app.game.movement_path(unit,destination).size()+3,"Preview traces every segment and outlines destination")
 app.click_tile(destination);await process_frame
 app.click_tile(start);assert(app.game.pos(unit)==destination,"Clicks during movement cannot issue another action")
 assert(app.busy and app.moving_id==unit.id,"Map actions lock while movement animates")
 assert(app.game.pos(unit)==destination,"Player move commits once before presentation")
 assert(app.unit_nodes[unit.id].position.distance_to(Vector3(destination.x,0,destination.y))>.01,"Visual travels from old position")
 while app.busy:await process_frame
 assert(app.unit_nodes[unit.id].position==Vector3(destination.x,0,destination.y))
 var actor=app.unit_nodes[unit.id]
 assert(actor.sprite.get_parent()==actor and actor.marker.get_parent()==actor and actor.health.get_parent()==actor,"Sprite, ground marker and HP travel in one group")
 assert(actor.player.state=="idle" and app.map_facings[unit.id]==actor.player.facing,"Walk returns to idle while retaining its last facing")
 app.cancel_selection();assert(app.game.pos(unit)==start and app.unit_nodes[unit.id].position==Vector3(start.x,0,start.y),"Cancel restores both simulation and visuals")
 assert(app.sprites.size()==app.game.units.size())
 for other in app.game.units:
  if other.id!=unit.id:other.hp=0
 app.refresh_pieces();await process_frame
 actor=app.unit_nodes[unit.id]
 for zoom in [12.0,16.0,22.0]:
  app.camera.size=zoom
  var bounds=actor.screen_bounds(app.camera)
  assert(bounds.size.x>10 and bounds.size.y>10,"Picking uses projected sprite dimensions")
  assert(app.pick_map_unit(bounds.position+bounds.size*Vector2(.5,.2))==unit,"Upper body remains selectable at different map zooms")
  assert(app.pick_map_unit(bounds.end+Vector2(15,15))==null,"Outside sprite bounds falls through to terrain picking")
 for recruit in app.game.roster:
  var data=recruit.duplicate(true);data.team="player";data.acted=false
  var visual=app.MapUnit.new();app.pieces.add_child(visual);visual.configure(app.map_catalog,data)
  assert(visual.visual_id=="unit."+data.job.to_lower(),"Every recruit uses its own class animation set")
  visual.queue_free()
 app.queue_free();await process_frame
 print("PASS: ",paths," legal weighted routes across 12 maps, movement animation, action lock and undo restoration")
 quit()
