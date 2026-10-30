extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
const Backdrop=preload("res://scripts/title_backdrop.gd")
func _initialize():call_deferred("run")

func press(app,caption):
 var buttons=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text==caption)
 assert(buttons.size()==1 and not buttons[0].disabled,"Title action remains available: "+caption)
 buttons[0].pressed.emit()

func inspect(app):
 var backdrop=app.ui.get_node("TitleBackdrop")
 assert(backdrop.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Illustration cannot steal menu input")
 for node in [app.world,app.pieces,app.markers]:assert(not node.visible and node.process_mode==Node.PROCESS_MODE_DISABLED,"Covered map rendering and animation are suspended")

func run():
 var frames=0
 for size in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  for time in range(0,630,3):
   var rect=Backdrop.framing(size,time)
   assert(rect.encloses(Rect2(Vector2.ZERO,size)),"Slow drift never reveals an empty border")
   assert(is_equal_approx(rect.size.x/rect.size.y,1.5),"Painting retains its source aspect ratio")
   var banner=Rect2(rect.position+Vector2(1180,135)*rect.size.x/1536,Vector2(285,400)*rect.size.x/1536)
   assert(Rect2(Vector2.ZERO,size).encloses(banner),"Main banner body remains visible through every sampled crop")
   assert(banner.position.x>528,"Banner stays clear of the title menu")
   frames+=1
 var host=Control.new();root.add_child(host);host.size=Vector2(1280,720)
 var visible_scene=Node3D.new();var hidden_scene=Node3D.new();root.add_child(visible_scene);root.add_child(hidden_scene)
 hidden_scene.hide();hidden_scene.process_mode=Node.PROCESS_MODE_PAUSABLE
 var image=Backdrop.new();image.configure(host,[visible_scene,hidden_scene]);await process_frame
 assert(image.size==host.size)
 image.hide();var elapsed=image.elapsed;image._process(2);assert(image.elapsed==elapsed,"Hidden illustration suspends its clock")
 image.show();image._process(.1);assert(image.elapsed>elapsed)
 image.queue_free();await process_frame
 assert(visible_scene.visible and visible_scene.process_mode==Node.PROCESS_MODE_INHERIT)
 assert(not hidden_scene.visible and hidden_scene.process_mode==Node.PROCESS_MODE_PAUSABLE,"Departure restores each scene's original state")
 host.queue_free();visible_scene.queue_free();hidden_scene.queue_free();await process_frame
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-title-illustration-test.json"
 root.add_child(app);await process_frame;inspect(app)
 var roster=app.game.roster.duplicate(true)
 press(app,"Credits");inspect(app);press(app,"Return to title");inspect(app)
 press(app,"Options");inspect(app);press(app,"Apply and return");inspect(app)
 press(app,"Transfer a local save");inspect(app);press(app,"Return");inspect(app)
 assert(app.game.roster==roster,"Title browsing preserves character progression")
 press(app,"Begin the chronicle");assert(app.screen=="dialogue" and not app.ui.has_node("TitleBackdrop"))
 assert(app.ui.get_node("DialogueBackdrop").covered.all(func(entry):return entry.visible and entry.process_mode==Node.PROCESS_MODE_INHERIT),"Title releases its scene before the conversation acquires it")
 app.finish_dialogue();assert(app.screen=="camp")
 assert(app.ui.has_node("CouncilBackdrop") and not app.world.visible and not app.pieces.visible,"Finishing the opening hands scene suspension to the opaque council")
 assert(app.ui.get_node("CouncilBackdrop").covered.slice(0,3).all(func(entry):return entry.visible and entry.process_mode==Node.PROCESS_MODE_INHERIT),"Dialogue restores the underlying scene before council takes ownership")
 app.show_options("camp");assert(not app.ui.has_node("TitleBackdrop"),"Camp options retain their campaign context")
 await Shutdown.dispose(app);await process_frame
 print("PASS: %d title crop samples, banner visibility, nonblocking input, hidden-scene suspension/restoration and real title-menu navigation"%frames)
 quit()
