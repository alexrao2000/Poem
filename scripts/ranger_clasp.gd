extends RefCounted
# Sera's brass pin and the pale feather folded against her cloak.
const BRASS=Color("b58b47")
const EDGE=Color("e5c982")
const ENAMEL=Color("37454c")
const SHAFT=Color("dbca9f")
const VANES=[Color("e5d5b4"),Color("f2e5cc")]
const WIDTHS=[.004,.012,.020,.023,.018,.013,.006,0.0]
static var clasp: ArrayMesh

static func add(painter,parent: Node3D,placement: Transform3D) -> MeshInstance3D:
 var material=painter.geo.material(Color.WHITE).duplicate()
 material.vertex_color_use_as_albedo=true;material.vertex_color_is_srgb=true
 material.cull_mode=BaseMaterial3D.CULL_DISABLED
 material.set_meta("no_character_outline",true)
 var mesh=painter.geo.mesh(parent,geometry(),Vector3.ZERO,Vector3.ONE,material)
 mesh.name="FeatherClasp";mesh.transform=placement
 return mesh

static func geometry() -> ArrayMesh:
 if clasp!=null:return clasp
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var halo=[];var inset=[]
 for index in 12:
  var angle=index*TAU/12+PI*.5
  var ray=Vector3(cos(angle),sin(angle),0)
  halo.append(ray*(.028 if index%2==0 else .020))
  inset.append(ray*.013+Vector3.BACK*.006)
 for index in 12:
  var after=(index+1)%12
  triangle(surface,[halo[index],halo[after],inset[after]],BRASS if index%3==0 else EDGE)
  triangle(surface,[halo[index],inset[after],inset[index]],BRASS)
  triangle(surface,[inset[index],inset[after],Vector3.BACK*.010],ENAMEL)
 for index in range(WIDTHS.size()-1):
  var first=feather_spine(index);var second=feather_spine(index+1)
  for side in [-1,1]:
   var outside=first+Vector3(side*WIDTHS[index],-.006,-.005)
   var tip=second+Vector3(side*WIDTHS[index+1],-.006,-.005)
   triangle(surface,[first,outside,second],VANES[(index+1)%2] if side<0 else VANES[index%2])
   if WIDTHS[index+1]>0:triangle(surface,[outside,tip,second],VANES[index%2])
  var quill=Vector3.RIGHT*lerpf(.0025,.0007,float(index)/WIDTHS.size())
  var crest=Vector3.BACK*.001
  triangle(surface,[first-quill+crest,first+quill+crest,second+crest],SHAFT)
 clasp=surface.commit()
 return clasp

static func feather_spine(index: int) -> Vector3:
 var t=float(index)/(WIDTHS.size()-1)
 return Vector3(-.014*t*t,-.018-.134*t,.006+.010*sin(t*PI)-.048*t)

static func triangle(surface: SurfaceTool,points: Array,color: Color):
 var normal: Vector3=(points[1]-points[0]).cross(points[2]-points[0]).normalized()
 var order=[0,2,1] if normal.z>0 else [0,1,2]
 surface.set_normal(normal if normal.z>0 else -normal)
 surface.set_color(color)
 for index in order:surface.add_vertex(points[index])
