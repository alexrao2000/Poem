extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
const Transition=preload("res://scripts/combat_transition.gd")
# Measure projected ground anchors rather than relying on screenshots. Exercise
# bounded drag, interrupted zoom, cursor tracking and the real cinematic handoff.
func _initialize():call_deferred("run")
func check_details(app,visible: bool):
 assert(app.markers.visible==visible,"Tactical tile overlays follow map control ownership")
 for actor in app.unit_nodes.values():
  assert(actor.tactical_details_visible==visible and actor.health.visible==visible)
  assert(actor.sprite.visible and actor.marker.visible,"Cinematic approaches keep character sprites and contact shadows")
  assert(actor.ring.visible==(visible and actor.selected))
  for icon in [actor.commander_insignia,actor.rescue_marker,actor.carry_marker,actor.shared_marker]:
   if is_instance_valid(icon):assert(icon.visible==visible,"Every applicable status badge follows tactical ownership")
func check_opening_aperture(app,veil,focus: Vector3,units: Array,dimensions: Vector2i):
 var frame=Rect2(Vector2.ZERO,Vector2(dimensions))
 var projected=app.camera.unproject_position(focus)
 var mask=veil.aperture_rect(projected)
 var center=mask.get_center()
 assert(mask.encloses(frame) and center.is_equal_approx(projected-Vector2(0,frame.size.y*.08)),"Opening shade tracks the projected pair and covers the viewport")
 var gradient=Transition.aperture_mask().gradient
 var radius=mask.size.x*.5
 for unit in units:
  var box=app.unit_nodes[unit.id].screen_bounds(app.camera)
  for point in [box.position,box.end,Vector2(box.position.x,box.end.y),Vector2(box.end.x,box.position.y)]:
   assert(gradient.sample(center.distance_to(point)/radius).a<=.01,"The vignette leaves both enlarged sprites clear")
 var edge_alpha=0.0
 for point in [frame.position,frame.end,Vector2(0,frame.size.y),Vector2(frame.size.x,0)]:
  edge_alpha=maxf(edge_alpha,gradient.sample(center.distance_to(point)/radius).a)
 assert(edge_alpha>=.70,"At least one far corner shows a clear peripheral fade")

func visible_combat_zoom():
 var viewport=SubViewport.new();viewport.size=Vector2i(1440,900);viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-visible-zoom-%d.json"%Time.get_ticks_usec();viewport.add_child(app);await process_frame
 app.debug_session.begin(app.game,"camp");var count=0
 for dimensions in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
  viewport.size=dimensions;await process_frame
  for sample in [["lyra","iron_sword"],["oren","javelin"],["sera","longbow"]]:
   var setup=app.debug_session.start_recruit_encounter(app.game,sample[0],"",sample[1]);app.make_map();app.show_battle();await process_frame
   var a=app.game.units.filter(func(unit):return unit.id==setup.actor)[0];var b=app.game.units.filter(func(unit):return unit.id==setup.target)[0]
   for pair in [[a,b],[b,a]]:app.unit_nodes[pair[0].id].face_toward(app.game.pos(pair[1]),app.game.pos(pair[0]))
   var focus=(app.map_position(app.game.pos(a))+app.map_position(app.game.pos(b)))*.5
   var saved=app.game.save_data("battle").duplicate(true);var random=app.game.rng.state
   for zoom in [8.0,16.0,24.0]:
    for panned in [false,true]:
     app.map_camera();app.camera.size=zoom
     if panned:app.camera.position+=Vector3(1.5,0,-1)
     var original=app.map_navigation.capture_view();var initial=app.unit_nodes[a.id].screen_bounds(app.camera).size.y
     var subjects=[app.unit_nodes[a.id],app.unit_nodes[b.id]]
     var approach=app.map_navigation.approach_combat(focus,.42,subjects);approach.pause()
     var veil=Transition.new();veil.configure(app.ui);var fade=veil.conceal();fade.pause()
     approach.custom_step(.42*.5);fade.custom_step(.42*.5)
     assert(veil.cover_alpha()==0 and app.unit_nodes[a.id].screen_bounds(app.camera).size.y>=initial*(1.15 if zoom==8 else 1.45),"The sprite zoom becomes visible before the covering fade starts")
     approach.custom_step(.42*.26);fade.custom_step(.42*.26)
     assert(is_equal_approx(veil.cover_alpha(),.5))
     check_opening_aperture(app,veil,focus,[a,b],dimensions)
     var minimum=1.4 if zoom==8 else 2.5 if zoom==16 else 3.5
     assert(app.unit_nodes[a.id].screen_bounds(app.camera).size.y>=initial*minimum,"Useful sprite enlargement must happen while the map is still visible")
     for unit in [a,b]:assert(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(app.unit_nodes[unit.id].screen_bounds(app.camera)),"Both combatants remain inside the actual viewport during the enlarged handoff")
     approach.custom_step(.42*.24+.001);fade.custom_step(.42*.24+.001)
     assert(is_equal_approx(app.camera.size,5.0) and veil.cover_alpha()==1,"The existing fully covered endpoint is retained")
     var returning=app.map_navigation.return_from_combat(app.map_navigation.capture_view(),original);returning.pause();returning.custom_step(.251)
     assert(app.map_navigation.capture_view()==original);app.map_navigation.stop();veil.free();count+=1
   assert(app.game.save_data("battle")==saved and app.game.rng.state==random)
 assert(count==54 and not FileAccess.file_exists(app.save_path) and not FileAccess.file_exists(app.save_path+".debug"))
 await Shutdown.dispose(app);viewport.queue_free();await process_frame

func offscreen_combat_zoom():
 var viewport=SubViewport.new();viewport.size=Vector2i(1440,900);viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-offscreen-zoom-%d.json"%Time.get_ticks_usec();viewport.add_child(app);await process_frame
 app.debug_session.begin(app.game,"camp")
 var count=0;var offscreen=0;var widened=0
 for sample in [["lyra","iron_sword"],["oren","javelin"],["sera","longbow"]]:
  var setup=app.debug_session.start_recruit_encounter(app.game,sample[0],"",sample[1],5)
  app.make_map();app.show_battle();await process_frame
  var first=app.unit_nodes[setup.actor];var second=app.unit_nodes[setup.target];var subjects=[first,second]
  var focus=(first.position+second.position)*.5
  var extent=app.game.board_size();var center=Vector3((extent.x-1)*.5,0,(extent.y-1)*.5)
  var homes=[Vector3(-1,0,-1),Vector3(extent.x,0,-1),Vector3(-1,0,extent.y),Vector3(extent.x,0,extent.y),center]
  var saved=app.game.save_data("battle").duplicate(true)
  for dimensions in [Vector2i(720,640),Vector2i(720,960),Vector2i(1024,640),Vector2i(1440,900)]:
   viewport.size=dimensions;await process_frame
   var frame=Rect2(Vector2.ZERO,Vector2(dimensions))
   for home in homes:
    app.map_camera();app.camera.size=8.0;app.camera.position+=home-center
    var initial=app.map_navigation.capture_view()
    if not frame.encloses(app.map_navigation.combat_bounds(subjects)):offscreen+=1
    var push=app.map_navigation.approach_combat(focus,.42,subjects);push.pause()
    assert(app.map_navigation.capture_view()==initial,"The framing check preserves the live starting camera exactly")
    push.custom_step(.21)
    assert(frame.encloses(app.map_navigation.combat_bounds(subjects)),"Both sprites are fully visible before concealment at %s from %s with %s"%[dimensions,home,sample[1]])
    push.custom_step(.211)
    var settled=app.map_navigation.capture_view()
    assert(frame.grow(-17).encloses(app.map_navigation.combat_bounds(subjects)),"The final close view has room around both figures")
    if settled.size>5.0:widened+=1
    var returning=app.map_navigation.return_from_combat(settled,initial);returning.pause();returning.custom_step(.251)
    assert(app.map_navigation.capture_view()==initial,"A fitted close view returns to the exact previous map")
    count+=1
  assert(app.game.save_data("battle")==saved,"Fitting an offscreen exchange leaves the full save and RNG untouched")
 assert(count==60 and offscreen>=40 and widened==5)
 assert(not FileAccess.file_exists(app.save_path) and not FileAccess.file_exists(app.save_path+".debug"))
 await Shutdown.dispose(app);viewport.queue_free();await process_frame
 print("PASS: sixty combat entries bring both sprites into view before concealment, including %d initially offscreen and five fitted narrow longbow shots"%offscreen)

func verify_transition_palette(app):
 var inks={}
 for chapter in app.CHAPTER_LIGHTING.values():
  var horizon=Color(chapter.horizon)
  var veil=Transition.new();veil.configure(app.ui,Callable(),horizon)
  assert(veil.ink.a==1 and veil.ink.get_luminance()<.19)
  assert(veil.cool_streak!=Transition.COOL_STREAK and veil.warm_streak!=Transition.WARM_STREAK)
  inks[veil.ink]=true
  veil.free()
 assert(inks.size()==12,"The transition palette distinguishes all twelve chapter horizons")

func check_home_edges(camera: Camera3D,board: Vector2i):
 var frame=camera.get_viewport().get_visible_rect().grow(-18)
 for x in [-.5,board.x-.5]:
  for y in [-.5,board.y-.5]:
   var corner=Vector3(x,0,y)
   assert(not camera.is_position_behind(corner) and frame.has_point(camera.unproject_position(corner)),
    "Home shows every outer edge of %s at %s"%[board,frame.size+Vector2(36,36)])

func fitted_map_home():
 var viewport=SubViewport.new();viewport.size=Vector2i(1440,900)
 viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path=""
 viewport.add_child(app);await process_frame
 var original=app.game.info().map
 var campaign=app.game.save_data("camp");var layouts=0
 for dimensions in [Vector2i(720,640),Vector2i(720,960),Vector2i(1024,640),Vector2i(1440,900)]:
  viewport.size=dimensions;await process_frame
  for board in [Vector2i(14,10),Vector2i(10,25),Vector2i(26,12),Vector2i(18,34),Vector2i(8,8)]:
   var rows=[]
   for y in range(board.y):rows.append(".".repeat(board.x))
   app.game.info().map=rows
   app.map_camera()
   check_home_edges(app.camera,board);assert(app.map_navigation.at_home())
   if board==Vector2i(14,10) and dimensions.x>=1024:
    assert(app.camera.size==16 and app.camera.h_offset==2 and app.camera.v_offset==0,
     "An already fitted original board keeps the desktop framing")
   layouts+=1
 app.game.info().map=original
 assert(app.game.save_data("camp")==campaign,"Framing and resizing the map never change campaign data")
 app.game.start_battle();app.make_map();app.show_battle();await process_frame
 var nav=app.map_navigation;var camera=app.camera;var board=app.game.board_size()
 var desktop=nav.capture_view();var battle=app.game.save_data("battle")
 viewport.size=Vector2i(720,640);await process_frame
 assert(nav.at_home() and nav.capture_view()!=desktop)
 check_home_edges(camera,board)
 var commands=app.side.get_parent().get_global_rect()
 var terrain=app.terrain_card.get_global_rect()
 for unit in app.game.units:
  var figure=app.unit_nodes[unit.id]
  var bounds=figure.screen_bounds(camera)
  assert(not commands.intersects(bounds) and not terrain.intersects(bounds),"Home keeps both armies clear of the narrow tactical panels")
  var position=app.game.pos(unit)
  assert(app.map_tile_at(camera.unproject_position(app.map_position(position)))==position,"The visible narrow Home tiles still pick exactly")
 var foe=app.game.living("enemy")[0]
 var aim=app.unit_nodes[foe.id].screen_bounds(camera).get_center()
 for pressed in [true,false]:
  var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=pressed;click.position=aim
  viewport.push_input(click,true)
 assert(app.selected==foe,"A real pointer click reaches the previously hidden enemy")
 app.cancel_selection()
 var anchor=viewport.get_visible_rect().get_center()
 nav.zoom(3,anchor);await nav.motion.finished
 nav.begin_drag(anchor);nav.drag(anchor+Vector2(25,20));nav.dragging=false
 var manual=nav.capture_view()
 viewport.size=Vector2i(720,960);await process_frame
 assert(nav.capture_view()==manual,"Resizing preserves a deliberate pan and zoom")
 var key=InputEventKey.new();key.keycode=KEY_HOME;key.pressed=true;app._input(key)
 assert(nav.at_home() and camera.size>desktop.size)
 check_home_edges(camera,board)
 var fitted=nav.capture_view()
 nav.zoom(-100,anchor);await nav.motion.finished
 assert(is_equal_approx(camera.size,fitted.size*1.5),"Zoom-out respects the fitted portrait home size")
 assert(app.game.save_data("battle")==battle)
 await verify_forecast_opening(app,viewport)
 await Shutdown.dispose(app);viewport.queue_free();await process_frame
 print("PASS: %d complete default map views, live Home resizing, exact manual framing and fitted portrait zoom bounds"%layouts)

func verify_forecast_opening(app,viewport: SubViewport):
 viewport.size=Vector2i(720,640);await process_frame
 var ally=app.game.living("player")[0];var foe=app.game.living("enemy")[0]
 for pair in [[ally,Vector2i(2,3)],[foe,Vector2i(3,3)]]:
  var occupant=app.game.at(pair[1]);var origin=app.game.pos(pair[0])
  if occupant!=null and occupant!=pair[0]:occupant.x=origin.x;occupant.y=origin.y
  pair[0].x=pair[1].x;pair[0].y=pair[1].y
 app.refresh_pieces();app.map_camera()
 var home=app.map_navigation.capture_view()
 var saved=app.game.save_data("battle").duplicate(true)
 app.click_tile(app.game.pos(ally));app.click_tile(app.game.pos(foe))
 assert(app.target==foe and app.map_navigation.at_home())
 for size in [Vector2i(720,640),Vector2i(720,960),Vector2i(720,640)]:
  viewport.size=size;await process_frame;await process_frame
  var opening=app.forecast_panel.map_opening(app.terrain_card.get_rect().end.y)
  var pair=[app.unit_nodes[ally.id],app.unit_nodes[foe.id]]
  var formation=app.map_navigation.combat_bounds(pair)
  assert(opening.grow(1).encloses(formation),
   "In a narrow forecast at %s, both map sprites (%s) fit between the portraits (%s)"%[size,formation,opening])
 app.cancel_selection()
 assert(app.forecast_panel==null and app.map_navigation.capture_view()==home)
 assert(app.game.save_data("battle")==saved)
 print("PASS: a narrow forecast keeps both tactical sprites clear across resizes and restores the exact Home view on dismissal")

func resized_combat_return():
 var viewport=SubViewport.new();viewport.size=Vector2i(1440,900);viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 root.add_child(viewport)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-resized-combat-return-%d.json"%Time.get_ticks_usec()
 viewport.add_child(app);await process_frame
 var nav=app.map_navigation
 for fixture in [["arena",Vector2i(720,960),true],["opening Skip",Vector2i(720,640),true],["map reveal",Vector2i(720,960),true],["arena",Vector2i(720,960),false]]:
  viewport.size=Vector2i(1440,900);await process_frame
  app.game.new_campaign();app.game.start_battle();app.make_map();app.show_battle();await process_frame
  var attacker=app.game.living("player").filter(func(unit):return unit.id=="sera")[0]
  var target=app.game.living("enemy")[0]
  attacker.x=6;attacker.y=4;target.x=8;target.y=4
  app.refresh_pieces()
  if not fixture[2]:
   app.camera.size*=.85
   app.camera.position+=Vector3(-.7,0,.4)
  else:
   app.camera.fov=62
   nav.configure(app.camera,app.game.board_size())
  assert(nav.at_home()==fixture[2])
  var original=nav.capture_view();var events=app.game.combat(attacker,target)
  var saved=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state
  var resized=[false]
  var resize=func():
   if resized[0]:return
   var veil=app.ui.get_node_or_null("CombatTransition")
   if veil==null:return
   match fixture[0]:
    "arena":
     if not app.ui.has_node("CombatHUD"):return
    "opening Skip":
     if veil.revealing or veil.progress<.12 or app.stage.visible:return
     app.ui.get_node("CombatPlayback").request_skip()
    "map reveal":
     if not veil.revealing or app.stage.visible or veil.progress>=.95:return
   viewport.size=fixture[1];resized[0]=true
  app.busy=true;process_frame.connect(resize)
  await app.cinematic(attacker,target,events)
  process_frame.disconnect(resize);app.busy=false
  assert(resized[0] and viewport.size==fixture[1],"The real encounter reached the requested resize point")
  assert(app.unit_nodes.values().all(func(visual):return is_zero_approx(visual.cutaway_dim)),"Returning from combat clears bystander dimming after resize or opening Skip")
  if fixture[2]:
   assert(nav.at_home() and nav.capture_view()!=original and app.camera.fov==original.fov,"An arena return fits Home to the new viewport without losing the saved lens")
   check_home_edges(app.camera,app.game.board_size())
   var returned=nav.capture_view()
   app.map_camera();assert(nav.capture_view()==returned,"Returning Home matches the useful default for the new viewport")
  else:
   assert(nav.capture_view()==original and not nav.at_home(),"A deliberate map view returns exactly after the combat resize")
  assert(app.game.save_data("battle")==saved and app.game.rng.state==rng)
 await Shutdown.dispose(app);viewport.queue_free();await process_frame
 print("PASS: resizing during the arena, opening Skip or map reveal refits Home; a manual view restores exactly")

func run():
 await fitted_map_home()
 await resized_combat_return()
 await visible_combat_zoom()
 await offscreen_combat_zoom()
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-map-camera.json"
 root.add_child(app);await process_frame
 verify_transition_palette(app)
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
 camera.size=8.5;camera.position+=Vector3(7.5,0,-5.5)
 var prior=camera.transform;var size=camera.size;var rng=app.game.rng.state
 var a=app.game.units[0];var b=app.game.living("enemy")[0];a.x=8;a.y=4;b.x=9;b.y=4
 app.refresh_pieces()
 var subjects=[app.unit_nodes[a.id],app.unit_nodes[b.id]]
 var frame=camera.get_viewport().get_visible_rect()
 assert(not frame.encloses(nav.combat_bounds(subjects)),"The actual exchange starts from a camera panned away from its participants")
 var handoff=[false];var restored=[false];var checked_tint=[false];var visible_before_cut=[false]
 var horizon=app.environment.sky.sky_material.sky_horizon_color
 var expected_ink=Transition.INK.lerp(horizon.darkened(.81),.52)
 var observe_return=func():
  if app.ui.get_node_or_null("CombatPlayback")!=null:check_details(app,false)
  var veil=app.ui.get_node_or_null("CombatTransition")
  if veil!=null:
   assert(veil.ink.is_equal_approx(expected_ink),"The actual map and arena fade keep the battlefield's dusk tint")
   checked_tint[0]=true
   if not handoff[0] and veil.progress>=.5 and veil.progress<=.62 and frame.encloses(nav.combat_bounds(subjects)):
    visible_before_cut[0]=true
  if app.stage.visible:handoff[0]=true
  elif handoff[0] and not restored[0]:
   restored[0]=true
   var pair=Vector3(8.5,0,4);var screen=camera.unproject_position(pair);var middle=camera.get_viewport().get_visible_rect().size*.5
   assert(screen.distance_to(middle)<120 and camera.size<size,"Real arena return reveals a close view around the battle before reaching the saved map framing")
 process_frame.connect(observe_return)
 await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"damage":1,"remaining":19,"hit":true,"crit":false}],{a.id:20,b.id:20})
 process_frame.disconnect(observe_return)
 assert(restored[0] and checked_tint[0] and visible_before_cut[0],"Real cinematic finds the offscreen units before cutting and restores the player's view")
 check_details(app,true)
 await create_timer(.2).timeout
 assert(camera.transform.is_equal_approx(prior) and is_equal_approx(camera.size,size),"Interrupted map zoom cannot overwrite arena or restored view")
 assert(app.game.rng.state==rng,"Camera gestures never consume gameplay randomness")
 for player in app.sfx_players:player.stop()
 app.music.stop();await create_timer(.15).timeout
 await Shutdown.dispose(app);await process_frame
 print("PASS: 54 actual-viewport melee/ranged sprite zooms visible before concealment, unchanged endpoints/state/files, pointer-anchored zoom, bounded drag, reset, cursor tracking, continuous pair-centered return, exact view/zoom restoration, cancellation, busy-input lock and cinematic ownership")
 quit()
