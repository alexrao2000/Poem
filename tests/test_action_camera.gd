extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
const Navigation=preload("res://scripts/tactical_camera.gd")
var movement_done=false
var saw_cue=false
var cue_types={}
var cue_layouts=0
var cue_recipient: Dictionary={}
var cue_attacker: Dictionary={}

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
  var label=Label.new();label.add_theme_font_size_override("font_size",28);viewport.add_child(label)
  for origin in [Vector3(-1,0,-1),Vector3(14,0,10)]:
   for cell in range(140):
    var point=Vector3(cell%14,.1 if cell%3==0 else 0.0,cell/14)
    for text in ["3","MISS","NO DAMAGE","CRIT 999","+999"]:
     label.text=text;var extent=label.get_minimum_size()
     camera.position=nav.eye_offset+origin
     camera.position=nav.action_destination(action_points([point]),occlusion,Vector2(maxf(18,extent.x*.5+8),50))
     var top=camera.unproject_position(point+Vector3.UP*1.1)-Vector2(extent.x*.5,44)
     var travel_bounds=Rect2(top,extent+Vector2(0,24)).grow(5)
     assert(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(travel_bounds),"Full text, outline and rising animation stay on screen at every tile and opposite pan origin")
     assert(not travel_bounds.intersects(occlusion),"Rising damage, miss, guard and recovery text cannot pass behind the terrain card")
     cue_layouts+=1
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
 var recipient=app.game.living("player")[0];unit.x=11;unit.y=8;recipient.x=13;recipient.y=8;app.refresh_pieces();cue_recipient=recipient;cue_attacker=unit
 app.camera.position=app.map_navigation.eye_offset+Vector3(-1,0,-1)
 saved=app.game.save_data("battle").duplicate(true)
 await app.map_combat_feedback([{"actor":unit.id,"target":recipient.id,"damage":3,"hit":true,"crit":false,"remaining":recipient.hp}])
 assert(saw_cue and app.game.save_data("battle")==saved and app.game.rng.state==rng,"Off-screen map-only result is framed without reapplying damage")
 unit.x=1;unit.y=0;recipient.x=0;recipient.y=0;app.refresh_pieces();cue_recipient=recipient
 saved=app.game.save_data("battle").duplicate(true)
 for content in ["NO DAMAGE","MISS","CRIT 999"]:
  app.camera.position=app.map_navigation.eye_offset+Vector3(14,0,10)
  app.terrain_card.inspect(app.game,app.game.pos(recipient));app.terrain_card.show()
  await app.map_combat_feedback([{"actor":unit.id,"target":recipient.id,"damage":999 if content=="CRIT 999" else 0,"hit":content!="MISS","crit":content=="CRIT 999","remaining":recipient.hp}])
  assert(cue_types.has(content),"Actual map result text was observed: "+content)
  assert(app.unit_nodes[recipient.id].position==app.map_position(app.game.pos(recipient)),"Evasion returns the sprite to its canonical tile before field control resumes")
  assert(app.map_facings[recipient.id]=="east" and app.unit_nodes[recipient.id].player.facing=="east","Defenders face the incoming attacker and keep that facing after refresh")
 var interrupted=app.unit_nodes[recipient.id];var tile_position=app.map_position(app.game.pos(recipient))
 interrupted.recoil_from(app.game.pos(unit),app.game.pos(recipient),true)
 await process_frame;await process_frame
 assert(interrupted.position.distance_to(tile_position)>.001,"Interrupted recoil fixture has actually moved")
 interrupted.finish_move()
 assert(interrupted.position==tile_position and not interrupted.reaction_motion.is_valid(),"Cancelling a reaction restores the exact tile immediately")
 app.camera.position=app.map_navigation.eye_offset+Vector3(14,0,10)
 await app.map_heal_feedback(recipient,recipient,999)
 assert(cue_types.has("+999") and app.game.save_data("battle")==saved and app.game.rng.state==rng,"Recovery centering and text framing change no resolved game state")
 for player in app.sfx_players:player.stop()
 app.music.stop();await create_timer(.15).timeout;await Shutdown.dispose(app);await process_frame
 print("PASS: %d action frames and %d full floating-text layouts, opposite pan origins, bounded tracking, real movement/damage/miss/guard/recovery cues and unchanged simulation"%[measurements,cue_layouts])
 quit()

func run_movement(app,unit,path):
 await app.animate_map_move(unit,path);movement_done=true

func watch_cue(node,app):
 if not node is Label:return
 await process_frame
 if node.text not in ["3","NO DAMAGE","MISS","CRIT 999","+999"]:return
 saw_cue=true;cue_types[node.text]=true
 if node.text=="MISS":
  var victim=app.unit_nodes[cue_recipient.id];var base=app.map_position(app.game.pos(cue_recipient))
  assert(victim.position.distance_to(base)>.12 and is_equal_approx(victim.position.x,base.x) and is_equal_approx(victim.position.y,base.y),"Actual missed attack shows a perpendicular sidestep with unchanged tile height")
  assert(victim.player.facing=="east","Miss reaction keeps the defender looking toward the incoming attack")
 var target=app.unit_nodes[cue_recipient.id];var tile=app.map_position(app.game.pos(cue_recipient));var largest_recoil=0.0;var content=node.text
 var away=Vector2(app.game.pos(cue_recipient)-app.game.pos(cue_attacker)).normalized()
 var direction=Vector3(away.x,0,away.y)
 while is_instance_valid(node) and not node.is_queued_for_deletion():
  if node.text in ["3","CRIT 999"]:
   var offset=target.position-tile;largest_recoil=maxf(largest_recoil,offset.length())
   assert(absf(offset.y)<.00001 and offset.dot(direction)>=-.00001 and offset.cross(direction).length()<.00001,"Map damage recoils directly away from the attacker without changing tile height")
  elif node.text=="NO DAMAGE":assert(target.position==tile,"A blocked quick-map hit stays planted")
  var bounds=node.get_global_rect().grow(5)
  assert(app.map_navigation.safe_rect().encloses(bounds),"Full floating result remains in the action area throughout its rise and fade")
  assert(not bounds.intersects(app.action_occlusion()),"Actual floating result never passes behind the terrain readout")
  await process_frame
 if content in ["3","CRIT 999"]:
  assert(largest_recoil>=(.138 if content=="CRIT 999" else .078),"Normal and critical map hits show their intended distinct recoil distance")
