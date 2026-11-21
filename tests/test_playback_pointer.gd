extends SceneTree
const Playback=preload("res://scripts/combat_playback.gd")
const HUD=preload("res://scripts/combat_hud.gd")
const Shutdown=preload("res://tests/helpers/game_shutdown.gd")
var app
var requested=0
var active_case=""
func _initialize():call_deferred("run")
func click(button: Button):
 var point=button.get_global_rect().get_center()
 var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion,true)
 for pressed in [true,false]:
  var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=point;event.global_position=point
  event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;root.push_input(event,true)
func shift(pressed: bool):
 var event=InputEventKey.new();event.keycode=KEY_SHIFT;event.physical_keycode=KEY_SHIFT;event.pressed=pressed
 Input.parse_input_event(event);Input.flush_buffered_events()
func watch(node):
 if not node is Playback:return
 await process_frame
 while not app.stage.visible:await process_frame
 while not app.stage.get_children().any(func(actor):return actor.get("pose_name")==("cast_windup" if active_case=="healing" else "windup")):await process_frame
 click(node.fast_button);assert(node.accelerated and Engine.time_scale==2.0,"Actual GUI click accelerates the active cinematic")
 var audio=app.interface_audio
 if active_case=="healing":assert(not audio.player.playing,"Muted combat controls stay silent")
 else:assert(audio.player.playing and audio.player.stream==audio.streams.confirm,"Pointer fast-forward uses the existing confirmation voice")
 if active_case=="focus":
  node.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
  assert(not node.accelerated and Engine.time_scale==1.0)
 await create_timer(.08).timeout
 audio.player.stop()
 if active_case=="keyboard":
  var event=InputEventKey.new();event.keycode=KEY_TAB;event.pressed=true;root.push_input(event,true)
  event=InputEventKey.new();event.keycode=KEY_TAB;event.pressed=false;root.push_input(event,true)
 else:click(node.skip_button)
 assert(app.skip_combat and node.skip_sent,"Pointer and keyboard skips share the one-shot cinematic request")
 if active_case=="healing":assert(not audio.player.playing)
 else:assert(audio.player.playing and audio.player.stream==audio.streams.back,"Accepted skips use the existing return cue")
 var last_press=audio.last_press;node.request_skip();assert(audio.last_press==last_press,"Repeated requests do not replay confirmation")
 requested+=1
func skip_opening(report: Dictionary,pointer: bool,threshold: float):
 while app.ui.get_node_or_null("CombatTransition")==null:await process_frame
 var veil=app.ui.get_node("CombatTransition")
 while veil.progress<threshold:await process_frame
 assert(not app.stage.visible,"The request is sent during the real tactical zoom, before arena construction")
 var playback=app.ui.get_node("CombatPlayback")
 if pointer:click(playback.fast_button);click(playback.skip_button)
 else:
  for pressed in [true,false]:
   var key=InputEventKey.new();key.keycode=KEY_TAB;key.pressed=pressed;root.push_input(key,true)
 assert(playback.skip_sent and app.skip_combat);report.requested=true
 while is_instance_valid(playback) and not playback.is_queued_for_deletion():
  assert(not app.stage.visible and app.world.visible,"An opening skip never flashes the arena")
  await process_frame

func verify_opening_skips():
 var additions=[0];var count_child=func(_child):additions[0]+=1
 app.stage.child_entered_tree.connect(count_child)
 var hidden=Control.new();app.ui.add_child(hidden);hidden.hide()
 for revised in [false,true]:
  for healing in [false,true]:
   app.preferences.values.character_models="revised" if revised else "current"
   var a=app.game.units[0];var b=app.game.living("enemy")[0] if not healing else app.game.units[1]
   a.job="Warden" if healing else "Vanguard";a.weapon="staff" if healing else "sword";a.item="field_staff" if healing else "iron_sword"
   var event={"actor":a.id,"target":b.id,"healing":3,"remaining":20} if healing else {"actor":a.id,"target":b.id,"damage":1,"remaining":19,"hit":true,"crit":false}
   var saved=app.game.save_data("battle").duplicate(true);var camera=app.map_navigation.capture_view();var lighting=app.lighting_state();var score=app.score;var scale=Engine.time_scale
   var controls={}
   for control in app.ui.get_children():controls[control]=control.visible
   var report={};var previous=additions[0];skip_opening(report,healing,.75 if revised else .18)
   await app.cinematic(a,b,[event],{a.id:20,b.id:17 if healing else 20});await process_frame;await process_frame
   assert(report.get("requested",false) and additions[0]==previous,"Early Tab and late pointer skips construct no arena, fighters, HUD or effects")
   assert(app.game.save_data("battle")==saved and app.map_navigation.capture_view()==camera and app.lighting_state()==lighting,"Opening cancellation preserves resolved state/RNG, exact camera and map lighting")
   assert(app.score==score and Engine.time_scale==scale and app.world.visible and app.pieces.visible and app.markers.visible)
   assert(not app.ui.has_node("CombatTransition") and not app.ui.has_node("CombatPlayback"))
   for control in controls:assert(control.visible==controls[control],"Restore only the controls visible before entry")
 app.stage.child_entered_tree.disconnect(count_child);hidden.queue_free();await process_frame

func run():
 var original_scale=Engine.time_scale;var audio_scale=AudioServer.playback_speed_scale
 var host=Control.new();host.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(host)
 var rules=load("res://scripts/rules.gd").new();rules.start_battle()
 var entries=[]
 for unit in [rules.units[0],rules.living("enemy")[0]]:entries.append({"unit":unit,"hp":unit.hp,"class_name":unit.job,"weapon":rules.item_for(unit).name})
 for dimensions in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
  root.size=dimensions;host.size=dimensions;Engine.time_scale=.75
  var playback=Playback.new();playback.configure(host);var skips=[0];playback.skip_requested.connect(func():skips[0]+=1)
  var hud=HUD.new();hud.configure(host,entries);await process_frame;await process_frame
  for control in [playback.fast_button,playback.skip_button]:
   assert(control.size.x>=100 and control.size.y>=44 and Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(control.get_global_rect()),"Pointer controls retain usable targets inside all supported viewports")
   assert(not control.get_global_rect().intersects(playback.hint.get_global_rect()),"Buttons leave the keyboard hint clear")
   for record in hud.records.values():assert(not control.get_global_rect().intersects(record.plate.get_global_rect()),"Controls fit between both health plates")
  click(playback.fast_button);assert(playback.pointer_fast and playback.accelerated and Engine.time_scale==1.5)
  shift(true);shift(false);assert(playback.accelerated and Engine.time_scale==1.5,"Releasing Shift does not cancel a pointer speed toggle")
  click(playback.fast_button);assert(not playback.accelerated and Engine.time_scale==.75)
  shift(true);assert(playback.fast_button.button_pressed)
  shift(false);assert(not playback.fast_button.button_pressed and Engine.time_scale==.75)
  click(playback.fast_button);playback.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
  assert(not playback.pointer_fast and not playback.keyboard_fast and not playback.fast_button.button_pressed and Engine.time_scale==.75,"Focus loss clears both speed sources")
  click(playback.skip_button);click(playback.skip_button);assert(skips[0]==1 and playback.skip_button.disabled,"Skip dispatches only once")
  playback.stop();click(playback.fast_button);assert(Engine.time_scale==.75 and not playback.active)
  playback.queue_free();hud.queue_free();await process_frame
 host.queue_free();await process_frame;Engine.time_scale=original_scale
 app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-playback-pointer.json";root.add_child(app);await process_frame
 app.game.start_battle();app.make_map();app.show_battle();app.busy=true;app.ui.child_entered_tree.connect(watch)
 var a=app.game.units[0];var b=app.game.living("enemy")[0];a.x=8;a.y=4;b.x=9;b.y=4
 for mode in ["melee","focus","healing","keyboard"]:
  active_case=mode
  app.preferences.values.effects=0.0 if mode=="healing" else 1.0;app.apply_audio_preferences()
  a.job="Warden" if mode=="healing" else "Vanguard";a.weapon="staff" if mode=="healing" else "sword";a.item="field_staff" if mode=="healing" else "iron_sword"
  b.team="player" if mode=="healing" else "enemy"
  var event={"actor":a.id,"target":b.id,"healing":3,"remaining":20} if mode=="healing" else {"actor":a.id,"target":b.id,"damage":1,"remaining":19,"hit":true,"crit":false}
  var saved=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state;var camera=app.map_navigation.capture_view();var score=app.score
  await app.cinematic(a,b,[event],{a.id:20,b.id:17 if mode=="healing" else 20});await process_frame
  assert(not app.stage.visible and app.world.visible and not app.ui.has_node("CombatPlayback") and Engine.time_scale==original_scale)
  assert(app.game.save_data("battle")==saved and app.game.rng.state==rng and app.map_navigation.capture_view()==camera,"Pointer controls preserve resolved state and exact map framing")
  assert(app.score==score and app.music.pitch_scale==1.0 and AudioServer.playback_speed_scale==audio_scale,"Speed controls leave the score and audio pitch untouched")
 assert(requested==4)
 app.ui.child_entered_tree.disconnect(watch)
 app.game.start_battle();app.make_map();app.show_battle();app.busy=true
 await verify_opening_skips()
 await Shutdown.dispose(app);await process_frame
 print("PASS: actual GUI fast/skip clicks, three sizes without HUD overlap, mixed keyboard/pointer ownership, focus loss, one-shot pointer/keyboard cancellation, muted/confirmed interface feedback, four real combat/healing skips, four opening skips without arena construction and exact state/RNG/camera/audio-clock restoration")
 quit()
