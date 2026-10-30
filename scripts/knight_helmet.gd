extends RefCounted
# Original faceted helmet with a hollow eye slit, recessed lining and fitted
# nasal trim. Three cached meshes retain the former attachment/material count.

const SIDES=16
const RINGS=[[-.185,.095,.105,.015],[-.115,.139,.155,.008],[-.018,.166,.190,0],[.030,.166,.180,.005],[.070,.161,.159,.012],[.155,.143,.140,.020],[.215,.080,.085,.025],[.235,.018,.040,.025]]
static var metal: ArrayMesh
static var lining: ArrayMesh
static var trim: ArrayMesh

static func point(row: int,column: int,inside=false) -> Vector3:
 var ring=RINGS[row];var angle=posmod(column,SIDES)*TAU/SIDES;var inset=.008 if inside else 0.0
 var height=ring[0]+(.008 if inside and row==0 else -.008 if inside and row==RINGS.size()-1 else 0.0)
 return Vector3(cos(angle)*(ring[1]-inset),height,sin(angle)*(ring[2]-inset)+ring[3])

static func mesh() -> ArrayMesh:
 if metal!=null:return metal
 var points=[];var inner=[];var faces=[]
 for row in range(RINGS.size()):
  for column in range(SIDES):points.append(point(row,column));inner.append(point(row,column,true))
 for row in range(RINGS.size()-1):
  for column in range(SIDES):
   if row==2 and column in [10,11,12,13]:continue
   var a=row*SIDES+column;var b=row*SIDES+(column+1)%SIDES;var c=(row+1)*SIDES+(column+1)%SIDES;var d=(row+1)*SIDES+column
   faces.append([a,b,c]);faces.append([a,c,d])
 for top in [false,true]:
  var row=RINGS.size()-1 if top else 0;var center=points.size()
  points.append(Vector3(0,.242 if top else -.189,.025 if top else .015));inner.append(Vector3(0,.234 if top else -.181,.025 if top else .015))
  for column in range(SIDES):
   var a=row*SIDES+column;var b=row*SIDES+(column+1)%SIDES
   faces.append([center,a,b] if top else [center,b,a])
 metal=closed_surface(points,inner,faces);return metal

static func closed_surface(points: Array,inner: Array,faces: Array) -> ArrayMesh:
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);var edges={}
 for face in faces:
  triangle(surface,points[face[0]],points[face[1]],points[face[2]])
  triangle(surface,inner[face[2]],inner[face[1]],inner[face[0]])
  for i in range(3):
   var a=face[i];var b=face[(i+1)%3];var key=Vector2i(mini(a,b),maxi(a,b))
   if not edges.has(key):edges[key]={"a":a,"b":b,"count":0}
   edges[key].count+=1
 for edge in edges.values():
  if edge.count!=1:continue
  var a=edge.a;var b=edge.b
  triangle(surface,points[b],points[a],inner[a]);triangle(surface,points[b],inner[a],inner[b])
 return surface.commit()

static func visor_lining() -> ArrayMesh:
 if lining!=null:return lining
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for column in range(10,14):
  var a=point(2,column,true);var b=point(2,column+1,true);var c=point(3,column+1,true);var d=point(3,column,true)
  a.z+=.002;b.z+=.002;c.z+=.002;d.z+=.002
  triangle(surface,a,b,c);triangle(surface,a,c,d)
 lining=surface.commit();return lining

static func front(y: float,x: float) -> Vector3:
 var row=0
 while row<RINGS.size()-2 and y>RINGS[row+1][0]:row+=1
 var weight=clampf((y-RINGS[row][0])/(RINGS[row+1][0]-RINGS[row][0]),0,1)
 var center=point(row,12).lerp(point(row+1,12),weight)
 var edge=point(row,13).lerp(point(row+1,13),weight)
 return Vector3(x,y,lerpf(center.z,edge.z,absf(x)/edge.x))

static func nasal_trim() -> ArrayMesh:
 if trim!=null:return trim
 var profile=[[.155,.016],[.070,.018],[.030,.015],[-.018,.018],[-.115,.024],[-.160,.009]]
 var points=[];var inner=[];var faces=[]
 for row in profile:
  for side in [-1,0,1]:
   var p=front(row[0],side*row[1])-Vector3.BACK*.004
   points.append(p);inner.append(p+Vector3.BACK*.003)
 for row in range(profile.size()-1):
  for half in range(2):
   var a=row*3+half;var b=a+1;var c=a+4;var d=a+3
   faces.append([a,c,b]);faces.append([a,d,c])
 trim=closed_surface(points,inner,faces);return trim

static func triangle(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3):
 var normal=(c-a).cross(b-a).normalized()
 for p in [a,b,c]:
  surface.set_normal(normal);surface.set_uv(Vector2(atan2(p.z,p.x)/TAU+.5,(p.y+.2)/.45));surface.add_vertex(p)
