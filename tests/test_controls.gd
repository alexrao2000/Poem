extends SceneTree
func _initialize():call_deferred("run")
func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/ashen-controls.json";root.add_child(app);await process_frame
 app.game.start_battle();app.make_map();app.show_battle();app.preferences.values.auto_end=false;app.preferences.values.combat="map"
 app.cycle_ready_ally(1);assert(app.selected.id=="lyra" and app.cursor_visible,"Cycle begins with first ready ally")
 app.cycle_ready_ally(1);assert(app.selected.id=="oren")
 app.selected.acted=true;app.cycle_ready_ally(1);assert(app.selected.id=="lyra","Cycle excludes allies that have acted")
 app.move_map_cursor(Vector2i(-100,-100));assert(app.cursor_tile==Vector2i.ZERO,"Cursor clamps to board")
 var before=app.cursor_tile;app.busy=true;app.move_map_cursor(Vector2i.RIGHT);assert(app.cursor_tile==before,"Busy phases ignore cursor movement")
 app.busy=false
 var unit=app.selected;var destination=app.game.pos(unit)
 for tile in app.game.reachable(unit):
  if app.game.at(tile)==null:destination=tile;break
 var origin=app.game.pos(unit);app.cursor_tile=destination;app.activate_map_cursor()
 while app.busy:await process_frame
 assert(app.game.pos(unit)==destination and app.origin==origin,"Keyboard selection uses normal validated movement")
 app.cycle_ready_ally(1);assert(app.game.pos(unit)==origin,"Cycling restores uncommitted movement")
 app.selected=unit;app.cursor_tile=origin;app.wait_action();await process_frame
 assert(unit.acted and app.game.phase=="player","Wait commits action without forced phase when disabled")
 app.game.start_battle();app.make_map();app.show_battle();unit=app.game.units[0]
 var enemy=app.game.living("enemy")[0];unit.x=8;unit.y=4;enemy.x=9;enemy.y=4
 app.selected=unit;app.cursor_tile=app.game.pos(enemy);app.cursor_visible=true;app.activate_map_cursor()
 assert(app.target==enemy and not unit.acted,"First confirmation opens forecast")
 app.activate_map_cursor()
 while app.busy:await process_frame
 assert(unit.acted,"Second confirmation resolves the forecasted attack")
 # Actual key routing reaches cursor movement and ready-unit cycling.
 var key=InputEventKey.new();key.pressed=true;key.keycode=KEY_E;app._input(key)
 assert(app.selected!=null and not app.selected.acted)
 var old=app.cursor_tile;key.keycode=KEY_UP;app._input(key);assert(app.cursor_tile.y==maxi(0,old.y-1))
 for player in app.sfx_players:player.stop()
 app.music.stop();await create_timer(.15).timeout
 app.queue_free();await process_frame
 print("PASS: keyboard cursor bounds, ready-unit cycling, movement undo, wait, forecast confirmation and key routing")
 quit()
