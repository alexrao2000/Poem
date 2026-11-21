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
 if active_case=="focus":
  node.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
  assert(not node.accelerated and Engine.time_scale==1.0)
 click(node.skip_button);assert(app.skip_combat and node.skip_sent,"Actual GUI skip reaches the cinematic owner")
 requested+=1
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
 for mode in ["melee","focus","healing"]:
  active_case=mode
  a.job="Warden" if mode=="healing" else "Vanguard";a.weapon="staff" if mode=="healing" else "sword";a.item="field_staff" if mode=="healing" else "iron_sword"
  b.team="player" if mode=="healing" else "enemy"
  var event={"actor":a.id,"target":b.id,"healing":3,"remaining":20} if mode=="healing" else {"actor":a.id,"target":b.id,"damage":1,"remaining":19,"hit":true,"crit":false}
  var saved=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state;var camera=app.map_navigation.capture_view();var score=app.score
  await app.cinematic(a,b,[event],{a.id:20,b.id:17 if mode=="healing" else 20});await process_frame
  assert(not app.stage.visible and app.world.visible and not app.ui.has_node("CombatPlayback") and Engine.time_scale==original_scale)
  assert(app.game.save_data("battle")==saved and app.game.rng.state==rng and app.map_navigation.capture_view()==camera,"Pointer controls preserve resolved state and exact map framing")
  assert(app.score==score and app.music.pitch_scale==1.0 and AudioServer.playback_speed_scale==audio_scale,"Speed controls leave the score and audio pitch untouched")
 assert(requested==3)
 await Shutdown.dispose(app);await process_frame
 print("PASS: actual GUI fast/skip clicks, three sizes without HUD overlap, mixed keyboard/pointer ownership, focus loss, one-shot cancellation, three real combat/healing skips and exact state/RNG/camera/audio-clock restoration")
 quit()
