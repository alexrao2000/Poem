extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
# Measure projected ground anchors rather than relying on screenshots. Exercise
# bounded drag, interrupted zoom, cursor tracking and the real cinematic handoff.
func _initialize():call_deferred("run")
func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-map-camera.json"
 root.add_child(app);await process_frame
 app.game.start_battle();app.make_map();app.show_battle()
 var nav=app.map_navigation;var camera=app.camera;var home=camera.transform;var anchor=Vector2(600,400)
 var ground=nav.ground_at(anchor);nav.zoom(2,anchor);await nav.motion.finished
 assert(camera.size<16 and nav.ground_at(anchor).distance_to(ground)<.0001,"Zoom holds the pointer's ground position")
 ground=nav.ground_at(anchor);nav.begin_drag(anchor);nav.drag(anchor+Vector2(80,45))
 assert(nav.ground_at(anchor+Vector2(80,45)).distance_to(ground)<.0001,"Drag holds the grabbed ground beneath the pointer")
 nav.drag(Vector2(-10000,-10000))
 var center=camera.position-nav.eye_offset
 assert(center.x>=-1 and center.x<=nav.board.x and center.z>=-1 and center.z<=nav.board.y,"Dragging cannot lose the board")
 var release=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_MIDDLE;release.pressed=false;app._input(release)
 assert(not nav.dragging,"Middle release always ends dragging")
 var key=InputEventKey.new();key.pressed=true;key.keycode=KEY_HOME;app._input(key)
 assert(camera.transform==home and camera.size==16,"Home restores the full tactical view")
 key.keycode=KEY_EQUAL;app._input(key);await nav.motion.finished
 assert(camera.size<16,"Keyboard zoom works without a wheel")
 key.keycode=KEY_HOME;app._input(key)
 nav.zoom(100,anchor);await nav.motion.finished;assert(camera.size==8,"Zoom-in is bounded")
 nav.keep_visible(Vector3(13,0,9))
 assert(nav.safe_rect().grow(.01).has_point(camera.unproject_position(Vector3(13,0,9))),"Keyboard tracking keeps distant tiles away from command panels")
 var height=camera.position.y
 for cycle in range(4):
  for point in [Vector3(0,.1,0),Vector3(13,.08,9)]:
   nav.keep_visible(point)
   assert(is_equal_approx(camera.position.y,height),"Tracking elevated tiles cannot accumulate camera altitude")
   assert(nav.safe_rect().grow(.01).has_point(camera.unproject_position(point)),"Elevated tiles track to the actual safe screen rectangle")
 app.cursor_visible=true
 for corner in [Vector2i.ZERO,Vector2i(13,0),Vector2i(0,9),Vector2i(13,9)]:
  app.cursor_tile=corner;app.move_map_cursor(Vector2i.ZERO)
  var projected=camera.unproject_position(Vector3(corner.x,0,corner.y))
  assert(nav.safe_rect().grow(.01).has_point(projected) and not app.terrain_card.get_global_rect().has_point(projected),"Keyboard tracking keeps every board corner clear of terrain and command panels")
 nav.zoom(-100,anchor);await nav.motion.finished;assert(camera.size==24,"Zoom-out is bounded")
 app.map_camera()
 camera.position+=Vector3(3,0,-2)
 var start_angle=camera.rotation.x;var initial_transform=camera.transform;var tactical=nav.capture_view()
 var approach=nav.approach_combat(Vector3(8.5,0,4),.18)
 assert(camera.transform==initial_transform,"Combat approach starts without a position or angle jump")
 var previous_size=camera.size;var previous_pitch=camera.rotation.x
 while approach.is_running():
  await process_frame
  assert(camera.size<=previous_size+.001,"Tactical zoom closes continuously")
  assert(camera.rotation.x>=previous_pitch-.001,"Camera descends continuously toward the ground-level scene")
  assert(is_zero_approx(camera.rotation.z),"Approach never rolls the horizon")
  previous_size=camera.size;previous_pitch=camera.rotation.x
 assert(camera.rotation.x>start_angle+.2 and is_equal_approx(camera.rotation.x,deg_to_rad(-38)),"Combat handoff lowers the overhead view to 38 degrees")
 assert(camera.unproject_position(Vector3(8.5,0,4)).distance_to(camera.get_viewport().get_visible_rect().size*.5)<.01,"Completed combat zoom centers the engaged pair after tactical panning")
 var close_view=nav.capture_view();camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.position=Vector3(35,2,8);camera.look_at(Vector3(35,1,0))
 var returning=nav.return_from_combat(close_view,tactical,.2);returning.pause()
 assert(camera.transform.is_equal_approx(close_view.transform) and camera.size==close_view.size,"Map return begins at the actual close map view instead of jumping to a different map center")
 assert(camera.unproject_position(Vector3(8.5,0,4)).distance_to(camera.get_viewport().get_visible_rect().size*.5)<.01,"Engaged units remain centered at the reveal handoff")
 var last_size=camera.size;var distance=camera.position.distance_to(tactical.transform.origin)
 for frame in range(8):
  returning.custom_step(.025)
  assert(camera.size>=last_size-.001 and camera.position.distance_to(tactical.transform.origin)<=distance+.001,"Return widens and moves back continuously to the player's panned view")
  last_size=camera.size;distance=camera.position.distance_to(tactical.transform.origin)
 returning.custom_step(.01)
 assert(nav.capture_view()==tactical and nav.zoom_goal==tactical.size,"Return restores exact transform, lens, offsets, projection and subsequent wheel target")
 for offsets in [Vector2(-.6,.4),Vector2(.7,-.3)]:
  camera.h_offset=offsets.x;camera.v_offset=offsets.y;camera.size=11;camera.fov=57;var offset_view=nav.capture_view()
  nav.approach_combat(Vector3(12,0,8),.1).custom_step(.11);close_view=nav.capture_view()
  returning=nav.return_from_combat(close_view,offset_view,.2);returning.custom_step(.21)
  assert(nav.capture_view()==offset_view,"Nondefault view offsets and lens survive a full round trip")
 returning=nav.return_from_combat(close_view,tactical,.2);returning.custom_step(.03);nav.stop()
 var cancelled=nav.capture_view();await create_timer(.22).timeout
 assert(nav.capture_view()==cancelled,"Navigation stop cancels a return before another camera owner takes over")

 app.map_camera()
 var wheel=InputEventMouseButton.new();wheel.pressed=true;wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.position=anchor
 app.busy=true;app._unhandled_input(wheel);assert(camera.size==16 and nav.zoom_goal==16,"Busy actions ignore map gestures")
 app.busy=false;app._unhandled_input(wheel);await create_timer(.035).timeout
 camera.position+=Vector3(3,0,-2)
 var prior=camera.transform;var size=camera.size;var rng=app.game.rng.state
 var handoff=[false];var restored=[false]
 var observe_return=func():
  if app.stage.visible:handoff[0]=true
  elif handoff[0] and not restored[0]:
   restored[0]=true
   var pair=Vector3(8.5,0,4);var screen=camera.unproject_position(pair);var middle=camera.get_viewport().get_visible_rect().size*.5
   assert(screen.distance_to(middle)<120 and camera.size<size,"Real arena return reveals a close view around the battle before reaching the saved map framing")
 process_frame.connect(observe_return)
 var a=app.game.units[0];var b=app.game.living("enemy")[0];a.x=8;a.y=4;b.x=9;b.y=4
 await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"damage":1,"remaining":19,"hit":true,"crit":false}],{a.id:20,b.id:20})
 process_frame.disconnect(observe_return);assert(restored[0],"Real cinematic exercised the close map handoff")
 await create_timer(.2).timeout
 assert(camera.transform.is_equal_approx(prior) and is_equal_approx(camera.size,size),"Interrupted map zoom cannot overwrite arena or restored view")
 assert(app.game.rng.state==rng,"Camera gestures never consume gameplay randomness")
 for player in app.sfx_players:player.stop()
 app.music.stop();await create_timer(.15).timeout
 await Shutdown.dispose(app);await process_frame
 print("PASS: pointer-anchored zoom, bounded drag, reset, cursor tracking, continuous pair-centered return, exact view/zoom restoration, cancellation, busy-input lock and cinematic ownership")
 quit()
