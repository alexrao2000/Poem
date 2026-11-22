extends SceneTree
# Exercise the real preparation UI: private drafts, legal empty-slot swaps,
# current enemy previews, explicit Apply/save, cancellation and actual deployment.

const Rules=preload("res://scripts/rules.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")
func canonical(data):return JSON.parse_string(JSON.stringify(data))
func run():
 var viewport=SubViewport.new();viewport.size=Vector2i(1440,900);viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-formation-ui-%d.json"%Time.get_ticks_usec();viewport.add_child(app);await process_frame
 app.preferences.values.combat="map";app.preferences.values.auto_end=false
 var layouts=0
 for dimensions in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
  viewport.size=dimensions;await process_frame
  for chapter in range(12):
   app.game.new_campaign(true);app.game.chapter=chapter;app.game.deployed=app.game.available().slice(0,6).map(func(unit):return unit.id)
   app.game.trials.flags.hard_campaign=chapter%2==0;app.game.trials.flags.reset_pressure=true;app.game.trials.pressure=2
   for index in range(12):app.game.story_seen.append("opening_"+str(index))
   app.show_camp();await process_frame;assert(app.screen=="camp");assert(app.persist_campaign("camp"))
   var before=canonical(app.game.save_data("camp"));var disk=FileAccess.get_file_as_string(app.save_path)
   app.ui.find_child("OpenFormation",true,false).pressed.emit();await process_frame;await process_frame
   var board=app.ui.find_child("FormationBoard",true,false);assert(app.screen=="formation" and board.draft==app.game.deployment_slots())
   assert(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(board.get_global_rect()) and Rect2(Vector2.ZERO,board.size).encloses(board.map_rect.grow(4)))
   for button in board.slots:
    assert(board.map_rect.encloses(button.get_rect()) and button.size.x>=24 and button.size.y>=24,"Every legal starting tile is selectable")
   for name in ["ApplyFormation","CancelFormation","DefaultFormation","FormationHint"]:
    var node=app.ui.find_child(name,true,false);assert(Rect2(Vector2.ZERO,Vector2(dimensions)).grow(1).encloses(node.get_global_rect()))
   board.slots[0].pressed.emit();app.ui.find_child("FormationChoice6",true,false).pressed.emit()
   assert(board.selected==-1 and board.draft[5]==before.deployed[0])
   var clone=Rules.new();assert(clone.restore_save(before)=="camp" and clone.set_formation_order(board.draft));clone.start_battle()
   assert(board.enemy_markers==clone.living("enemy").map(func(unit):return {"position":[unit.x,unit.y],"name":unit.name,"job":unit.job}),"Preview includes Hard reinforcements and raiders after pressure, using the draft's real starting positions")
   assert(canonical(app.game.save_data("camp"))==before and FileAccess.get_file_as_string(app.save_path)==disk,"Swapping a draft never changes live campaign, RNG, ledger or disk")
   app.ui.find_child("DefaultFormation",true,false).pressed.emit();assert(board.draft==board.defaults)
   board.slots[0].pressed.emit();board.slots[5].pressed.emit()
   var weak=weakref(board);var escape=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true;app._unhandled_input(escape);await process_frame
   assert(app.screen=="camp" and weak.get_ref()==null and canonical(app.game.save_data("camp"))==before and FileAccess.get_file_as_string(app.save_path)==disk)
   layouts+=1
 app.game.new_campaign(true);app.game.action_saves=true
 for index in range(12):app.game.story_seen.append("opening_"+str(index))
 app.show_camp();app.show_formation();await process_frame
 var board=app.ui.find_child("FormationBoard",true,false)
 board.slots[0].grab_focus();await process_frame
 var key=InputEventKey.new();key.keycode=KEY_ENTER;key.pressed=true;viewport.push_input(key,true)
 key=InputEventKey.new();key.keycode=KEY_ENTER;key.pressed=false;viewport.push_input(key,true)
 assert(board.selected==0,"Keyboard selects the focused starting tile")
 var click_point=board.slots[5].get_global_rect().get_center()
 var motion=InputEventMouseMotion.new();motion.position=click_point;viewport.push_input(motion,true)
 for pressed in [true,false]:
  var mouse=InputEventMouseButton.new();mouse.position=click_point;mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=pressed;viewport.push_input(mouse,true)
 var draft=board.draft.duplicate();assert(draft[0].is_empty() and draft[5]=="lyra","Pointer completes the swap into an empty tile")
 app.ui.find_child("ApplyFormation",true,false).pressed.emit();assert(app.screen=="camp" and app.game.formation_order==draft)
 var saved=Rules.new();assert(saved.load_game(app.save_path)=="camp" and saved.formation_order==draft)
 app.deploy_company()
 while app.busy:
  app.chapter_card_skip=true;app.phase_skip=true;await process_frame
 assert(app.screen=="battle")
 for unit in app.game.living("player"):
  var point=app.game.info().deployment_positions[draft.find(unit.id)];assert(app.game.pos(unit)==Vector2i(point[0],point[1]))
 var battle=canonical(app.game.save_data("battle"));assert(saved.load_game(app.save_path)=="battle" and canonical(saved.save_data("battle"))==battle)
 await Shutdown.dispose(app);viewport.queue_free();await process_frame
 print("PASS: %d actual formation layouts and camp buttons; occupied/empty swaps, Hard/pressure preview, default reset, Escape cancellation, untouched draft saves/RNG, keyboard/pointer swap, explicit Apply round trip and real deployment"%layouts)
 quit()
