extends RefCounted
# Original ring profiles give the mount a lifted belly, defined withers and
# sloping neck while retaining saddle, leg, head and rein attachment positions.

const SIDES=16
const TORSO=[[-.68,.07,-.08,.16],[-.56,.22,-.24,.28],[-.42,.30,-.34,.37],[-.20,.34,-.39,.37],[.10,.33,-.34,.33],[.36,.31,-.27,.36],[.55,.24,-.20,.30],[.68,.065,-.06,.13]]
const NECK=[[.05,-.43,.20,.26],[.20,-.47,.205,.24],[.40,-.57,.17,.205],[.60,-.61,.125,.205],[.76,-.59,.095,.16]]
static var shapes={}

static func center(row: int,neck: bool) -> Vector3:
 var ring=NECK[row] if neck else TORSO[row]
 return Vector3(0,ring[0],ring[1]) if neck else Vector3(0,(ring[2]+ring[3])*.5,ring[0])

static func point(row: int,side: int,neck: bool) -> Vector3:
 var angle=(side%SIDES)*TAU/SIDES;var ring=NECK[row] if neck else TORSO[row]
 return center(row,neck)+(Vector3(cos(angle)*ring[2],0,sin(angle)*ring[3]) if neck else Vector3(cos(angle)*ring[1],sin(angle)*(ring[3]-ring[2])*.5,0))

static func neck_back(y: float) -> float:
 var row=0
 while row<NECK.size()-2 and y>NECK[row+1][0]:row+=1
 var share=clampf((y-NECK[row][0])/(NECK[row+1][0]-NECK[row][0]),0,1)
 return lerpf(NECK[row][1]+NECK[row][3],NECK[row+1][1]+NECK[row+1][3],share)

static func triangle(surface: SurfaceTool,points: Array,normal: Vector3,neck: bool):
 if (points[2]-points[0]).cross(points[1]-points[0]).dot(normal)<0:points.reverse()
 for vertex in points:
  surface.set_uv(Vector2(vertex.x+.5,vertex.y if neck else vertex.z));surface.add_vertex(vertex)

static func mesh(neck=false) -> ArrayMesh:
 if shapes.has(neck):return shapes[neck]
 var count=NECK.size() if neck else TORSO.size();var axis=Vector3.UP if neck else Vector3.BACK
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for side in range(SIDES):
  triangle(surface,[center(0,neck),point(0,side,neck),point(0,side+1,neck)],-axis,neck)
  for row in range(count-1):
   var a=point(row,side,neck);var b=point(row,side+1,neck);var c=point(row+1,side+1,neck);var d=point(row+1,side,neck)
   var normal=(a+b+c+d)*.25-(center(row,neck)+center(row+1,neck))*.5
   triangle(surface,[a,b,c],normal,neck);triangle(surface,[a,c,d],normal,neck)
  triangle(surface,[center(count-1,neck),point(count-1,side,neck),point(count-1,side+1,neck)],axis,neck)
 surface.generate_normals();surface.generate_tangents();surface.index();shapes[neck]=surface.commit();return shapes[neck]
