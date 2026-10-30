extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
const InterfaceAudio=preload("res://scripts/ui_audio.gd")
func _initialize():call_deferred("run")
func run():
 var voice=InterfaceAudio.new();root.add_child(voice);voice.configure(-12)
 for kind in ["move","confirm","back"]:
  var stream=voice.streams[kind]
  assert(stream is AudioStreamWAV and stream.mix_rate==22050 and stream.loop_mode==AudioStreamWAV.LOOP_DISABLED)
  assert(absf(stream.get_length()-{"move":.045,"confirm":.145,"back":.115}[kind])<.001,"Interface cues have short authored durations")
 assert(voice.cue("move",1000) and not voice.cue("move",1030),"Hover/focus duplicates do not stack")
 assert(voice.cue("confirm",1035) and voice.player.stream==voice.streams.confirm,"Confirmation takes priority over cursor motion")
 assert(not voice.cue("confirm",1040) and not voice.cue("move",1100),"Duplicate activation and immediate post-click hover stay quiet")
 assert(voice.cue("move",1160) and voice.cue("back",1200))
 voice.player.volume_db=-80;voice.player.stop()
 assert(not voice.cue("confirm",1500) and not voice.player.playing,"Effects mute prevents interface playback")
 voice.queue_free();await process_frame
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-ui-audio-test.json";root.add_child(app);await process_frame
 var audio=app.interface_audio;var game_state=app.game.export_code("camp");var music=app.music.stream
 var holder=VBoxContainer.new();app.ui.add_child(holder)
 var pressed=[]
 var action=app.button_in(holder,"Inspect",func():pressed.append("inspect"))
 var disabled=app.button_in(holder,"Locked",func():pressed.append("locked"),true)
 action.focus_entered.emit();assert(audio.player.stream==audio.streams.move)
 action.pressed.emit();assert(pressed==["inspect"] and audio.player.stream==audio.streams.confirm,"Real buttons play confirmation and still execute their action")
 audio.player.stop();disabled.mouse_entered.emit();disabled.focus_entered.emit()
 assert(not audio.player.playing,"Disabled controls stay silent")
 while Time.get_ticks_msec()-audio.last_press<35:await process_frame
 var back=app.button_in(holder,"Return to war council",func():pressed.append("back"))
 back.pressed.emit();assert(pressed==["inspect","back"] and audio.player.stream==audio.streams.back)
 assert(app.game.export_code("camp")==game_state and app.music.stream==music,"UI sounds do not change campaign state or replace the music pair")
 app.preferences.values.effects=0;app.apply_audio_preferences()
 assert(audio.player.volume_db==-80 and app.sfx_players.all(func(player):return player.volume_db==-80),"Interface and combat effects share the saved effects volume")
 app.preferences.values.effects=1;app.apply_audio_preferences()
 app.game.start_battle();app.make_map();app.show_battle()
 await create_timer(.15).timeout
 app.cursor_visible=true;app.cursor_tile=Vector2i.ZERO;audio.player.stop()
 app.move_map_cursor(Vector2i.LEFT);assert(not audio.player.playing,"Cursor motion clamped at the board edge stays silent")
 app.move_map_cursor(Vector2i.RIGHT);assert(audio.player.stream==audio.streams.move and audio.player.playing,"A real changed tile gives one navigation cue")
 var combat_voice=app.sfx_players[0];combat_voice.stream=app.sfx_streams.phase;combat_voice.play()
 while Time.get_ticks_msec()-audio.last_press<35:await process_frame
 assert(audio.cue("confirm"))
 assert(combat_voice.playing and combat_voice.stream==app.sfx_streams.phase,"Menu feedback never steals an active combat effect channel")
 app.music.play();app.game.chapter=4;app.select_score_theme()
 assert(app.score_director.outgoing!=null)
 app.score_director.stop()
 assert(not app.music.playing and app.score_director.outgoing==null,"Stopping the score cancels both sides of a live crossfade")
 audio.player.stop()
 for player in app.sfx_players:player.stop()
 await create_timer(.2).timeout;await Shutdown.dispose(app);await process_frame
 print("PASS: original UI cue resources, hover/press throttling, actual button and cursor feedback, mute/volume, independent combat channel and complete score shutdown")
 quit()
