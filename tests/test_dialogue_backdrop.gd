extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
const Backdrop=preload("res://scripts/dialogue_backdrop.gd")
func _initialize():call_deferred("run")

func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-dialogue-place-test.json"
 root.add_child(app);await process_frame
 assert(Backdrop.profiles.chapters.size()==app.game.content.chapters.size(),"Every campaign chapter has a painted location")
 var places=[];var layouts=0
 for chapter in range(12):
  app.game.chapter=chapter;app.game.start_battle();app.make_map();app.show_battle()
  var saved=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state
  var texture=Backdrop.texture_for(chapter,"opening")
  assert(texture==Backdrop.texture_for(chapter,"opening") and texture.filter_clip,"Repeated dialogue reuses a clipped atlas region")
  assert(not texture in places,"Each chapter has a distinct location");places.append(texture)
  assert(Rect2(Vector2.ZERO,texture.atlas.get_size()).encloses(texture.region),"Measured panel remains inside its source")
  assert(texture.region.size==Vector2(764,508),"Two-pixel insets keep neighboring paintings outside the sample")
  for kind in ["opening","closing","support"]:
   app.show_dialogue(app.story.chapters[chapter].opening,app.show_battle,kind);await process_frame
   var backdrop=app.ui.get_node("DialogueBackdrop")
   assert(backdrop.context_id==kind+"_"+str(chapter) and backdrop.artwork==Backdrop.texture_for(chapter,kind),"Actual dialogue selects its current chapter and story phase")
   assert(not app.world.visible and app.pieces.process_mode==Node.PROCESS_MODE_DISABLED,"Covered map stays suspended during dialogue")
   assert(app.ui.get_child(0)==backdrop and backdrop.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Painting sits behind portraits and cannot block dialogue controls")
   for dimensions in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
    var rect=Backdrop.framing(dimensions,backdrop.artwork.get_size())
    assert(rect.grow(.001).encloses(Rect2(Vector2.ZERO,dimensions)))
    assert(is_equal_approx(rect.size.x/rect.size.y,backdrop.artwork.get_size().x/backdrop.artwork.get_size().y),"Dialogue paintings never stretch")
    layouts+=1
   app.finish_dialogue();await process_frame
   assert(app.world.visible and app.pieces.visible and app.pieces.process_mode==Node.PROCESS_MODE_INHERIT,"Returning from every location restores the map")
   assert(app.game.save_data("battle")==saved and app.game.rng.state==rng,"Backdrop selection and skipping never alter campaign outcomes")
 assert(Backdrop.texture_for(1,"closing").atlas.resource_path.ends_with("dialogue-river-open-v1.png"),"River closing uses the chain-free waterway")
 assert(Backdrop.texture_for(11,"closing").atlas.resource_path.ends_with("title-dawn-v1.png"),"Finale closing shows natural dawn instead of the active engine")
 for chapter in [1,11]:
  app.game.chapter=chapter;app.game.start_battle();app.make_map();app.show_battle()
  for enemy in app.game.living("enemy"):enemy.hp=0
  var leader=app.game.living("player")[0];var objective=app.game.objective_position();leader.x=objective.x;leader.y=objective.y
  assert(await app.check_result())
  var button=app.ui.find_children("*","Button",true,false).filter(func(control):return control.text=="Continue the chronicle")[0]
  button.pressed.emit();assert(app.screen=="dialogue" and app.ui.get_node("DialogueBackdrop").context_id=="closing_"+str(chapter),"Real victory navigation selects the resolved-story background")
  app.finish_dialogue()
  if chapter==1:
   assert(app.game.chapter==2 and app.ui.get_node("DialogueBackdrop").context_id=="opening_2","Next chapter selects its own background without retaining the closing scene")
   app.finish_dialogue()
  else:assert(app.game.completed and app.screen=="ending" and not app.ui.has_node("DialogueBackdrop"),"Final dialogue restores the scene and reaches the epilogue")
 await Shutdown.dispose(app);await process_frame
 print("PASS: twelve distinct chapter locations, %d aspect-preserving layouts, two closing variants, scene restoration, actual victory transitions and unchanged simulation"%layouts)
 quit()
