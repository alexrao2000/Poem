extends RefCounted
# Orthographic navigation preserves the ground under the pointer when zooming.
# Bounds keep the board recoverable; stopping cancels every pending camera tween
# before cinematic ownership changes. This helper never changes simulation state.
var camera: Camera3D
var board=Vector2i(14,10)
var eye_offset=Vector3.ZERO
var zoom_goal=16.0
var motion: Tween
var dragging=false
var drag_anchor=Vector3.ZERO

func configure(value: Camera3D,dimensions: Vector2i):
 stop();camera=value;board=dimensions;zoom_goal=camera.size
 eye_offset=camera.position-Vector3((board.x-1)*.5,0,(board.y-1)*.5)

func stop():
 if motion and motion.is_valid():motion.kill()
 dragging=false
 if is_instance_valid(camera):zoom_goal=camera.size

func approach_combat(focus: Vector3,duration=.42) -> Tween:
 stop()
 motion=camera.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
 motion.tween_property(camera,"size",5.0,duration)
 motion.tween_property(camera,"h_offset",0.0,duration)
 motion.tween_property(camera,"v_offset",0.0,duration)
 # Orbit around a moving look point, keeping the pair centered as the map
 # angle descends. A single owner also makes interruption/restoration exact.
 var rotation=camera.rotation
 var distance=eye_offset.length()
 var start_focus=camera.position-camera.basis.z*distance
 var heading=Vector3(eye_offset.x,0,eye_offset.z).normalized().rotated(Vector3.UP,.10)
 var destination=(heading*cos(deg_to_rad(38))+Vector3.UP*sin(deg_to_rad(38)))*distance
 var final_rotation=Basis.looking_at(-destination,Vector3.UP).get_euler()
 motion.tween_method(func(weight):
  camera.rotation=Vector3(lerp_angle(rotation.x,final_rotation.x,weight),lerp_angle(rotation.y,final_rotation.y,weight),0)
  camera.position=start_focus.lerp(focus,weight)+camera.basis.z*distance
 ,0.0,1.0,duration)
 return motion

func ground_at(screen_point: Vector2):
 return Plane(Vector3.UP,0).intersects_ray(camera.project_ray_origin(screen_point),camera.project_ray_normal(screen_point))

func limit_position():
 var center=camera.position-eye_offset
 camera.position.x=clampf(center.x,-1.0,board.x)+eye_offset.x
 camera.position.z=clampf(center.z,-1.0,board.y)+eye_offset.z

func zoom(steps: float,screen_point: Vector2):
 var next=clampf(zoom_goal*pow(.86,steps),8.0,maxf(16,board.x+2)*1.5)
 stop();zoom_goal=next
 var before=ground_at(screen_point);var old_position=camera.position;var old_size=camera.size
 camera.size=next
 var after=ground_at(screen_point)
 if before!=null and after!=null:camera.position+=before-after
 limit_position();var destination=camera.position
 camera.position=old_position;camera.size=old_size
 motion=camera.create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
 motion.tween_property(camera,"size",next,.14);motion.tween_property(camera,"position",destination,.14)

func begin_drag(screen_point: Vector2):
 stop();var point=ground_at(screen_point)
 dragging=point!=null
 if dragging:drag_anchor=point

func drag(screen_point: Vector2):
 if not dragging:return
 var point=ground_at(screen_point)
 if point!=null:camera.position+=drag_anchor-point;limit_position()

func safe_rect() -> Rect2:
 var size=camera.get_viewport().get_visible_rect().size
 return Rect2(Vector2(42,122),Vector2(maxf(80,size.x-392),maxf(80,size.y-232)))

# Project the whole action, including sprite height, before choosing the smallest
# camera correction. The same calculation drives the initial pan and tracking.
func action_destination(points: Array,occlusion=Rect2(),padding=Vector2(18,18)) -> Vector3:
 if points.is_empty():return camera.position
 var destination=camera.position;var safe=safe_rect()
 # Clamping one world axis can shift both screen axes in the angled map view.
 # Reproject a proposed translation to settle that correction before tweening.
 for attempt in range(4):
  var offset=destination-camera.position
  var bounds=Rect2(camera.unproject_position(points[0]-offset),Vector2.ZERO)
  for point in points:bounds=bounds.expand(camera.unproject_position(point-offset))
  bounds=Rect2(bounds.position-padding,bounds.size+padding*2)
  var shift=Vector2.ZERO
  for axis in range(2):
   shift[axis]=clampf(0,safe.position[axis]-bounds.position[axis],safe.end[axis]-bounds.end[axis]) if bounds.size[axis]<=safe.size[axis] else safe.get_center()[axis]-bounds.get_center()[axis]
  var placed=Rect2(bounds.position+shift,bounds.size)
  if occlusion.has_area() and placed.intersects(occlusion.grow(16)):
   var down=occlusion.end.y+16-placed.position.y
   var right=occlusion.end.x+16-placed.position.x
   if placed.end.y+down<=safe.end.y:shift.y+=down
   elif placed.end.x+right<=safe.end.x:shift.x+=right
  if shift.length()<1:break
  var source=ground_at(safe.get_center());var target=ground_at(safe.get_center()+shift)
  if source==null or target==null:break
  var previous=destination;destination+=source-target
  destination.x=clampf(destination.x-eye_offset.x,-1.0,board.x)+eye_offset.x
  destination.z=clampf(destination.z-eye_offset.z,-1.0,board.y)+eye_offset.z
  if previous.distance_to(destination)<.0001:break
 return destination

func frame_action(points: Array,occlusion=Rect2(),duration=.22,padding=Vector2(18,18)) -> Tween:
 stop();var destination=action_destination(points,occlusion,padding)
 if camera.position.distance_to(destination)<.0001:return null
 motion=camera.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
 motion.tween_property(camera,"position",destination,duration)
 return motion

func follow_action(points: Array,occlusion=Rect2()):
 camera.position=action_destination(points,occlusion)

func keep_visible(point: Vector3,occlusion=Rect2()):
 var projected=camera.unproject_position(point);var safe=safe_rect()
 var desired=projected.clamp(safe.position,safe.end)
 if occlusion.has_area() and occlusion.grow(16).has_point(desired):desired.y=minf(safe.end.y,occlusion.end.y+20)
 if projected.distance_to(desired)<1:return
 stop();var source=ground_at(projected);var target=ground_at(desired)
 if source!=null and target!=null:camera.position+=source-target;limit_position()
