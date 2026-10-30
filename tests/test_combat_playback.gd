extends SceneTree
const Playback=preload("res://scripts/combat_playback.gd")
const Impact=preload("res://scripts/combat_impact.gd")
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

func skip_phase(app,phase: String,report: Dictionary):
 var deadline=Time.get_ticks_msec()+10000
 while Time.get_ticks_msec()<deadline:
  await process_frame
  if not app.stage.visible:continue
  var actors=app.stage.get_children().filter(func(node):return node is Actor and not node.is_queued_for_deletion())
  var found=actors.any(func(actor):return actor.pose_name==phase)
  if phase=="projectile":found=app.stage.has_node("CombatProjectile")
  elif phase=="hold":found=app.stage.has_node("CombatHitStop")
  elif phase in ["heal_flight","heal_bloom"]:
   var heal=app.stage.get_node_or_null("CombatHeal")
   found=heal!=null and heal.has_arrived==(phase=="heal_bloom")
  if not found:continue
  report.requested=true
  var tab=InputEventKey.new();tab.keycode=KEY_TAB;tab.pressed=true;app._input(tab)
  report.frames=0
  while not app.ui.get_node("CombatTransition").visible and report.frames<6:
   await process_frame;report.frames+=1
  assert(report.frames<=2,"Tab starts the return transition within two frames during "+phase)
  return
 assert(false,"The actual cinematic reached the requested skip phase: "+phase)

func verify_phase_skips(app,a,b):
 app.preferences.values.combat="all";mode="normal"
 var impact_count=[0]
 var count_impact=func(node):
  if node is Impact:impact_count[0]+=1
 app.stage.child_entered_tree.connect(count_impact)
 for phase in ["windup","strike","projectile","hit","hold","down","evade","heal_flight","heal_bloom"]:
  var healing=phase.begins_with("heal_")
  a.job="Warden" if healing else "Ranger" if phase=="projectile" else "Vanguard"
  a.weapon="staff" if healing else "bow" if phase=="projectile" else "sword"
  a.item="mend_staff" if healing else "iron_bow" if phase=="projectile" else "iron_sword"
  b.team="player" if healing else "enemy"
  var event={"actor":a.id,"target":b.id,"damage":0 if phase=="evade" else 1,"remaining":0 if phase=="down" else 19,"hit":phase!="evade","crit":false}
  if healing:event={"actor":a.id,"target":b.id,"healing":3,"remaining":20}
  var saved=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state
  var camera=app.camera.transform;var score=app.score;var initial_impacts=impact_count[0]
  var report={};skip_phase(app,phase,report)
  await app.cinematic(a,b,[event],{a.id:20,b.id:17 if healing else 20})
  await process_frame;await process_frame
  assert(report.get("requested",false) and app.skip_combat,"Skip is exercised during "+phase)
  assert(not app.stage.visible and app.world.visible and app.camera.transform.is_equal_approx(camera),"Every cancelled phase returns to the original map camera")
  assert(app.game.save_data("battle")==saved and app.game.rng.state==rng and app.score==score and Engine.time_scale==1.0,"Presentation cancellation preserves resolved state, score ownership and clock")
  for name in ["CombatProjectile","CombatHeal","CombatHitStop","CombatCharge","CombatTrail"]:assert(not app.stage.has_node(name),"Cancelled transient is released: "+name)
  for actor in app.stage.get_children().filter(func(node):return node is Actor):assert(actor.can_process(),"Cancellation cannot strand a frozen fighter")
  if phase in ["windup","strike","projectile","evade"]:assert(impact_count[0]==initial_impacts,"No delayed impact may appear after the user skips before contact")
 app.stage.child_entered_tree.disconnect(count_impact)

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
 await verify_phase_skips(app,a,b)
 await Shutdown.dispose(app);await process_frame
 print("PASS: held/released speed, three hint layouts, focus loss, exact prior-scale cleanup, faster real combat, nine phase-specific skips within two frames, transient cleanup, map-only isolation and unchanged simulation/audio/camera")
 quit()
