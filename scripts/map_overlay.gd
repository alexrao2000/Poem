extends RefCounted
# Flat unlit tactical marks preserve ground detail. One mesh per range layer
# shares crisp tile seams and a stronger outer boundary; routes end in arrows.
static func quad(surface: SurfaceTool,points: Array,color: Color):
 for i in [0,1,2,0,2,3]:
  surface.set_normal(Vector3.UP);surface.set_color(color);surface.add_vertex(points[i])

static func rectangle(surface: SurfaceTool,center: Vector2,half: Vector2,height: float,color: Color):
 quad(surface,[Vector3(center.x-half.x,height,center.y-half.y),Vector3(center.x+half.x,height,center.y-half.y),Vector3(center.x+half.x,height,center.y+half.y),Vector3(center.x-half.x,height,center.y+half.y)],color)

static func finish(parent: Node3D,surface: SurfaceTool,label: String) -> MeshInstance3D:
 var node=MeshInstance3D.new();node.name=label;node.mesh=surface.commit()
 var material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.vertex_color_use_as_albedo=true;material.vertex_color_is_srgb=true
 material.cull_mode=BaseMaterial3D.CULL_DISABLED;node.material_override=material
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 parent.add_child(node);return node

static func tiles(parent: Node3D,points: Array,color: Color,height: float,label: String) -> MeshInstance3D:
 if points.is_empty():return null
 var occupied={}
 for point in points:occupied[point]=true
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for point in occupied:
  rectangle(surface,Vector2(point),Vector2.ONE*.425,height,color)
  for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   var edge=color.lightened(.35);edge.a=.26 if occupied.has(point+step) else .85
   var half=Vector2(.018,.455) if step.x!=0 else Vector2(.455,.018)
   rectangle(surface,Vector2(point)+Vector2(step)*.445,half,height+.001,edge)
 return finish(parent,surface,label)

static func ribbon(surface: SurfaceTool,a: Vector2,b: Vector2,width: float,height: float,color: Color):
 var side=(b-a).orthogonal().normalized()*width
 quad(surface,[Vector3(a.x-side.x,height,a.y-side.y),Vector3(b.x-side.x,height,b.y-side.y),Vector3(b.x+side.x,height,b.y+side.y),Vector3(a.x+side.x,height,a.y+side.y)],color)

static func arrow(surface: SurfaceTool,point: Vector2,direction: Vector2,width: float,height: float,color: Color):
 var side=direction.orthogonal()*width
 for p in [point+direction*.29,point-direction*.17+side,point-direction*.17-side]:
  surface.set_normal(Vector3.UP);surface.set_color(color);surface.add_vertex(Vector3(p.x,height,p.y))

static func route(parent: Node3D,path: Array) -> MeshInstance3D:
 if path.size()<2:return null
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var dark=Color("69543a");var gold=Color("ffe29a")
 for i in range(1,path.size()):
  ribbon(surface,Vector2(path[i-1]),Vector2(path[i]),.08,.057,dark)
  ribbon(surface,Vector2(path[i-1]),Vector2(path[i]),.045,.060,gold)
 var last=Vector2(path[-1]);var direction=(last-Vector2(path[-2])).normalized()
 arrow(surface,last,direction,.22,.062,dark);arrow(surface,last,direction,.17,.065,gold)
 return finish(parent,surface,"MovementRoute")
