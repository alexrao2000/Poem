extends SceneTree
const Rules=preload("res://scripts/rules.gd")
const Tactics=preload("res://scripts/tactics.gd")
const Tracked=preload("res://scripts/tracked_threats.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")
func covered(mesh,point: Vector2i) -> bool:
 if mesh==null:return false
 var vertices=mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 for index in range(0,vertices.size(),3):
  var triangle=PackedVector2Array()
  for offset in range(3):triangle.append(Vector2(vertices[index+offset].x,vertices[index+offset].z))
  if Geometry2D.is_point_in_polygon(Vector2(point),triangle):return true
 return false
func inspect_overlay(app):
 var expected={}
 for unit in app.tracked_threats.units:expected.merge(app.tactics.threatened_tiles(app.game,unit))
 var tracked=app.markers.get_node_or_null("TrackedRange");var danger=app.markers.get_node_or_null("DangerRange")
 for y in range(app.game.board_size().y):
  for x in range(app.game.board_size().x):
   var tile=Vector2i(x,y)
   assert(covered(tracked,tile)==expected.has(tile),"Purple geometry matches only the tracked enemies’ actual threat areas")
   if expected.has(tile):assert(not covered(danger,tile),"Tracked tiles replace the red fill rather than stacking a second threat fill")
 if tracked!=null:
  for vertex in tracked.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
   assert(vertex.y>=app.map_height(Vector2i(roundi(vertex.x),roundi(vertex.z)))+.0279,"Tracked ranges follow raised ground")
func settle():
 await process_frame;await process_frame
func run():
 var game=Rules.new();game.start_battle();var tracker=Tracked.new();var tactics=Tactics.new()
 var before=game.save_data("battle").duplicate(true);var enemies=game.living("enemy")
 assert(not tracker.toggle(game,null) and not tracker.toggle(game,game.units[0]) and not tracker.toggle(game,enemies[0].duplicate(true)))
 assert(tracker.toggle(game,enemies[0]) and tracker.toggle(game,enemies[1]))
 var expected=tactics.threatened_tiles(game,enemies[0]);expected.merge(tactics.threatened_tiles(game,enemies[1]))
 assert(tracker.tiles(game,tactics)==expected and game.save_data("battle")==before,"Range annotations do not change the campaign or RNG")
 var old_enemy=enemies[0];game.start_battle()
 assert(old_enemy==game.living("enemy")[0] and not is_same(old_enemy,game.living("enemy")[0]))
 assert(tracker.tiles(game,tactics).is_empty() and tracker.units.is_empty(),"Identical new-attempt IDs/stats never inherit stale tracking")
 root.size=Vector2i(1440,900)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-tracked-threats.json"
 root.add_child(app);await process_frame
 app.game.start_battle();app.make_map();app.show_battle();app.preferences.values.auto_end=false
 before=app.game.save_data("battle").duplicate(true);enemies=app.game.living("enemy")
 app.click_tile(app.game.pos(enemies[0]));app.ui.find_child("TrackEnemyRange",true,false).pressed.emit()
 assert(app.tracked_threats.contains(enemies[0]) and app.ui.find_child("TrackEnemyRange",true,false).text.ends_with("on"))
 app.cancel_selection();assert(app.markers.get_node_or_null("TrackedRange")!=null and not app.show_danger)
 app.click_tile(app.game.pos(enemies[1]));var key=InputEventKey.new();key.pressed=true;key.keycode=KEY_T
 app._input(key);assert(app.tracked_threats.units.size()==2)
 key.echo=true;app._input(key);assert(app.tracked_threats.units.size()==2);key.echo=false
 inspect_overlay(app);app.toggle_danger();assert(app.show_danger);inspect_overlay(app)
 app.toggle_danger();inspect_overlay(app)
 assert(app.game.save_data("battle")==before)
 app.cancel_selection();var ally=app.game.units[0];app.click_tile(app.game.pos(ally))
 app._input(key);assert(app.tracked_threats.units.size()==2,"Tracking shortcut cannot mark an ally")
 var destination=app.game.pos(ally)
 for tile in app.game.reachable(ally):
  if app.game.at(tile)==null:destination=tile;break
 app.click_tile(destination)
 while app.busy:await process_frame
 inspect_overlay(app);assert(app.tracked_threats.units.size()==2)
 app.cancel_selection();inspect_overlay(app);assert(app.game.save_data("battle")==before,"Movement undo retains annotations and exact campaign state")
 app.show_options("battle");app._input(key);app.close_options();assert(app.tracked_threats.units.size()==2)
 app.selected=enemies[0];app.update_side();app.busy=true;app.toggle_tracked_threat();assert(app.tracked_threats.units.size()==2);app.busy=false
 app.game.phase="enemy";app.toggle_tracked_threat();assert(app.tracked_threats.units.size()==2)
 var choice=app.tactics.plan(app.game,enemies[1]);assert(choice.position!=app.game.pos(enemies[1]))
 assert(app.game.move_unit(enemies[1],choice.position));app.refresh_pieces();app.highlight();inspect_overlay(app)
 app.game.phase="player";enemies[0].hp=0;app.selected=null;app.highlight();app.update_side()
 assert(app.tracked_threats.units.size()==1 and app.tracked_threats.contains(enemies[1]));inspect_overlay(app)
 app.click_tile(app.game.pos(enemies[1]));app._input(key)
 assert(app.tracked_threats.units.is_empty() and app.markers.get_node_or_null("TrackedRange")==null)
 for chapter in range(12):
  app.game.trials.flags.reset_pressure=true;app.game.trials.pressure=1
  app.game.chapter=chapter;app.game.start_battle();app.make_map();app.show_battle()
  var enemy=app.game.living("enemy")[0];app.click_tile(app.game.pos(enemy));app.toggle_tracked_threat()
  for dimensions in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
   app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions;await settle()
   var panel=app.side.get_parent().get_global_rect()
   if panel.end.y>dimensions.y-20:
    print("Overflow chapter=",chapter," size=",dimensions," panel=",panel)
    for child in app.side.get_children():print(child.get_class()," ",child.get_global_rect()," ",child.text if child is Label or child is Button else "")
   assert(panel.end.y<=dimensions.y-20,"Commander details and both range controls fit at every supported size")
   for button in app.side.find_children("*","Button",true,false):assert(panel.grow(1).encloses(button.get_global_rect()),"Both range buttons remain within the sidebar width")
   assert(app.battle_hint.get_line_count()==1)
  inspect_overlay(app)
  app.game.start_battle();app.make_map();app.show_battle()
  assert(app.tracked_threats.units.is_empty() and app.markers.get_node_or_null("TrackedRange")==null)
 await Shutdown.dispose(app);await process_frame
 print("PASS: independent tracked threat areas, actual pointer/keyboard controls, held-key/busy/menu guards, movement/undo updates, exact overlay coverage, death/retry cleanup, raised ground and 36 commander layouts without campaign/RNG changes")
 quit()
