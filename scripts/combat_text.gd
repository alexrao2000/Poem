extends Label3D
# Keep a floating result inside the shot without moving its contact effect.
# Projection uses the text quad plus outline, not the billboard culling box.
# Rise and pop retain the intended world motion; only the visible label shifts.

var camera: Camera3D
var anchor=Vector3.ZERO
var corners=PackedVector3Array()
var rise=0.0:
 set(value):rise=value;layout_text()
var pop=1.0:
 set(value):pop=value;layout_text()

func follow(view: Camera3D,point: Vector3):
 camera=view;anchor=point;corners.clear();layout_text()

func layout_text():
 if not is_inside_tree():return
 global_position=anchor+Vector3.UP*rise;scale=Vector3.ONE*pop
 if not is_instance_valid(camera):return
 var depth=-camera.to_local(global_position).z
 if depth<=.01:return
 if corners.is_empty():
  var triangles=generate_triangle_mesh()
  if triangles==null:return
  var points=triangles.get_faces()
  if points.is_empty():return
  var bounds=Rect2(Vector2(points[0].x,points[0].y),Vector2.ZERO)
  for point in points:bounds=bounds.expand(Vector2(point.x,point.y))
  bounds=bounds.grow(outline_size*pixel_size)
  for point in [bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)]:corners.append(Vector3(point.x,point.y,0))
 var screen=Rect2(camera.unproject_position(global_position+camera.global_basis*(corners[0]*pop)),Vector2.ZERO)
 for corner in corners:screen=screen.expand(camera.unproject_position(global_position+camera.global_basis*(corner*pop)))
 var size_value=camera.get_viewport().get_visible_rect().size
 var safe=Rect2(Vector2(24,24),size_value-Vector2(48,184))
 var correction=Vector2(clampf(0,safe.position.x-screen.position.x,safe.end.x-screen.end.x),clampf(0,safe.position.y-screen.position.y,safe.end.y-screen.end.y))
 if not correction.is_zero_approx():global_position=camera.project_position(camera.unproject_position(global_position)+correction,depth)

func _process(_delta):
 if is_visible_in_tree():layout_text()
