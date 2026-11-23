extends SceneTree
# Replay every authored scene through the Debug picker. The scene must use its
# own backdrop and expression data while leaving both campaign slots intact.

const Resolve=preload("res://scripts/story_survivors.gd")
const Shutdown=preload("helpers/game_shutdown.gd")

func _initialize():call_deferred("run")

func pick(control: OptionButton,index: int):
 control.select(index)
 control.item_selected.emit(index)

func replay_button(app,name_value: String) -> Button:
 return app.ui.find_child(name_value,true,false)

func check_scene(app,lines: Array,kind: String,chapter: int):
 assert(app.screen=="dialogue" and app.dialogue_lines==lines)
 assert(app.ui.get_node("DialogueBackdrop").context_id==kind+"_"+str(chapter),"Replay selects the requested painting without loading its chapter")
 var line=lines[0]
 assert(app.dialogue_name.text==app.dialogue_speaker_name(line.speaker))
 assert(app.dialogue_portrait.texture==app.portraits.get_dialogue_portrait(line.speaker,line.get("expression","")))

func run():
 var viewport=SubViewport.new()
 viewport.size=Vector2i(1280,720)
 viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 root.add_child(viewport)
 var app=load("res://main.tscn").instantiate()
 app.settings_path=""
 app.save_path="/private/tmp/poem-debug-dialogue-%d.json"%Time.get_ticks_usec()
 viewport.add_child(app);await process_frame
 var title_ui=app.ui
 app.show_debug_dialogue()
 assert(app.ui==title_ui and app.screen=="title","Normal campaigns cannot open the Debug picker")
 app.game.new_campaign(true)
 app.game.story_seen=["opening_0"]
 app.show_camp()
 app.preferences.values.text_speed=0
 app.settings_path=app.save_path+".settings"
 assert(app.preferences.save_file(app.settings_path) and app.persist_campaign("camp"))
 var normal_snapshot=app.game.save_data("camp").duplicate(true)
 var normal_disk=FileAccess.get_file_as_string(app.save_path)
 var settings_disk=FileAccess.get_file_as_string(app.settings_path)
 app.debug_session.begin(app.game,"camp")
 var lost=app.game.roster.filter(func(unit):return unit.id=="oren")[0]
 lost.fallen=true;lost.fallen_chapter=0;lost.hp=0
 assert(app.persist_campaign("camp"))
 var sandbox=app.game.save_data("camp").duplicate(true)
 var sandbox_disk=FileAccess.get_file_as_string(app.save_path+".debug")
 var trace=app.debug_session.trace.report()
 var before_view=app.map_navigation.capture_view()
 app.show_debug_tools("camp")
 replay_button(app,"DebugDialogueScenes").pressed.emit()
 assert(app.screen=="debug_dialogue")

 var campaigns=0
 for chapter in app.story.chapters.size():
  for kind in ["opening","closing"]:
   pick(app.ui.find_child("ReplayChapter",true,false),chapter)
   var name_value="Replay"+kind.capitalize()
   replay_button(app,name_value).pressed.emit()
   check_scene(app,app.story.chapters[chapter][kind],kind,chapter)
   app.finish_dialogue()
   await process_frame;await process_frame
   assert(app.screen=="debug_dialogue" and app.ui.find_child("ReplayChapter",true,false).selected==chapter)
   assert(replay_button(app,name_value).has_focus(),"Repeating a scene keeps the launch button focused")
   campaigns+=1

 var supports=0
 for index in app.game.supports.entries.size():
  var entry=app.game.supports.entries[index]
  pick(app.ui.find_child("ReplayPair",true,false),index)
  assert(app.ui.find_child("ReplayRank",true,false).selected==0)
  for rank in entry.scenes.size():
   pick(app.ui.find_child("ReplayRank",true,false),rank)
   replay_button(app,"ReplaySupport").pressed.emit()
   check_scene(app,entry.scenes[rank].lines,"support",int(entry.chapters[rank]))
   app.finish_dialogue()
   await process_frame;await process_frame
   assert(app.ui.find_child("ReplayPair",true,false).selected==index and app.ui.find_child("ReplayRank",true,false).selected==rank)
   assert(replay_button(app,"ReplaySupport").has_focus())
   supports+=1

 for dimensions in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
  viewport.size=dimensions
  await process_frame;await process_frame
  var bounds=Rect2(Vector2.ZERO,Vector2(dimensions))
  var menu_return=replay_button(app,"ReplayReturn")
  assert(bounds.encloses(menu_return.get_global_rect()))
  for name_value in ["ReplayChapter","ReplayLosses","ReplayOpening","ReplayClosing","ReplayPair","ReplayRank","ReplaySupport"]:
   var control=app.ui.find_child(name_value,true,false)
   var ancestor=control.get_parent()
   while not ancestor is ScrollContainer:ancestor=ancestor.get_parent()
   ancestor.ensure_control_visible(control)
   await process_frame
   assert(ancestor.get_global_rect().grow(1).encloses(control.get_global_rect()),"Every preview control fits its scroll area")
   assert(control.size.x>=control.get_minimum_size().x)
 pick(app.ui.find_child("ReplayChapter",true,false),0)
 app.ui.find_child("ReplayLosses",true,false).button_pressed=true
 replay_button(app,"ReplayClosing").pressed.emit()
 var alternate=Resolve.resolve(app.story.chapters[0].closing,["oren"])
 check_scene(app,alternate,"closing",0)
 assert(not app.dialogue_lines.any(func(line):return line.speaker=="oren"))
 app.show_dialogue_history()
 assert(app.dialogue_stage.history!=null)
 app.dialogue_stage.close_history()
 app.finish_dialogue()
 await process_frame;await process_frame
 assert(app.ui.find_child("ReplayLosses",true,false).button_pressed)
 var escape=InputEventKey.new();escape.pressed=true;escape.keycode=KEY_ESCAPE
 app._unhandled_input(escape)
 assert(app.screen=="debug_tools")
 assert(app.game.save_data("camp")==sandbox and app.debug_session.trace.report()==trace)
 assert(app.map_navigation.capture_view()==before_view)
 assert(FileAccess.get_file_as_string(app.save_path)==normal_disk)
 assert(FileAccess.get_file_as_string(app.save_path+".debug")==sandbox_disk)
 assert(FileAccess.get_file_as_string(app.settings_path)==settings_disk)
 app.debug_session.end(app.game)
 assert(app.game.save_data("camp")==normal_snapshot and campaigns==24 and supports==36)
 await Shutdown.dispose(app)
 viewport.queue_free();await process_frame
 print("PASS: 24 campaign previews, 36 support previews, actual loss branch, authored backdrops/expressions, focus and three layouts, exact debug and campaign state, camera, trace and file isolation")
 quit()
