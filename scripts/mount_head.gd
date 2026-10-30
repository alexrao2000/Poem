extends RefCounted
# A continuous tapered skull and broad muzzle replace overlapping head ovals.
# Both closed regions share the seam; bridles and eyes keep their attachments.

const SIDES=16
const PROFILE=[
 [.22,.025,.055,.075],
 [.14,.025,.128,.155],
 [.02,.005,.155,.195],
 [-.11,-.005,.150,.165],
 [-.22,-.055,.125,.120],
 [-.28,-.070,.115,.100],
 [-.35,-.075,.080,.065]
]
static var shapes={}

static func point(row: int,side: int) -> Vector3:
 var ring=PROFILE[row];var angle=float(side%SIDES)*TAU/SIDES
 return Vector3(cos(angle)*ring[2],ring[1]+sin(angle)*ring[3],ring[0])

static func triangle(surface: SurfaceTool,points: Array):
 for vertex in points:
  surface.set_uv(Vector2(vertex.x/.32+.5,(.23-vertex.z)/.60));surface.add_vertex(vertex)

static func mesh(muzzle=false) -> ArrayMesh:
 if shapes.has(muzzle):return shapes[muzzle]
 var start=4 if muzzle else 0;var end=6 if muzzle else 4
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for side in range(SIDES):
  triangle(surface,[Vector3(0,PROFILE[start][1],PROFILE[start][0]),point(start,side+1),point(start,side)])
  for row in range(start,end):
   var a=point(row,side);var b=point(row,side+1);var c=point(row+1,side+1);var d=point(row+1,side)
   triangle(surface,[a,b,c]);triangle(surface,[a,c,d])
  triangle(surface,[Vector3(0,PROFILE[end][1],PROFILE[end][0]),point(end,side),point(end,side+1)])
 surface.generate_normals();surface.generate_tangents();surface.index();shapes[muzzle]=surface.commit();return shapes[muzzle]

static func surface_point(z: float,angle: float) -> Vector3:
 var row=0
 while row<PROFILE.size()-2 and z<PROFILE[row+1][0]:row+=1
 var vertical=clampf((PROFILE[row][0]-z)/(PROFILE[row][0]-PROFILE[row+1][0]),0,1)
 var side=fposmod(angle,TAU)*SIDES/TAU;var index=floori(side);var share=side-index
 return point(row,index).lerp(point(row,index+1),share).lerp(point(row+1,index).lerp(point(row+1,index+1),share),vertical)

static func raised(z: float,angle: float,height: float) -> Vector3:
 return surface_point(z,angle)+Vector3(cos(angle),sin(angle),0)*height

static func quad(surface: SurfaceTool,points: Array,outward: Vector3):
 if (points[2]-points[0]).cross(points[1]-points[0]).dot(outward)<0:points.reverse()
 triangle(surface,[points[0],points[1],points[2]]);triangle(surface,[points[0],points[2],points[3]])

static func strip(surface: SurfaceTool,edges: Array,looped=false):
 for index in range(edges.size() if looped else edges.size()-1):
  var a=edges[index];var b=edges[(index+1)%edges.size()]
  var up=(a[2]+a[3]+b[2]+b[3]-a[0]-a[1]-b[0]-b[1])*.25
  var across=(a[1]+a[3]+b[1]+b[3]-a[0]-a[2]-b[0]-b[2])*.25
  quad(surface,[a[2],a[3],b[3],b[2]],up)
  quad(surface,[a[0],a[1],b[1],b[0]],-up)
  quad(surface,[a[0],a[2],b[2],b[0]],-across)
  quad(surface,[a[1],a[3],b[3],b[1]],across)
 if not looped:
  var a=edges[0];var b=edges[-1];var direction=b[0]-a[0]
  quad(surface,[a[0],a[1],a[3],a[2]],-direction)
  quad(surface,[b[0],b[1],b[3],b[2]],direction)

static func bridle() -> ArrayMesh:
 if shapes.has("bridle"):return shapes.bridle
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var edges=[]
 for side in range(SIDES):
  var angle=float(side)*TAU/SIDES
  edges.append([raised(-.3025,angle,.002),raised(-.2575,angle,.002),raised(-.3025,angle,.007),raised(-.2575,angle,.007)])
 strip(surface,edges,true)
 for angle in [0.0,PI]:
  edges=[]
  for row in range(1,5):
   var z=PROFILE[row][0]
   edges.append([raised(z,angle-.11,.002),raised(z,angle+.11,.002),raised(z,angle-.11,.007),raised(z,angle+.11,.007)])
  strip(surface,edges)
 surface.generate_normals();surface.generate_tangents();surface.index();shapes.bridle=surface.commit();return shapes.bridle
