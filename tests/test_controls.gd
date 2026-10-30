extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")
func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-controls.json";root.add_child(app);await process_frame
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
 app.game.start_battle();app.make_map();app.show_battle();unit=app.game.units[0];enemy=app.game.living("enemy")[0]
 unit.x=8;unit.y=4;enemy.x=9;enemy.y=4
 for dimensions in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions
  for state in ["company","unit","forecast","enemy"]:
   app.selected=null if state=="company" else enemy if state=="enemy" else unit
   app.target=enemy if state=="forecast" else null;app.update_side();await process_frame;await process_frame
   var panel=app.side.get_parent();var frame=panel.get_global_rect()
   assert(frame.end.y<=dimensions.y-20,"Battle sidebar fits the shorter desktop window")
   assert(frame.size.y<=app.side.get_combined_minimum_size().y+32,"Action card fits its contents instead of covering an empty column")
   if state=="company":assert(frame.size.y<300,"Unselected map leaves most of the right edge visible")
   for child in app.side.get_children():assert(child.get_global_rect().end.y<=frame.end.y-10,"Every action remains inside its panel without scrolling")
   assert(app.battle_hint.get_line_count()==1,"Contextual map hint stays on one line")
  app.selected=unit;app.target=enemy;app.update_side()
  var saved=app.game.save_data("battle").duplicate(true);var selection=app.selected;var position=app.camera.transform
  app.show_battle_menu();await process_frame;await process_frame
  assert(app.screen=="battle_menu" and app.selected==selection,"Opening the menu preserves tactical selection")
  var menu_frame=app.battle_menu.get_node("MenuFrame").get_global_rect()
  assert(menu_frame.position.x>=0 and menu_frame.position.y>=0 and menu_frame.end.x<=dimensions.x and menu_frame.end.y<=dimensions.y,"Battle menu stays within each desktop viewport")
  for child in app.battle_menu.get_node("MenuFrame").find_children("*","Control",true,false):assert(menu_frame.grow(1).encloses(child.get_global_rect()),"Full control guide and all menu actions fit the window")
  var buttons=app.battle_menu.find_children("*","Button",true,false)
  assert(buttons.size()==5,"All existing save, transfer, options and council routes remain available")
  for button in buttons:assert(button.get_node(button.focus_next) in buttons and button.get_node(button.focus_previous) in buttons,"Keyboard focus cannot escape to the battlefield behind the menu")
  key.keycode=KEY_SPACE;app._unhandled_input(key)
  assert(app.game.save_data("battle")==saved and app.camera.transform==position,"Menu input cannot end the phase or move the camera")
  key.keycode=KEY_ESCAPE;app._input(key)
  assert(app.screen=="battle" and app.selected==selection and app.target==enemy,"Escape resumes the same forecast")
 app.target=null;app.selected=unit;app.update_side()
 var pending=app.game.pos(unit)
 for tile in app.game.reachable(unit):
  if app.game.at(tile)==null:pending=tile;break
 app.click_tile(pending)
 while app.busy:await process_frame
 var moved=app.game.pos(unit);var undo_origin=app.origin
 app.show_battle_menu();app.close_battle_menu()
 assert(app.game.pos(unit)==moved and app.origin==undo_origin,"Opening and closing the menu preserves an uncommitted move")
 app.cancel_selection();assert(app.game.pos(unit)==Vector2i(8,4),"Undo still works after resuming from the menu")
 app.busy=true;app.show_battle_menu();assert(app.screen=="battle" and app.battle_menu==null,"Menu cannot interrupt an action")
 app.busy=false;app.settings_path="/private/tmp/poem-controls-settings.json"
 for command in ["Save","Transfer code","Options / audio","War council (restart map)"]:
  app.show_battle_menu()
  var button=app.battle_menu.find_children("*","Button",true,false).filter(func(value):return value.text==command)[0]
  button.pressed.emit();await process_frame
  if command=="Save":assert(app.screen=="battle" and FileAccess.file_exists(app.save_path),"Menu Save writes the local battle save")
  elif command=="Transfer code":
   assert(app.screen=="save_transfer" and app.transfer_text.text.begins_with("POEM1:"),"Menu transfer exports the live battle")
   app.close_save_transfer();await process_frame
  elif command=="Options / audio":
   assert(app.screen=="options" and app.options_return=="battle","Menu options retain their return route")
   app.close_options();await process_frame;assert(app.screen=="battle")
  else:
   if app.screen=="dialogue":app.finish_dialogue();await process_frame
   assert(app.screen=="camp","Menu council returns to preparation after any unseen chapter briefing")
 for player in app.sfx_players:player.stop()
 app.music.stop();await create_timer(.15).timeout
 await Shutdown.dispose(app);await process_frame
 print("PASS: keyboard cursor bounds, ready-unit cycling, movement undo, wait, forecast confirmation and key routing")
 quit()
