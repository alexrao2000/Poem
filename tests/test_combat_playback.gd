extends SceneTree
const Playback=preload("res://scripts/combat_playback.gd")
const Actor=preload("res://scripts/fighter_actor.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var mode="normal"
var accelerated_seen=false

func _initialize():call_deferred("run")

func shift(pressed: bool):
 var event=InputEventKey.new();event.keycode=KEY_SHIFT;event.physical_keycode=KEY_SHIFT;event.pressed=pressed
 Input.parse_input_event(event);Input.flush_buffered_events()

func watch_playback(node):
 if not node is Playback:return
 await process_frame
 if mode=="normal":return
 shift(true);accelerated_seen=node.accelerated
 if mode!="skip":return
 var app=node.get_parent().get_parent().get_parent()
 while app.stage.visible==false:await process_frame
 while not app.stage.get_children().any(func(actor):return actor is Actor and actor.pose_name=="advance"):await process_frame
 var tab=InputEventKey.new();tab.keycode=KEY_TAB;tab.pressed=true;app._input(tab)

func run():
 var baseline=Engine.time_scale;var audio_speed=AudioServer.playback_speed_scale
 var host=Control.new();root.add_child(host)
 for dimensions in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  host.size=dimensions;Engine.time_scale=.75
  var playback=Playback.new();playback.configure(host);await process_frame
  assert(Engine.time_scale==.75 and not playback.accelerated)
  shift(true);assert(playback.accelerated and Engine.time_scale==1.5,"Held Shift doubles the existing clock scale")
  assert(playback.hint.get_global_rect().end.y<=dimensions.y and playback.hint.get_global_rect().position.y>=dimensions.y-27)
  assert(playback.hint.get_theme_font("font").get_string_size(playback.hint.text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x<playback.hint.size.x,"Full control hint fits every supported width")
  playback.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
  assert(Engine.time_scale==.75 and not playback.accelerated,"Losing application focus clears a held speed control")
  shift(false);shift(true);playback.stop()
  assert(Engine.time_scale==.75 and not playback.active,"Explicit stop restores the exact prior clock")
  shift(false);playback.queue_free();await process_frame
 shift(true)
 var detached=Playback.new();detached.configure(host)
 assert(detached.accelerated and Engine.time_scale==1.5,"A key already held at cinematic entry is honored")
 host.queue_free();await process_frame
 assert(Engine.time_scale==.75,"Tree cleanup restores speed even without explicit cinematic completion")
 shift(false);Engine.time_scale=baseline
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-playback-test.json";root.add_child(app);await process_frame
 app.game.start_battle();app.make_map();app.show_battle();app.busy=true
 app.ui.child_entered_tree.connect(watch_playback)
 var a=app.game.units[0];var b=app.game.living("enemy")[0];a.x=8;a.y=4;b.x=9;b.y=4
 var events=[{"actor":a.id,"target":b.id,"damage":1,"remaining":19,"hit":true,"crit":false}]
 var saved=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state;var camera=app.camera.transform;var score=app.score;var durations={}
 for case in ["normal","fast","skip"]:
  mode=case;accelerated_seen=false
  var started=Time.get_ticks_msec()
  await app.cinematic(a,b,events,{a.id:20,b.id:20})
  durations[case]=Time.get_ticks_msec()-started
  assert(Engine.time_scale==baseline,"Completed and skipped real cinematics restore speed before returning control")
  shift(false);await process_frame
  assert(not app.ui.has_node("CombatPlayback"),"Combat playback control leaves no stale UI or input listener")
  assert(accelerated_seen==(case!="normal"))
  if case=="skip":assert(app.skip_combat,"Tab interrupts an accelerated real exchange")
  assert(app.game.save_data("battle")==saved and app.game.rng.state==rng and app.camera.transform.is_equal_approx(camera),"Speed changes cannot alter combat outcomes or restored map framing")
  assert(app.score==score and app.music.pitch_scale==1.0 and AudioServer.playback_speed_scale==audio_speed,"Normal/Ablaze streams retain their shared audio clock and pitch")
 assert(durations.fast<durations.normal*.8,"The actual accelerated cinematic completes measurably faster")
 mode="fast";accelerated_seen=false;app.preferences.values.combat="map"
 await app.cinematic(a,b,events,{a.id:20,b.id:20})
 assert(not accelerated_seen and Engine.time_scale==baseline,"Map-only battles never acquire a cinematic speed override")
 await Shutdown.dispose(app);await process_frame
 print("PASS: held/released speed, three hint layouts, focus loss, exact prior-scale cleanup, faster real combat, Tab skip, map-only isolation and unchanged simulation/audio/camera")
 quit()
