extends SceneTree
const Reach=preload("res://scripts/action_range.gd")
const Rules=preload("res://scripts/rules.gd")
func _initialize():call_deferred("run")

func covered(mesh,point: Vector2i) -> bool:
 if mesh==null:return false
 var vertices=mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 for i in range(0,vertices.size(),3):
  var triangle=PackedVector2Array()
  for j in range(3):triangle.append(Vector2(vertices[i+j].x,vertices[i+j].z))
  if Geometry2D.is_point_in_polygon(Vector2(point),triangle):return true
 return false

func check_overlay(app):
 var unit=app.selected;var moves=app.game.reachable(unit) if app.origin==null else {app.game.pos(unit):0}
 var all=Reach.tiles(app.game,unit,moves);var healing=unit.weapon=="staff"
 var overlay=app.markers.get_node_or_null("HealingReach" if healing else "ActionReach")
 for y in range(app.game.board_size().y):
  for x in range(app.game.board_size().x):
   var point=Vector2i(x,y)
   assert(covered(overlay,point)==(all.has(point) and not moves.has(point)),"Reach geometry shows exactly the equipped action area outside blue movement cells")
 if overlay!=null:
  for vertex in overlay.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
   assert(vertex.y>=app.map_height(Vector2i(roundi(vertex.x),roundi(vertex.z)))+.0349,"Action reach follows raised terrain")

func run():
 var game=Rules.new();var cases=0
 for chapter in range(12):
  game.chapter=chapter;game.start_battle();var source=game.living("player")[0]
  var saved=game.save_data("battle").duplicate(true);var rng=game.rng.state
  for item in game.equipment:
   var unit=source.duplicate(true);unit.weapon=item.kind;unit.item=item.id;game.normalize_equipment(unit)
   for moved in [false,true]:
    var origins={game.pos(unit):0} if moved else game.reachable(unit)
    var actual=Reach.tiles(game,unit,origins);var legal=[]
    for origin in origins:
     if game.movement_path(unit,origin).size()>0:legal.append(origin)
    for y in range(game.board_size().y):
     for x in range(game.board_size().x):
      var point=Vector2i(x,y);var expected=false
      if game.terrain(point) not in ["#","~"]:
       for origin in legal:
        var probe=unit.duplicate();probe.x=origin.x;probe.y=origin.y
        var target={"id":"range_test_target","team":unit.team if item.kind=="staff" else "enemy","x":x,"y":y,"hp":1,"max_hp":2}
        if game.can_heal(probe,target) if item.kind=="staff" else game.can_attack(probe,target):expected=true;break
      assert(actual.has(point)==expected,"Preview agrees with actual attack/healing rules from legal stopping cells")
    cases+=1
  assert(game.save_data("battle")==saved and game.rng.state==rng,"Range calculation never mutates positions, equipment, saves or RNG")
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-action-range.json";root.add_child(app);await process_frame
 app.game.start_battle();app.make_map();app.show_battle();app.preferences.values.auto_end=false
 var unit=app.game.units[0];app.selected=unit;app.highlight();await process_frame;check_overlay(app)
 var destination=app.game.pos(unit)
 for point in app.game.reachable(unit):
  if app.game.at(point)==null:destination=point;break
 app.click_tile(destination)
 while app.busy:await process_frame
 await process_frame;check_overlay(app)
 assert(app.origin!=null,"Actual move narrows the action preview to its new position")
 app.cancel_selection();app.selected=unit;app.highlight();await process_frame;check_overlay(app)
 app.game.chapter=11;app.game.start_battle();app.make_map();app.show_battle()
 for weapon in ["bow","staff"]:
  unit=app.game.living("player").filter(func(value):return value.weapon==weapon)[0]
  app.selected=unit;app.origin=app.game.pos(unit);app.highlight();app.update_side();await process_frame;check_overlay(app)
  var reach=Reach.tiles(app.game,unit,{app.game.pos(unit):0})
  if weapon=="bow":
   for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:assert(not reach.has(app.game.pos(unit)+step),"Stationary bow keeps its adjacent blind spot")
  else:assert("Green" in app.battle_hint.text and app.markers.get_node_or_null("ActionReach")==null,"Staff reach is green and never presented as an attack")
 app.origin=null;unit.acted=true;app.highlight();await process_frame
 assert(app.markers.get_node_or_null("ActionReach")==null and app.markers.get_node_or_null("HealingReach")==null,"Spent units show no actionable preview")
 for player in app.sfx_players:player.stop()
 app.music.stop();await create_timer(.15).timeout;app.queue_free();await process_frame
 print("PASS: ",cases," weapon/chapter/movement previews agree with action rules, exact overlay coverage, raised terrain, move/undo, bow blind spot and staff styling")
 quit()
