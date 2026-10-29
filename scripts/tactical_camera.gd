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
 motion.tween_property(camera,"position",eye_offset+focus,duration)
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

func keep_visible(point: Vector3,occlusion=Rect2()):
 var projected=camera.unproject_position(point);var safe=safe_rect()
 var desired=projected.clamp(safe.position,safe.end)
 if occlusion.has_area() and occlusion.grow(16).has_point(desired):desired.y=minf(safe.end.y,occlusion.end.y+20)
 if projected.distance_to(desired)<1:return
 stop();var target=ground_at(desired)
 if target!=null:camera.position+=point-target;limit_position()
