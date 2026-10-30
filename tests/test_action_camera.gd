extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
const Navigation=preload("res://scripts/tactical_camera.gd")
var movement_done=false
var saw_cue=false

func _initialize():call_deferred("run")

func action_points(positions: Array) -> Array:
 var points=[]
 for position in positions:points.append(position);points.append(position+Vector3.UP*1.1)
 return points

func check_visible(nav,points,occlusion):
 var bounds=Rect2(nav.camera.unproject_position(points[0]),Vector2.ZERO)
 for point in points:
  var projected=nav.camera.unproject_position(point);bounds=bounds.expand(projected)
  assert(nav.safe_rect().grow(1).has_point(projected),"Full action stays inside the tactical safe area")
 assert(not bounds.intersects(occlusion),"Terrain readout never covers the framed action")

func run():
 var measurements=0
 for dimensions in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
  var viewport=SubViewport.new();viewport.size=dimensions;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
  var camera=Camera3D.new();viewport.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=8
  camera.position=Vector3(9,22,16);camera.look_at(Vector3(6.5,0,4.5));camera.h_offset=2
  var nav=Navigation.new();nav.configure(camera,Vector2i(14,10));var occlusion=Rect2(22,118,238,90)
  for positions in [[Vector3(0,0,0)],[Vector3(13,0,9)],[Vector3(0,.1,9),Vector3(2,.1,9)],[Vector3(11,0,0),Vector3(13,0,0)],[Vector3(0,0,0),Vector3(0,0,2)],[Vector3(13,0,7),Vector3(13,0,9)]]:
   camera.position=nav.eye_offset+Vector3(-1,0,-1)
   var before=camera.position;var points=action_points(positions);var pan=nav.frame_action(points,occlusion,.05)
   assert(camera.position==before,"Attention begins as a tween rather than teleporting")
   if pan!=null:await pan.finished
   check_visible(nav,points,occlusion)
   assert(camera.size==8 and camera.position.y==22 and camera.h_offset==2,"Automatic framing preserves zoom, altitude and lens offset")
   var delta=nav.action_destination(points,occlusion)-camera.position
   assert(nav.frame_action(points,occlusion)==null,"Already-visible actions introduce no extra pause: %s %s %s"%[dimensions,positions,delta])
   measurements+=1
  # Tracking crosses a raised tile without accumulating camera altitude.
  for i in range(121):
   var point=Vector3(13*i/120.0,.1 if i>55 else 0,9*i/120.0)
   var points=action_points([point]);nav.follow_action(points,occlusion);check_visible(nav,points,occlusion)
   assert(camera.position.y==22 and camera.size==8)
  viewport.queue_free();await process_frame
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-action-camera.json";root.add_child(app);await process_frame
 app.game.start_battle();app.make_map();app.show_battle();app.preferences.values.combat="map"
 var unit=app.game.living("enemy")[0];var visual=app.unit_nodes[unit.id]
 var path=[Vector2i(10,6),Vector2i(11,6),Vector2i(12,6),Vector2i(12,7),Vector2i(12,8)]
 var saved=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state
 app.camera.size=8;app.camera.position=app.map_navigation.eye_offset+Vector3(-1,0,-1);app.busy=true
 run_movement(app,unit,path)
 assert(app.moving_id==unit.id,"Action remains locked during the initial camera pan")
 var samples=0
 while not movement_done:
  await process_frame
  if visual.player.state=="move":
   check_visible(app.map_navigation,action_points([visual.position]),app.action_occlusion());samples+=1
 assert(samples>3 and app.game.save_data("battle")==saved and app.game.rng.state==rng,"Following actual movement never changes simulation or RNG")
 assert(visual.position==app.map_position(path[-1]) and app.camera.size==8,"Movement reaches its destination at the player's zoom")
 app.ui.child_entered_tree.connect(func(node):watch_cue(node,app))
 var recipient=app.game.living("player")[0];unit.x=11;unit.y=8;recipient.x=13;recipient.y=8;app.refresh_pieces()
 app.camera.position=app.map_navigation.eye_offset+Vector3(-1,0,-1)
 saved=app.game.save_data("battle").duplicate(true)
 await app.map_combat_feedback([{"actor":unit.id,"target":recipient.id,"damage":3,"hit":true,"crit":false,"remaining":recipient.hp}])
 assert(saw_cue and app.game.save_data("battle")==saved and app.game.rng.state==rng,"Off-screen map-only result is framed without reapplying damage")
 for player in app.sfx_players:player.stop()
 app.music.stop();await create_timer(.15).timeout;await Shutdown.dispose(app);await process_frame
 print("PASS: %d action frames across three viewports, bounded continuous tracking, real enemy movement and visible map-only results without simulation changes"%measurements)
 quit()

func run_movement(app,unit,path):
 await app.animate_map_move(unit,path);movement_done=true

func watch_cue(node,app):
 if not node is Label:return
 await process_frame
 if node.text!="3":return
 saw_cue=true
 assert(app.map_navigation.safe_rect().encloses(node.get_global_rect()),"Damage number is visible when it appears, not after it fades")
