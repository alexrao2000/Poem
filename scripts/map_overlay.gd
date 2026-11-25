extends RefCounted
const MapSurface=preload("res://scripts/map_surface.gd")
# Unlit tactical marks follow raised walkable surfaces without hiding ground
# detail. Each layer keeps its own geometry and shares the vertex-color material.
# Routes ramp into raised tiles and fill the outside of each bend.
static var ink: StandardMaterial3D

static func quad(surface: SurfaceTool,points: Array,color: Color):
 for i in [0,1,2,0,2,3]:
  surface.set_normal(Vector3.UP);surface.set_color(color);surface.add_vertex(points[i])

static func rectangle(surface: SurfaceTool,center: Vector2,half: Vector2,height: float,color: Color):
 quad(surface,[Vector3(center.x-half.x,height,center.y-half.y),Vector3(center.x+half.x,height,center.y-half.y),Vector3(center.x+half.x,height,center.y+half.y),Vector3(center.x-half.x,height,center.y+half.y)],color)

static func finish(parent: Node3D,surface: SurfaceTool,label: String) -> MeshInstance3D:
 if ink==null:
  ink=StandardMaterial3D.new()
  ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  ink.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
  ink.vertex_color_use_as_albedo=true
  ink.vertex_color_is_srgb=true
  ink.cull_mode=BaseMaterial3D.CULL_DISABLED
 var node=MeshInstance3D.new();node.name=label;node.mesh=surface.commit()
 node.material_override=ink
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 parent.add_child(node);return node

static func tiles(parent: Node3D,points: Array,color: Color,height: float,label: String,elevation: Callable=Callable()) -> MeshInstance3D:
 if points.is_empty():return null
 var occupied={}
 for point in points:occupied[point]=true
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for point in occupied:
  var level=height+(float(elevation.call(point)) if elevation.is_valid() else 0.0)
  rectangle(surface,Vector2(point),Vector2.ONE*.425,level,color)
  for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   var edge=color.lightened(.35);edge.a=.26 if occupied.has(point+step) else .85
   var half=Vector2(.018,.455) if step.x!=0 else Vector2(.455,.018)
   rectangle(surface,Vector2(point)+Vector2(step)*.445,half,level+.001,edge)
 return finish(parent,surface,label)

static func site_badges(parent: Node3D,events: Dictionary,elevation: Callable) -> MeshInstance3D:
 if events.is_empty():return null
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for tile in events:
  var center=Vector2(tile)+Vector2(-.27,-.27)
  var height=float(elevation.call(tile))+.074
  var effect=events[tile]
  var badge_color=Color("3d8269") if effect=="tonic" else Color("3e6d88") if effect=="recruit" else Color("a9814d")
  rectangle(surface,center,Vector2.ONE*.16,height,Color("233a3b"))
  rectangle(surface,center,Vector2.ONE*.132,height+.002,badge_color)
  var face=Color("fff2cf")
  if effect=="tonic":
   rectangle(surface,center,Vector2(.083,.023),height+.004,face)
   rectangle(surface,center,Vector2(.023,.083),height+.004,face)
  elif effect=="recruit":
   rectangle(surface,center+Vector2.UP*.024,Vector2.ONE*.033,height+.004,face)
   rectangle(surface,center+Vector2.DOWN*.022,Vector2(.072,.028),height+.004,face)
  else:
   rectangle(surface,center+Vector2.UP*.035,Vector2(.075,.019),height+.004,face)
   rectangle(surface,center+Vector2.DOWN*.035,Vector2(.05,.019),height+.004,face)
 return finish(parent,surface,"SiteBadges")

static func ribbon(surface: SurfaceTool,a: Vector3,b: Vector3,width: float,height: float,color: Color):
 var offset=Vector2(b.x-a.x,b.z-a.z).orthogonal().normalized()*width
 var side=Vector3(offset.x,0,offset.y);var lift=Vector3.UP*height
 quad(surface,[a-side+lift,b-side+lift,b+side+lift,a+side+lift],color)

static func arrow(surface: SurfaceTool,point: Vector2,direction: Vector2,width: float,height: float,color: Color):
 var side=direction.orthogonal()*width
 for p in [point+direction*.29,point-direction*.17+side,point-direction*.17-side]:
  surface.set_normal(Vector3.UP);surface.set_color(color);surface.add_vertex(Vector3(p.x,height,p.y))

static func bend(surface: SurfaceTool,point: Vector2,incoming: Vector2,outgoing: Vector2,width: float,height: float,color: Color):
 var start=-outgoing*width
 var end=incoming*width
 var middle=(start+end).normalized()*width
 for offset in [Vector2.ZERO,start,middle,Vector2.ZERO,middle,end]:
  var corner=point+offset
  surface.set_normal(Vector3.UP);surface.set_color(color);surface.add_vertex(Vector3(corner.x,height,corner.y))

static func route(parent: Node3D,path: Array,elevation: Callable=Callable()) -> MeshInstance3D:
 if path.size()<2:return null
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var dark=Color("69543a");var gold=Color("ffe29a")
 for i in range(1,path.size()):
  var a=Vector3(path[i-1].x,float(elevation.call(path[i-1])) if elevation.is_valid() else 0.0,path[i-1].y)
  var b=Vector3(path[i].x,float(elevation.call(path[i])) if elevation.is_valid() else 0.0,path[i].y)
  var middle=MapSurface.crossing(a,b)
  for ends in [[a,middle],[middle,b]]:
   ribbon(surface,ends[0],ends[1],.08,.057,dark)
   ribbon(surface,ends[0],ends[1],.045,.060,gold)
  if i>1:
   var incoming=Vector2(path[i-1]-path[i-2])
   var outgoing=Vector2(path[i]-path[i-1])
   if incoming.dot(outgoing)==0.0:
    bend(surface,Vector2(path[i-1]),incoming,outgoing,.08,a.y+.057,dark)
    bend(surface,Vector2(path[i-1]),incoming,outgoing,.045,a.y+.060,gold)
 var last=Vector2(path[-1]);var direction=(last-Vector2(path[-2])).normalized()
 var level=float(elevation.call(path[-1])) if elevation.is_valid() else 0.0
 arrow(surface,last,direction,.22,level+.062,dark);arrow(surface,last,direction,.17,level+.065,gold)
 return finish(parent,surface,"MovementRoute")
