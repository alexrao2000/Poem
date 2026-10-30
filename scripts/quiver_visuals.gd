extends RefCounted
## An open leather quiver with four aligned, staggered, feathered arrow tails.
const SEGMENTS=16
const TAILS=[Vector3(-.027,.46,-.027),Vector3(.027,.485,-.027),Vector3(-.027,.48,.027),Vector3(.027,.455,.027)]
static var cached={}

static func triangle(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3):
 var normal=(b-a).cross(c-a).normalized()
 for point in [a,c,b]:
  surface.set_normal(normal);surface.set_uv(Vector2(point.x*4+.5,point.y*2+.5));surface.add_vertex(point)

static func quad(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3):
 triangle(surface,a,b,c);triangle(surface,a,c,d)

static func ring_point(index: int,radius: float,y: float) -> Vector3:
 var angle=index*TAU/SEGMENTS
 return Vector3(cos(angle)*radius,y,sin(angle)*radius)

static func mesh(part: String) -> ArrayMesh:
 if cached.has(part):return cached[part]
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 if part=="body":
  for i in range(SEGMENTS):
   var a=ring_point(i,.075,.24);var b=ring_point(i+1,.075,.24)
   var c=ring_point(i+1,.060,-.24);var d=ring_point(i,.060,-.24)
   var ia=ring_point(i,.060,.24);var ib=ring_point(i+1,.060,.24)
   var ic=ring_point(i+1,.045,-.20);var id=ring_point(i,.045,-.20)
   quad(surface,a,b,c,d);quad(surface,ia,id,ic,ib);quad(surface,a,ia,ib,b)
   triangle(surface,Vector3(0,-.24,0),d,c);triangle(surface,Vector3(0,-.20,0),ic,id)
 elif part=="rim":
  for i in range(SEGMENTS):
   quad(surface,ring_point(i,.077,.235),ring_point(i+1,.077,.235),ring_point(i+1,.075,.205),ring_point(i,.075,.205))
 elif part=="shafts":
  var shaft=CylinderMesh.new();shaft.height=.40;shaft.top_radius=.006;shaft.bottom_radius=.006;shaft.radial_segments=8
  for tail in TAILS:surface.append_from(shaft,0,Transform3D(Basis.IDENTITY,tail-Vector3.UP*.20))
 elif part=="feathers":
  for i in range(TAILS.size()):
   for j in range(3):
    var direction=Vector3(cos(j*TAU/3+i*.35),0,sin(j*TAU/3+i*.35))
    var tail=TAILS[i]-Vector3.UP*.018
    quad(surface,tail,tail-Vector3.UP*.085,tail-Vector3.UP*.065+direction*.026,tail-Vector3.UP*.008+direction*.022)
 cached[part]=surface.commit();return cached[part]

static func build(painter,parent,leather,gold):
 var quiver=painter.joint(parent,"Quiver",Vector3(.16,.14,.19));quiver.rotation.z=-.22
 for part in ["body","rim","shafts","feathers"]:
  var color={"body":leather,"rim":gold,"shafts":Color("9c8769"),"feathers":Color("d3d7c9")}[part]
  var material=painter.geo.material(color)
  if part=="feathers":material=material.duplicate();material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.set_meta("outline_width",.001)
  var piece=painter.geo.mesh(quiver,mesh(part),Vector3.ZERO,Vector3.ONE,material);piece.name="Quiver"+part.capitalize()
