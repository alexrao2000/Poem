extends SceneTree
# Earned scenes survive section rewinds. They are read once during camp arrival,
# can be replayed as memories, and remain isolated with the debug save state.
const Rules=preload("res://scripts/rules.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")
func inspect_fixed(app):
 for dimensions in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions
  await process_frame;await process_frame
  for node in app.ui.find_children("*","Control",true,false):
   if not node.is_visible_in_tree():continue
   var parent=node.get_parent();var clipped=false
   while parent!=app.ui:
    if parent is ScrollContainer:clipped=true;break
    parent=parent.get_parent()
   if not clipped:assert(Rect2(Vector2.ZERO,dimensions).grow(1).encloses(node.get_global_rect()),"Epilogue and archive controls fit: "+app.screen)

func run():
 var game=Rules.new();var count=0;var ids=game.roster.map(func(unit):return unit.id)
 for scene in game.trials.scenes.values():
  for line in scene:
   assert(line.speaker in ids and line.text.length()>20 and line.text.length()<500);count+=1
 assert(count==31)
 game.trials.queue_scene("relief_4");game.trials.queue_scene("relief_4")
 assert(game.trials.earned_scenes.size()==1 and game.trials.next_scene(game).size()==5)
 assert(game.trials.next_scene(game).is_empty())
 var loaded=Rules.new();assert(loaded.import_code(game.export_code("camp"))=="camp" and loaded.trials.next_scene(loaded).is_empty(),"Read scenes survive save transfer")
 var malformed=game.save_data("camp").duplicate(true);malformed.trials.read_scenes.append("retreat_0")
 assert(not game.valid_save(malformed),"A scene cannot be read without being earned")
 game.trials.queue_scene("volunteer_faye");var faye=game.roster.filter(func(unit):return unit.id=="faye")[0];faye.fallen=true;faye.fallen_chapter=4;faye.hp=0
 assert(game.trials.next_scene(game).is_empty(),"An arrival scene cannot introduce a volunteer who has since died")
 for chapter in [0,4,8]:
  var mourning=Rules.new();mourning.new_campaign(true);mourning.chapter=chapter; mourning.trials.flags.death_legacies=true; mourning.trials.flags.section_restarts=true; mourning.death_door=true; mourning.start_battle()
  var patient=mourning.units[1];patient.hp=0; mourning.DeathDoor.fall(mourning,patient); mourning.commit_casualties()
  assert(mourning.trials.earned_scenes.is_empty(),"Downed allies are not memorialized while they can still be rescued")
  mourning.begin_enemy_phase();mourning.next_player_turn();mourning.begin_enemy_phase()
  var memorial="memorial_"+str(chapter)
  assert(memorial in mourning.trials.earned_scenes,"Terminal legacy loss earns the memorial for its section")
  var next=mourning.trials.next_scene(mourning)
  assert(next.size()==3 and next.all(func(line):return line.speaker=="lyra"),"Memorial precedes volunteer arrival and uses a surviving speaker")
  var other=mourning.units[2];other.hp=0;mourning.commit_casualties()
  assert(mourning.trials.earned_scenes.count(memorial)==1,"Later losses cannot repeat a section memorial")
  assert(mourning.trials.restart(mourning))
  var restored=Rules.new();assert(restored.import_code(mourning.export_code("camp"))=="camp")
  assert(memorial in restored.trials.read_scenes and restored.trials.earned_scenes.count(memorial)==1,"Memorial read state survives retreat and save transfer")
 var returning=Rules.new();returning.trials.flags.death_legacies=true;returning.start_battle();returning.units[1].hp=0;returning.commit_casualties()
 assert(returning.trials.earned_scenes.is_empty(),"Returning casualties do not trigger permanent-loss memorials")
 root.size=Vector2i(1440,900)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-trial-story-ui.json"
 root.add_child(app);await process_frame
 app.game.new_campaign(true);app.game.chapter=4;app.game.story_seen=["opening_4"];app.game.trials.flags.section_restarts=true;app.game.trials.arrive(app.game)
 app.show_camp();assert(app.screen=="dialogue" and app.dialogue_lines.size()==5 and "abbey" in app.dialogue_lines[0].text)
 assert(loaded.load_game(app.save_path)=="camp" and "relief_4" in loaded.trials.read_scenes,"Camp arrival checkpoints the scene before playback")
 app.finish_dialogue();assert(app.screen=="camp")
 app.show_camp();assert(app.screen=="camp","Returning to camp does not replay the relief scene")
 app.show_campaign_trials()
 var replay=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Replay · Relief at the abbey")
 assert(replay.size()==1);replay[0].pressed.emit();assert(app.screen=="dialogue")
 app.finish_dialogue();assert(app.screen=="campaign_trials","Memory replay returns to the campaign ledger")
 app.game.trials.queue_scene("retreat_4");var saved=app.game.export_code("camp")
 app.debug_session.begin(app.game,"camp");app.game.trials.next_scene(app.game);app.debug_session.end(app.game)
 assert(app.game.export_code("camp")==saved,"Debug playback cannot consume a scene in the normal campaign")
 app.game.new_campaign(true);app.game.chapter=11;app.game.trials.flags.death_legacies=true;app.game.start_battle()
 app.game.units[1].hp=0;app.game.commit_casualties()
 for enemy in app.game.living("enemy"):enemy.hp=0
 assert(app.game.result()=="victory");app.game.finish_chapter();app.make_map();app.show_ending()
 assert(app.screen=="dialogue" and app.dialogue_lines.size()==3 and "monastery bell" in app.dialogue_lines[0].text,"A final-battle memorial is presented before the epilogue")
 assert(loaded.load_game(app.save_path)=="ending" and "memorial_8" in loaded.trials.read_scenes,"Final memorial read state is saved as a completed campaign")
 app.finish_dialogue();assert(app.screen=="ending");await inspect_fixed(app)
 app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Company memories")[0].pressed.emit()
 assert(app.screen=="campaign_trials" and not app.ui.find_children("*","Button",true,false).any(func(button):return button.text.begins_with("Secure ·")),"Completed archives do not reopen the legacy shop")
 await inspect_fixed(app)
 var replay_memorial=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Replay · The monastery bell")[0]
 var completed=app.game.save_data("ending").duplicate(true);replay_memorial.pressed.emit();app.finish_dialogue()
 assert(app.screen=="campaign_trials" and app.game.save_data("ending")==completed,"Archived memorial replay leaves the completed campaign unchanged")
 var escape=InputEventKey.new();escape.pressed=true;escape.keycode=KEY_ESCAPE;app._unhandled_input(escape)
 assert(app.screen=="ending" and app.game.completed,"Escape from the completed archive returns to the epilogue, not deployment")
 app.show_campaign_trials();app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Return to epilogue")[0].pressed.emit()
 assert(app.screen=="ending","The archive return button also preserves the completed route")
 await Shutdown.dispose(app);await process_frame
 print("PASS: 31 original trial-story lines, relief/retreat/volunteer/memorial scenes, one-time arrivals, saved read state, deceased volunteer guard, archive replay and debug restoration")
 quit()
