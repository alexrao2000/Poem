extends RefCounted
# Closed, beveled steel silhouettes retain the existing weapon reach. Explicit
# flat normals make the central ridge and cutting edges catch different light;
# shared geometry also gives held and thrown spears the same leaf-shaped head.
static func triangle(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,outward: Vector3):
 var normal=(b-a).cross(c-a).normalized()
 if normal.dot(outward)<0:
  var swap=b;b=c;c=swap;normal=-normal
 for point in [a,c,b]:
  surface.set_normal(normal)
  surface.set_uv(Vector2(.5+point.x*2.0,-point.z))
  surface.add_vertex(point)

static func pointed(rings: Array,tip: float) -> ArrayMesh:
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var sections=[]
 for ring in rings:
  sections.append([Vector3(-ring.y,0,ring.x),Vector3(0,ring.z,ring.x),Vector3(ring.y,0,ring.x),Vector3(0,-ring.z,ring.x)])
 var base=sections[0]
 triangle(surface,base[0],base[1],base[2],Vector3.BACK)
 triangle(surface,base[0],base[2],base[3],Vector3.BACK)
 for i in range(sections.size()-1):
  for side in range(4):
   var a=sections[i][side];var b=sections[i][(side+1)%4]
   var c=sections[i+1][(side+1)%4];var d=sections[i+1][side]
   var outward=Vector3((a.x+b.x)*.5,(a.y+b.y)*.5,0)
   triangle(surface,a,b,c,outward);triangle(surface,a,c,d,outward)
 for side in range(4):
  var a=sections[-1][side];var b=sections[-1][(side+1)%4]
  triangle(surface,a,b,Vector3(0,0,tip),Vector3((a.x+b.x)*.5,(a.y+b.y)*.5,0))
 return surface.commit()

static func sword() -> ArrayMesh:
 return pointed([Vector3(-.235,.048,.018),Vector3(-.29,.065,.022),Vector3(-.91,.035,.014)],-1.075)

static func spear(base=-1.34,shoulder=-1.43,tip=-1.62,width=.075) -> ArrayMesh:
 return pointed([Vector3(base,width*.28,.014),Vector3(shoulder,width,.025)],tip)

static func axe() -> ArrayMesh:
 var outline=PackedVector2Array([Vector2(-.06,-.66),Vector2(-.18,-.62),Vector2(-.33,-.69),Vector2(-.39,-.84),Vector2(-.30,-.97),Vector2(-.13,-.93),Vector2(-.08,-.83),Vector2(.08,-.83),Vector2(.13,-.93),Vector2(.30,-.97),Vector2(.39,-.84),Vector2(.33,-.69),Vector2(.18,-.62),Vector2(.06,-.66)])
 return beveled(outline)

static func hammer() -> ArrayMesh:
 return beveled(PackedVector2Array([Vector2(-.24,-.63),Vector2(.24,-.63),Vector2(.28,-.67),Vector2(.28,-.93),Vector2(.24,-.97),Vector2(-.24,-.97),Vector2(-.28,-.93),Vector2(-.28,-.67)]),.10,.025)

static func hatchet() -> ArrayMesh:
 return beveled(PackedVector2Array([Vector2(.06,-.66),Vector2(-.12,-.66),Vector2(-.28,-.72),Vector2(-.33,-.86),Vector2(-.24,-.97),Vector2(-.09,-.91),Vector2(-.04,-.82),Vector2(.06,-.82)]))

static func beveled(outline: PackedVector2Array,thickness=.035,bevel=.018) -> ArrayMesh:
 var inset=PackedVector2Array();var winding=-1.0 if Geometry2D.is_polygon_clockwise(outline) else 1.0
 for i in range(outline.size()):
  var entering=(outline[i]-outline[(i-1+outline.size())%outline.size()]).normalized()
  var leaving=(outline[(i+1)%outline.size()]-outline[i]).normalized()
  var a=Vector2(-entering.y,entering.x)*winding;var b=Vector2(-leaving.y,leaving.x)*winding
  inset.append(outline[i]+(a+b)*(bevel/(1.0+a.dot(b))))
 var indices=Geometry2D.triangulate_polygon(inset)
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for sign_value in [-1,1]:
  for i in range(0,indices.size(),3):
   var a=inset[indices[i]];var b=inset[indices[i+1]];var c=inset[indices[i+2]]
   triangle(surface,Vector3(a.x,sign_value*thickness,a.y),Vector3(b.x,sign_value*thickness,b.y),Vector3(c.x,sign_value*thickness,c.y),Vector3.UP*sign_value)
  for i in range(outline.size()):
   var next=(i+1)%outline.size();var a=outline[i];var b=outline[next];var c=inset[next];var d=inset[i]
   triangle(surface,Vector3(a.x,0,a.y),Vector3(b.x,0,b.y),Vector3(c.x,sign_value*thickness,c.y),Vector3.UP*sign_value)
   triangle(surface,Vector3(a.x,0,a.y),Vector3(c.x,sign_value*thickness,c.y),Vector3(d.x,sign_value*thickness,d.y),Vector3.UP*sign_value)
 return surface.commit()
