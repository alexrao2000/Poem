extends Node3D
## Brief painted weapon strokes in world space. Presentation only.
var material: StandardMaterial3D

func start(point: Vector3,weapon: String,direction: float,critical=false):
 position=point
 var vertices=PackedVector3Array()
 if weapon=="lance":
  for vertex in [Vector3(-.85,-.025,0),Vector3(.6,0,0),Vector3(-.6,.10,0)]:vertices.append(Vector3(vertex.x*direction,vertex.y,vertex.z))
 else:
  var radius=.80 if weapon=="axe" else .65
  for i in range(14):
   var t0=i/14.0;var t1=(i+1)/14.0
   var points=[]
   for sample in [[t0,0],[t0,1],[t1,1],[t1,0]]:
    var t=float(sample[0]);var angle=lerpf(-2.3,.8,t)
    var width=sin(t*PI)*(.16 if critical else .10)
    var r=radius-width*float(sample[1])
    points.append(Vector3(cos(angle)*r*direction,sin(angle)*r,.015))
   for index in [0,1,2,0,2,3]:vertices.append(points[index])
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for vertex in vertices:surface.add_vertex(vertex)
 surface.generate_normals()
 stroke=MeshInstance3D.new();stroke.name="Stroke";stroke.mesh=surface.commit();stroke.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 material.albedo_color=Color("ffe4a3") if critical or weapon=="axe" else Color("e3f2ff")
 stroke.material_override=material;add_child(stroke)
 scale=Vector3.ONE*(1.15 if critical else 1.0)
 fade=create_tween();fade.tween_interval(.035);fade.tween_property(material,"albedo_color:a",0.0,.18);fade.tween_callback(queue_free)

var followed: WeakRef
var sampling=false
var samples=[]
var stroke: MeshInstance3D
var fade: Tween

func follow(actor: Node3D,weapon: String,critical=false) -> bool:
 if not actor.has_method("weapon_trail_points"):return false
 var edge=actor.weapon_trail_points()
 if edge.size()!=2 or edge[0].distance_squared_to(edge[1])<.0000000001:return false
 name="CombatTrail";followed=weakref(actor);sampling=true
 stroke=MeshInstance3D.new();stroke.name="Stroke";stroke.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 material.vertex_color_use_as_albedo=true;material.disable_fog=true
 material.albedo_color=Color("ffe4a3") if critical or weapon=="axe" else Color("e3f2ff")
 stroke.material_override=material;stroke.hide();add_child(stroke);sample();return true

func sample():
 if not sampling:return
 var actor=followed.get_ref()
 if actor==null:finish();return
 var points=actor.weapon_trail_points()
 if points.size()!=2:finish();return
 var edge=PackedVector3Array([to_local(points[0]),to_local(points[1])])
 if not samples.is_empty() and edge[0].distance_squared_to(samples[-1][0])+edge[1].distance_squared_to(samples[-1][1])<.00000001:return
 samples.append(edge)
 if samples.size()>12:samples.pop_front()
 if samples.size()<2:return
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);var count=0
 for i in range(1,samples.size()):
  var points4=[samples[i-1][0],samples[i-1][1],samples[i][1],samples[i][0]]
  var strength=float(i)/float(samples.size()-1)
  var colors=[Color(1,1,1,0),Color(1,1,1,strength*.8),Color(1,1,1,strength),Color(1,1,1,0)]
  for corners in [[0,1,2],[0,2,3]]:
   var a=points4[corners[0]];var b=points4[corners[1]];var c=points4[corners[2]]
   var normal=(c-a).cross(b-a)
   if normal.length_squared()<.000000000001:continue
   for index in corners:surface.set_normal(normal.normalized());surface.set_color(colors[index]);surface.add_vertex(points4[index])
   count+=1
 if count>0:stroke.mesh=surface.commit();stroke.show()

func finish():
 if not sampling:return
 # Sample once more in the caller after the strike tween reaches its endpoint.
 sampling=false;set_process(false)
 fade=create_tween();fade.tween_interval(.035);fade.tween_property(material,"albedo_color:a",0.0,.18);fade.tween_callback(queue_free)

func _process(_dt):
 if sampling and is_visible_in_tree():sample()
