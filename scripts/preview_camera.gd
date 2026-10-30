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

func configure(subject: Node3D,view: Camera3D,panel: Control,poses: Array):
 actor=subject;camera=view;controls=panel
 for mesh in actor.find_children("*","MeshInstance3D",true,false):
  if mesh.mesh==null:continue
  var corners=[];var box=mesh.mesh.get_aabb()
  for index in range(8):corners.append(box.get_endpoint(index))
  geometry.append([mesh,corners])
 if actor is Actor:
  for key in poses:
   actor.pose("idle",1).custom_step(1)
   var motion=actor.pose(key,1)
   for step in range(4):
    motion.custom_step(.25);actor.apply_constraints();measure()
  actor.pose("idle",1).custom_step(1);actor.apply_constraints()
 measure()
 radius+=.08;low-=.08;high+=.08
 reframe()

func measure() -> bool:
 var before=Vector3(radius,low,high)
 var inverse=actor.global_transform.affine_inverse()
 for entry in geometry:
  var mesh=entry[0]
  if not is_instance_valid(mesh) or not mesh.visible:continue
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
 camera.position=center+backward*distance
 camera.h_offset=-shift*distance/focal

func _process(_delta):
 if not is_instance_valid(actor) or not is_instance_valid(controls):return
 var expanded=measure()
 if expanded or last_size!=camera.get_viewport().get_visible_rect().size or last_rect!=controls.get_global_rect():reframe()
