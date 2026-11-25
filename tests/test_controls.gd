extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")
func place_duel(app,unit,enemy):
 for pair in [[unit,Vector2i(8,4)],[enemy,Vector2i(9,4)]]:
  var blocker=app.game.at(pair[1]);var previous=app.game.pos(pair[0])
  if blocker!=null and blocker.id!=pair[0].id:blocker.x=previous.x;blocker.y=previous.y
  pair[0].x=pair[1].x;pair[0].y=pair[1].y
 app.refresh_pieces()
func verify_downed_navigation(app):
 app.game.death_door=true
 app.game.start_battle();app.make_map()
 app.selected=null;app.target=null;app.origin=null;app.show_battle()
 var lyra=app.game.living("player").filter(func(unit):return unit.id=="lyra")[0]
 var oren=app.game.living("player").filter(func(unit):return unit.id=="oren")[0]
 var sera=app.game.living("player").filter(func(unit):return unit.id=="sera")[0]
 var field=app.game.DeathDoor.drop_positions(app.game,lyra)[0]
 sera.x=field.x;sera.y=field.y
 for patient in [oren,sera]:
  patient.hp=0
  app.game.DeathDoor.fall(app.game,patient)
 sera.bleed_turns=1
 app.refresh_pieces();app.update_side()
 var old_size=root.size
 var old_scale=root.content_scale_size
 var disk=FileAccess.get_file_as_string(app.save_path)
 var armed=InputEventKey.new();armed.keycode=KEY_K;armed.pressed=true
 for dimensions in [Vector2i(720,640),Vector2i(1440,900)]:
  root.size=dimensions;root.content_scale_size=dimensions
  app.cursor_visible=false
  await process_frame;await process_frame
  var button=app.side.find_child("NextDownedAlly",true,false)
  assert(button!=null and root.get_visible_rect().encloses(button.get_global_rect()))
  var saved=app.game.save_data("battle").duplicate(true)
  button.pressed.emit()
  assert(app.cursor_tile==app.game.pos(sera) and app.terrain_card.tile==app.cursor_tile)
  armed.echo=true;app._input(armed);assert(app.cursor_tile==app.game.pos(sera))
  armed.echo=false;app._input(armed);assert(app.cursor_tile==app.game.pos(oren))
  app.busy=true;app._input(armed);assert(app.cursor_tile==app.game.pos(oren))
  app.busy=false;app._input(armed);assert(app.cursor_tile==app.game.pos(sera))
  assert(app.selected==null and app.game.save_data("battle")==saved and FileAccess.get_file_as_string(app.save_path)==disk)
 assert(app.game.DeathDoor.rescue(app.game,lyra,sera))
 app.refresh_pieces();app.update_side();app.cursor_visible=false
 app._input(armed);assert(app.cursor_tile==app.game.pos(oren))
 app._input(armed);assert(app.cursor_tile==app.game.pos(lyra))
 for patient in [oren,sera]:
  patient.hp=1
  app.game.DeathDoor.recover(app.game,patient)
 app.refresh_pieces();app.update_side()
 assert(app.side.find_child("NextDownedAlly",true,false)==null)
 root.size=old_size;root.content_scale_size=old_scale
 print("PASS: downed ally cycling visits urgent patients first, sees carried allies, and preserves the battle")

func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-controls.json";root.add_child(app);await process_frame
 app.game.start_battle();app.make_map();app.show_battle();app.preferences.values.auto_end=false;app.preferences.values.combat="map"
 var repeated=InputEventKey.new();repeated.pressed=true;repeated.echo=true
 var untouched=app.game.save_data("battle").duplicate(true);var inspection=app.game.units[0];app.selected=inspection
 for command in [KEY_R,KEY_SPACE,KEY_ESCAPE]:
  repeated.keycode=command;app._unhandled_input(repeated)
  assert(not app.busy and not app.show_danger and app.selected==inspection and app.game.save_data("battle")==untouched,"Held battle commands do not toggle ranges, end a phase or discard a selection")
 repeated.echo=false;repeated.keycode=KEY_R;app._unhandled_input(repeated);assert(app.show_danger)
 app._unhandled_input(repeated);assert(not app.show_danger,"Fresh range presses still toggle normally")
 app.selected=null
 var figures=app.unit_nodes.duplicate()
 app.cycle_ready_ally(1);assert(app.selected.id=="lyra" and app.cursor_visible,"Cycle begins with first ready ally")
 app.cycle_ready_ally(1);assert(app.selected.id=="oren")
 assert(app.unit_nodes==figures,"Switching between ready allies keeps the existing figures")
 app.selected.acted=true;app.cycle_ready_ally(1);assert(app.selected.id=="lyra","Cycle excludes allies that have acted")
 app.toggle_danger()
 var cursor=app.markers.get_node("MapCursor")
 var range_layer=app.markers.get_node("MovementRange")
 var danger_layer=app.markers.get_node("DangerRange")
 var range_mesh=range_layer.mesh;var start=app.cursor_tile;var step=Vector2i.ZERO
 var reachable=app.game.reachable(app.selected)
 for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
  if reachable.has(start+direction) and app.game.at(start+direction)==null:step=direction;break
 assert(step!=Vector2i.ZERO)
 cursor.clock=.7
 var before_cursor=app.game.save_data("battle").duplicate(true)
 app.move_map_cursor(step)
 assert(app.markers.get_node("MapCursor")==cursor and is_equal_approx(cursor.clock,.7),"Moving the cursor retains its animation clock")
 assert(cursor.position==app.map_position(start+step) and app.route_preview.get_child_count()==1 and app.terrain_card.tile==start+step)
 assert(app.markers.get_node("MovementRange")==range_layer and range_layer.mesh==range_mesh,"Selection keeps its existing range overlay as the cursor moves")
 assert(app.markers.get_node("DangerRange")==danger_layer,"Enemy threat ink is unchanged while browsing destinations")
 app.move_map_cursor(-step)
 assert(app.route_preview.get_child_count()==0 and cursor.position==app.map_position(start))
 assert(app.game.save_data("battle")==before_cursor,"Moving the map cursor leaves the campaign untouched")
 app.toggle_danger()
 app.move_map_cursor(Vector2i(-100,-100));assert(app.cursor_tile==Vector2i.ZERO,"Cursor clamps to board")
 var before=app.cursor_tile;app.busy=true;app.move_map_cursor(Vector2i.RIGHT);assert(app.cursor_tile==before,"Busy phases ignore cursor movement")
 app.busy=false
 var unit=app.selected;var destination=app.game.pos(unit)
 for tile in app.game.reachable(unit):
  if app.game.at(tile)==null:destination=tile;break
 var origin=app.game.pos(unit);app.cursor_tile=destination;app.activate_map_cursor()
 while app.busy:await process_frame
 assert(app.game.pos(unit)==destination and app.origin==origin,"Keyboard selection uses normal validated movement")
 app.cycle_ready_ally(1);assert(app.game.pos(unit)==origin and app.unit_nodes[unit.id].position==app.map_position(origin),"Cycling restores uncommitted movement and its map figure")
 app.selected=unit;app.cursor_tile=origin;app.wait_action();await process_frame
 assert(unit.acted and app.game.phase=="player","Wait commits action without forced phase when disabled")
 app.game.start_battle();app.make_map();app.show_battle();unit=app.game.units[0]
 var enemy=app.game.living("enemy")[0];place_duel(app,unit,enemy)
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
 place_duel(app,unit,enemy)
 for dimensions in [Vector2(720,640),Vector2(720,960),Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions
  for state in ["company","unit","forecast","enemy"]:
   app.selected=null if state=="company" else enemy if state=="enemy" else unit
   app.target=enemy if state=="forecast" else null;app.update_side();await process_frame;await process_frame
   var panel=app.side.get_parent();var frame=panel.get_global_rect()
   assert(frame.end.y<=dimensions.y-20,"Battle sidebar fits the shorter desktop window")
   assert(frame.size.y<=app.side.get_combined_minimum_size().y+32,"Action card fits its contents instead of covering an empty column")
   if state=="company":assert(frame.size.y<300,"Unselected map leaves most of the right edge visible")
   else:
    var identity=app.side.find_child("SelectedUnitName",true,false)
    assert(identity.text==app.selected.name and identity.tooltip_text==app.selected.name)
    var font=identity.get_theme_font("font");var font_size=identity.get_theme_font_size("font_size")
    assert(identity.get_visible_line_count()==1 and identity.size.y>=font.get_height(font_size),
     "The selected unit's name keeps one readable line above its class")
    assert(font.get_string_size(identity.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x<=identity.size.x)
   for child in app.side.get_children():assert(child.get_global_rect().end.y<=frame.end.y-10,"Every action remains inside its panel without scrolling")
   var help=app.battle_hint.get_parent()
   var hint_font=app.battle_hint.get_theme_font("font")
   var hint_width=hint_font.get_string_size(app.battle_hint.text,HORIZONTAL_ALIGNMENT_LEFT,-1,app.battle_hint.get_theme_font_size("font_size")).x
   assert(app.battle_hint.get_line_count()==1 and hint_width<=app.battle_hint.size.x,
    "Full tactical guidance fits at %s in %s state. Text width %s, hint %s, commands %s."%[
     dimensions,state,hint_width,help.get_global_rect(),frame])
   assert(help.size.x<=ceilf(hint_width+36) and not help.get_global_rect().intersects(frame.grow(12)),
    "The help plate fits its text clear of the commands")
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
 await verify_downed_navigation(app)
 for player in app.sfx_players:player.stop()
 app.music.stop();await create_timer(.15).timeout
 await Shutdown.dispose(app);await process_frame
 print("PASS: keyboard cursor bounds, retained cursor and range meshes, ready-unit cycling, movement undo, wait, forecast confirmation and key routing")
 quit()
