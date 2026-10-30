extends Node
# Fit the whole rotating outfit inside the space beside its controls. Sample
# procedural actions once so replaying a pose does not pump the camera; retain
# live expansion for cloth, interrupted transitions and optional imported rigs.

const Actor=preload("res://scripts/fighter_actor.gd")
var actor: Node3D
var camera: Camera3D
var controls: Control
var geometry=[]
var radius=0.0
var low=INF
var high=-INF
var last_rect=Rect2()
var last_size=Vector2.ZERO
var zoom=1.0
var dragging=false
var face_height=1.8
var hint: Label

func configure(subject: Node3D,view: Camera3D,panel: Control,poses: Array):
 actor=subject;camera=view;controls=panel
 for mesh in actor.find_children("*","MeshInstance3D",true,false):
  if mesh.mesh==null:continue
  var corners=[];var box=mesh.mesh.get_aabb()
  for index in range(8):corners.append(box.get_endpoint(index))
  geometry.append([mesh,corners,mesh.mesh])
 if actor is Actor:
  for key in poses:
   actor.pose("idle",1).custom_step(1)
   var motion=actor.pose(key,1)
   for step in range(4):
    motion.custom_step(.25);actor.apply_constraints();measure()
  actor.pose("idle",1).custom_step(1);actor.apply_constraints()
 measure()
 radius+=.08;low-=.08;high+=.08
 face_height=actor.socket_position("gaze").y-actor.global_position.y if actor.has_method("socket_position") else high-.2
 reframe()

func measure() -> bool:
 var before=Vector3(radius,low,high)
 var inverse=actor.global_transform.affine_inverse()
 for entry in geometry:
  var mesh=entry[0]
  if not is_instance_valid(mesh) or not mesh.visible:continue
  if entry[2]!=mesh.mesh:
   entry[1].clear();entry[2]=mesh.mesh
   for index in range(8):entry[1].append(mesh.mesh.get_aabb().get_endpoint(index))
  var local=inverse*mesh.global_transform
  for point in entry[1]:
   var vertex=local*point
   radius=maxf(radius,Vector2(vertex.x,vertex.z).length())
   low=minf(low,vertex.y);high=maxf(high,vertex.y)
 return before!=Vector3(radius,low,high)

func clear_rect() -> Rect2:
 var size=camera.get_viewport().get_visible_rect().size
 var left=controls.get_global_rect().end.x+28
 return Rect2(left,28,maxf(64,size.x-left-28),maxf(64,size.y-56))

func reframe():
 var size=camera.get_viewport().get_visible_rect().size
 var area=clear_rect();last_size=size;last_rect=controls.get_global_rect()
 camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.keep_aspect=Camera3D.KEEP_HEIGHT;camera.fov=35;camera.v_offset=0
 var center=actor.global_position+Vector3(0,(low+high)*.5,0)
 var backward=Vector3(0,.10,1).normalized()
 camera.position=center+backward;camera.look_at(center)
 var inverse=camera.global_basis.inverse()
 var focal=size.y/(2*tan(deg_to_rad(camera.fov)*.5))
 var shift=area.get_center().x-size.x*.5
 var distance=1.0
 for x in [-radius,radius]:
  for y in [low,high]:
   for z in [-radius,radius]:
    var point=inverse*Vector3(x,y-(low+high)*.5,z)
    distance=maxf(distance,point.z+absf(point.x*focal+shift*point.z)/(area.size.x*.5))
    distance=maxf(distance,point.z+absf(point.y*focal)/(area.size.y*.5))
 distance*=zoom
 center.y=lerpf(center.y,actor.global_position.y+face_height-.1,clampf((1.0-zoom)/.4,0,1))
 camera.position=center+backward*distance
 camera.h_offset=-shift*distance/focal
 if is_instance_valid(hint):
  var host_size=hint.get_parent().size
  hint.position=Vector2(area.position.x,host_size.y-25);hint.size=Vector2(maxf(0,host_size.x-area.position.x-28),20)

func _process(_delta):
 if not is_instance_valid(actor) or not is_instance_valid(controls):return
 var expanded=measure()
 if expanded or last_size!=camera.get_viewport().get_visible_rect().size or last_rect!=controls.get_global_rect():reframe()

func add_hint(parent: Control):
 hint=Label.new();hint.name="PreviewHint";hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
 hint.text="Drag: turn · Scroll: zoom · Double-click: fit";hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 hint.add_theme_font_size_override("font_size",14);hint.add_theme_color_override("font_color",Color("f4e7c6"))
 hint.add_theme_color_override("font_outline_color",Color("253342"));hint.add_theme_constant_override("outline_size",3)
 parent.add_child(hint);reframe()

func _unhandled_input(event):
 if not is_instance_valid(actor) or not is_instance_valid(controls) or not actor.is_visible_in_tree():return
 if not event is InputEventMouseButton or not event.pressed or not clear_rect().has_point(event.position):return
 if event.button_index==MOUSE_BUTTON_LEFT:
  if event.double_click:zoom=1.0;dragging=false;reframe()
  else:dragging=true
 elif event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
  zoom=clampf(zoom*(.88 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/.88),.6,1.3);reframe()
 else:return
 get_viewport().set_input_as_handled()

func _input(event):
 if not dragging:return
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
  dragging=false;get_viewport().set_input_as_handled()
 elif event is InputEventMouseMotion:
  if (event.button_mask & MOUSE_BUTTON_MASK_LEFT)==0:dragging=false;return
  actor.rotation.y=wrapf(actor.rotation.y+event.relative.x*.009,-PI,PI)
  get_viewport().set_input_as_handled()

func _notification(what):
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT:dragging=false

func _exit_tree():
 if is_instance_valid(hint):hint.queue_free()
