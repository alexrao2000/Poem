extends SceneTree
# Earned scenes survive section rewinds. They are read once during camp arrival,
# can be replayed as memories, and remain isolated with the debug save state.
const Rules=preload("res://scripts/rules.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")
func run():
 var game=Rules.new();var count=0;var ids=game.roster.map(func(unit):return unit.id)
 for scene in game.trials.scenes.values():
  for line in scene:
   assert(line.speaker in ids and line.text.length()>20 and line.text.length()<500);count+=1
 assert(count==22)
 game.trials.queue_scene("relief_4");game.trials.queue_scene("relief_4")
 assert(game.trials.earned_scenes.size()==1 and game.trials.next_scene(game).size()==5)
 assert(game.trials.next_scene(game).is_empty())
 var loaded=Rules.new();assert(loaded.import_code(game.export_code("camp"))=="camp" and loaded.trials.next_scene(loaded).is_empty(),"Read scenes survive save transfer")
 var malformed=game.save_data("camp").duplicate(true);malformed.trials.read_scenes.append("retreat_0")
 assert(not game.valid_save(malformed),"A scene cannot be read without being earned")
 game.trials.queue_scene("volunteer_faye");var faye=game.roster.filter(func(unit):return unit.id=="faye")[0];faye.fallen=true;faye.fallen_chapter=4;faye.hp=0
 assert(game.trials.next_scene(game).is_empty(),"An arrival scene cannot introduce a volunteer who has since died")
 root.size=Vector2i(1440,900)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-trial-story-ui.json"
 root.add_child(app);await process_frame
 app.game.new_campaign(true);app.game.chapter=4;app.game.story_seen=["opening_4"];app.game.trials.flags.section_restarts=true;app.game.trials.arrive(app.game)
 app.show_camp();assert(app.screen=="dialogue" and app.dialogue_lines.size()==5 and "abbey" in app.dialogue_lines[0].text)
 assert(loaded.load_game(app.save_path)=="camp" and "relief_4" in loaded.trials.read_scenes,"Camp arrival checkpoints the scene before playback")
 app.finish_dialogue();assert(app.screen=="camp")
 app.show_camp();assert(app.screen=="camp","Returning to camp does not replay the relief scene")
 app.show_campaign_trials()
 var replay=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Replay · Relief 4")
 assert(replay.size()==1);replay[0].pressed.emit();assert(app.screen=="dialogue")
 app.finish_dialogue();assert(app.screen=="campaign_trials","Memory replay returns to the campaign ledger")
 app.game.trials.queue_scene("retreat_4");var saved=app.game.export_code("camp")
 app.debug_session.begin(app.game,"camp");app.game.trials.next_scene(app.game);app.debug_session.end(app.game)
 assert(app.game.export_code("camp")==saved,"Debug playback cannot consume a scene in the normal campaign")
 await Shutdown.dispose(app);await process_frame
 print("PASS: 22 original trial-story lines, relief/retreat/volunteer scenes, one-time arrivals, saved read state, deceased volunteer guard, archive replay and debug restoration")
 quit()
