extends RefCounted
# Shared original spell colors and simple airborne shapes keep folio identity
# consistent from launch to contact without adding simulation dependencies.
static func palette(id: String) -> Dictionary:
 match id:
  "ember":return {"core":Color("fff0b5"),"accent":Color("ffae4d"),"wake":Color("d86737")}
  "gale":return {"core":Color("e3fff1"),"accent":Color("8fe0c4"),"wake":Color("559ca9")}
  "thunder":return {"core":Color("f4eaff"),"accent":Color("c8a2ff"),"wake":Color("8577ca")}
 return {"core":Color("b7f2ed"),"accent":Color("6fbfdf"),"wake":Color("66b4d3")}

static func crescent() -> ArrayMesh:
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(18):
  var a=i/18.0*PI*1.55;var b=(i+1)/18.0*PI*1.55
  var inner_a=.22-.055*sin(i/18.0*PI);var inner_b=.22-.055*sin((i+1)/18.0*PI)
  var points=[Vector3(cos(a)*.22,sin(a)*.22,0),Vector3(cos(b)*.22,sin(b)*.22,0),Vector3(cos(b)*inner_b,sin(b)*inner_b,0),Vector3(cos(a)*inner_a,sin(a)*inner_a,0)]
  for index in [0,1,2,0,2,3]:surface.add_vertex(points[index])
 return surface.commit()

static func bolt() -> ArrayMesh:
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var path=[Vector3(0,0,.42),Vector3(.09,0,.22),Vector3(-.08,0,.08),Vector3(.06,0,-.12),Vector3(-.07,0,-.25),Vector3(0,0,-.45)]
 for i in range(path.size()-1):
  var a=path[i];var b=path[i+1];var width=Vector3.UP*.024
  for point in [a-width,a+width,b+width,a-width,b+width,b-width]:surface.add_vertex(point)
 return surface.commit()
