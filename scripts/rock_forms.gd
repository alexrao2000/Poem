extends RefCounted
## Three original fractured stone silhouettes inside the existing unit radius.

const SIDES=9
static var cache={}

static func variant_at(point: Vector3) -> int:
 return posmod(roundi(point.x*17)+roundi(point.z*31),3)

static func triangle(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3):
 var normal=(b-a).cross(c-a).normalized();var axis=normal.abs().max_axis_index()
 for point in [a,c,b]:
  var uv=Vector2(point.z,point.y) if axis==0 else Vector2(point.x,point.z) if axis==1 else Vector2(point.x,point.y)
  surface.set_normal(normal);surface.set_uv(uv*.5+Vector2.ONE*.5);surface.add_vertex(point)

static func mesh(variant: int) -> ArrayMesh:
 variant=posmod(variant,3)
 if cache.has(variant):return cache[variant]
 var rings=[]
 for row in range(4):
  var ring=[];var radius=[.70,1.0,.80,.35][row];var height=[-.70,-.06,.55,.93][row]
  for i in range(SIDES):
   var angle=i*TAU/SIDES+variant*.43+row*.025
   var spread=radius*(.89+.10*sin(i*2.4+variant*1.3))
   var lateral=Vector2(cos(angle),sin(angle))*spread+Vector2(sin(row*1.2+variant)*.08,cos(row*.8+variant)*.05)
   if lateral.length()>1:lateral=lateral.normalized()
   var y=height+sin(i*1.7+variant+row)*(.035 if row in [0,3] else .07)
   ring.append(Vector3(lateral.x,y,lateral.y))
  rings.append(ring)
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in range(3):
  for i in range(SIDES):
   var next=(i+1)%SIDES
   var a=rings[row][i];var b=rings[row+1][i];var c=rings[row+1][next];var d=rings[row][next]
   triangle(surface,a,b,c);triangle(surface,a,c,d)
 for row in [0,3]:
  var center=Vector3.ZERO
  for point in rings[row]:center+=point/SIDES
  for i in range(SIDES):
   var a=rings[row][i];var b=rings[row][(i+1)%SIDES]
   if row==0:triangle(surface,center,a,b)
   else:triangle(surface,center,b,a)
 cache[variant]=surface.commit();return cache[variant]
