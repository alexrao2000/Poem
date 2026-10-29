extends SceneTree
# Measure projected ground anchors rather than relying on screenshots. Exercise
# bounded drag, interrupted zoom, cursor tracking and the real cinematic handoff.
var approach_distance=INF
func watch_approach(app,focus):
 while app.world.visible:
  var projected=app.camera.unproject_position(focus)
  approach_distance=minf(approach_distance,projected.distance_to(app.camera.get_viewport().get_visible_rect().size*.5))
  await process_frame

func _initialize():call_deferred("run")
func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/ashen-map-camera.json"
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
 app.cursor_visible=true
 for corner in [Vector2i.ZERO,Vector2i(13,0),Vector2i(0,9),Vector2i(13,9)]:
  app.cursor_tile=corner;app.move_map_cursor(Vector2i.ZERO)
  var projected=camera.unproject_position(Vector3(corner.x,0,corner.y))
  assert(nav.safe_rect().grow(.01).has_point(projected) and not app.terrain_card.get_global_rect().has_point(projected),"Keyboard tracking keeps every board corner clear of terrain and command panels")
 nav.zoom(-100,anchor);await nav.motion.finished;assert(camera.size==24,"Zoom-out is bounded")
 app.map_camera()
 var wheel=InputEventMouseButton.new();wheel.pressed=true;wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.position=anchor
 app.busy=true;app._unhandled_input(wheel);assert(camera.size==16 and nav.zoom_goal==16,"Busy actions ignore map gestures")
 app.busy=false;app._unhandled_input(wheel);await create_timer(.035).timeout
 camera.position+=Vector3(3,0,-2)
 var prior=camera.transform;var size=camera.size;var rng=app.game.rng.state
 var a=app.game.units[0];var b=app.game.living("enemy")[0];a.x=8;a.y=4;b.x=9;b.y=4
 watch_approach(app,Vector3(8.5,0,4))
 await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"damage":1,"remaining":19,"hit":true,"crit":false}],{a.id:20,b.id:20})
 assert(approach_distance<25,"Combat zoom centers the engaged pair even after the tactical map was panned")
 await create_timer(.2).timeout
 assert(camera.transform.is_equal_approx(prior) and is_equal_approx(camera.size,size),"Interrupted map zoom cannot overwrite arena or restored view")
 assert(app.game.rng.state==rng,"Camera gestures never consume gameplay randomness")
 for player in app.sfx_players:player.stop()
 app.music.stop();await create_timer(.15).timeout
 app.queue_free();await process_frame
 print("PASS: pointer-anchored zoom, bounded drag, reset, cursor tracking, busy-input lock and cinematic ownership")
 quit()
