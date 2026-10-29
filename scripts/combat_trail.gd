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
 var stroke=MeshInstance3D.new();stroke.name="Stroke";stroke.mesh=surface.commit();stroke.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 material.albedo_color=Color("ffe4a3") if critical or weapon=="axe" else Color("e3f2ff")
 stroke.material_override=material;add_child(stroke)
 scale=Vector3.ONE*(1.15 if critical else 1.0)
 var fade=create_tween();fade.tween_interval(.035);fade.tween_property(material,"albedo_color:a",0.0,.18);fade.tween_callback(queue_free)
