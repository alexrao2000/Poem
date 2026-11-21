extends SceneTree
const Surface=preload("res://scripts/map_surface.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")

# Independent reference: intersect every cell's top rectangle, retaining the
# nearest hit. Lower neighbors can legitimately be hidden by a raised surface.
func reference_pick(origin: Vector3,direction: Vector3,game):
 var nearest=INF;var chosen=null
 for y in range(game.board_size().y):
  for x in range(game.board_size().x):
   var cell=Vector2i(x,y)
   var point=Plane(Vector3.UP,Surface.height_for(game.terrain(cell))).intersects_ray(origin,direction)
   if point==null or point.x<x-.5 or point.x>=x+.5 or point.z<y-.5 or point.z>=y+.5:continue
   var distance=origin.distance_squared_to(point)
   if distance<nearest:nearest=distance;chosen=cell
 return chosen

func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-map-picking.json";root.add_child(app);await process_frame
 var samples=0;var corrected=0
 for dimensions in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
  var viewport=SubViewport.new();viewport.size=dimensions;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
  var camera=Camera3D.new();viewport.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL
  for chapter in range(app.game.content.chapters.size()):
   app.game.chapter=chapter;app.game.start_battle();app.map_camera()
   camera.transform=app.camera.transform;camera.h_offset=app.camera.h_offset
   var saved=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state
   for zoom in [8,16,24]:
    camera.size=zoom;camera.position=app.camera.position+Vector3(zoom*.13,0,-zoom*.09)
    for y in range(app.game.board_size().y):
     for x in range(app.game.board_size().x):
      var cell=Vector2i(x,y);var offsets=[Vector3.ZERO]
      if app.map_height(cell)>0:offsets+=[Vector3(-.49,0,0),Vector3(.49,0,0),Vector3(0,0,-.49),Vector3(0,0,.49)]
      for offset in offsets:
       var pixel=camera.unproject_position(app.map_position(cell)+offset)
       var origin=camera.project_ray_origin(pixel);var direction=camera.project_ray_normal(pixel)
       var result=Surface.tile_at_ray(origin,direction,app.game.board_size(),app.map_height)
       var expected=reference_pick(origin,direction,app.game)
       assert(result==expected,"Raised surface picking agrees with nearest visible tile at every zoom and viewport")
       if offset==Vector3.ZERO:assert(result==cell,"Every map center retains its own tile")
       var flat=Plane(Vector3.UP,0).intersects_ray(origin,direction)
       if result==cell and Vector2i(roundi(flat.x),roundi(flat.z))!=cell:corrected+=1
       samples+=1
   assert(app.game.save_data("battle")==saved and app.game.rng.state==rng,"Pointer sampling changes neither campaign nor gameplay RNG")
  viewport.queue_free();await process_frame
 assert(corrected>700,"Regression samples exercise the former raised-edge slips")
 var bounds=Vector2i(2,2);var flat_height=func(_cell):return 0.0
 for origin in [Vector3(-.51,2,0),Vector3(1.51,2,0),Vector3(0,2,-.51),Vector3(0,2,1.51)]:
  assert(Surface.tile_at_ray(origin,Vector3.DOWN,bounds,flat_height)==null,"Outside-board rays return no tile")
 assert(Surface.tile_at_ray(Vector3(0,2,0),Vector3.UP,bounds,flat_height)==null,"Behind-ray surfaces are ignored")
 assert(Surface.tile_at_ray(Vector3(0,2,0),Vector3.RIGHT,bounds,flat_height)==null,"Parallel rays return no tile")
 # Exercise the actual hover and click handlers at the old sanctuary mismatch.
 app.game.chapter=0;app.game.start_battle();var unit=app.game.living("player")[0]
 app.game.units=[unit];unit.x=3;unit.y=5;unit.acted=false
 app.make_map();app.show_battle();app.selected=unit;app.highlight();app.update_side()
 var destination=Vector2i(3,3);var pixel=app.camera.unproject_position(app.map_position(destination)+Vector3(-.49,0,0))
 var motion=InputEventMouseMotion.new();motion.position=pixel;app._unhandled_input(motion)
 assert(app.last_hover==destination and app.terrain_card.tile==destination,"Real hover inspects the raised destination")
 assert(is_instance_valid(app.route_preview) and app.route_preview.get_child_count()>0,"Real hover draws the selected unit's movement route")
 motion.position=app.camera.unproject_position(Vector3(-10,0,-10));app._unhandled_input(motion)
 assert(not app.terrain_card.visible and app.route_preview.get_child_count()==0,"Leaving the board clears terrain and route hints")
 assert(app.pick_map_unit(pixel)==null,"Ground click fixture does not overlap a unit badge")
 var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=pixel;app._unhandled_input(click)
 while app.busy:await process_frame
 assert(app.game.pos(unit)==destination and app.unit_nodes[unit.id].position==app.map_position(destination),"Real click moves onto the raised tile, ending on its surface")
 app.cancel_selection();assert(app.game.pos(unit)==Vector2i(3,5),"Uncommitted movement can still be cancelled")
 var actor=app.unit_nodes[unit.id];click.position=actor.screen_bounds(app.camera).get_center();app._unhandled_input(click)
 assert(app.selected==unit,"Unit sprite picking retains priority over ground picking")
 await Shutdown.dispose(app);await process_frame
 print("PASS: %d visible-surface projections across 12 chapters, 3 viewports and 3 zooms; %d former edge slips corrected, actual route/click/cancel/unit selection and off-board clearing"%[samples,corrected]);quit()
