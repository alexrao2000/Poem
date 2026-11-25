extends RefCounted
# Ivo's violet stole, cut to follow the chest in each outfit.
const IMPORTED=[
 Vector4(.049,-.006,.078,.019),Vector4(.073,-.054,.122,.026),
 Vector4(.100,-.113,.128,.034),Vector4(.108,-.172,.129,.039),
 Vector4(.102,-.237,.136,.041),Vector4(.093,-.333,.144,.036)]
const ORIGINAL=[
 Vector4(.052,-.006,.091,.019),Vector4(.076,-.055,.117,.027),
 Vector4(.105,-.115,.133,.035),Vector4(.111,-.175,.139,.038),
 Vector4(.105,-.239,.149,.040),Vector4(.097,-.336,.154,.036)]
const SEAMS=[-1.0,-.87,-.72,-.35,.35,.72,.87,1.0]
const GOLD=Color("d8bd81")
const THREAD=Color("dfc993")
static var cuts={}

static func add(painter,parent: Node3D,placement: Transform3D,cloth: Color,imported: bool) -> MeshInstance3D:
 var material=painter.geo.material(Color.WHITE).duplicate()
 material.vertex_color_use_as_albedo=true;material.vertex_color_is_srgb=true
 material.cull_mode=BaseMaterial3D.CULL_DISABLED
 material.set_meta("no_character_outline",true)
 var mesh=painter.geo.mesh(parent,geometry(cloth,imported),Vector3.ZERO,Vector3.ONE,material)
 mesh.name="WardenStole";mesh.transform=placement
 return mesh

static func geometry(cloth: Color,imported: bool) -> ArrayMesh:
 var key=[cloth,imported]
 if cuts.has(key):return cuts[key]
 var rows=IMPORTED if imported else ORIGINAL
 var colors=[cloth.darkened(.17),GOLD,cloth,cloth.lightened(.06),cloth, GOLD,cloth.darkened(.17)]
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for side in [-1,1]:
  for row in range(rows.size()-1):
   for column in range(SEAMS.size()-1):
    var left=SEAMS[column];var right=SEAMS[column+1]
    var a=point(rows,row,left,side);var b=point(rows,row,right,side)
    var c=point(rows,row+1,right,side);var d=point(rows,row+1,left,side)
    triangle(surface,a,b,c,colors[column]);triangle(surface,a,c,d,colors[column])
  for row in range(1,8):
   var root=row*.55
   var start=point(rows,root-.28,0,side,.003)
   var end=point(rows,root+.32,0,side,.003)
   for branch in [-1,1]:
    var tip=point(rows,root-.11,branch*.45,side,.003)
    var base=point(rows,root+.08,branch*.13,side,.003)
    triangle(surface,start,tip,base,THREAD)
    triangle(surface,base,tip,end,GOLD)
  var left=point(rows,4.83,-.72,side,.002)
  var right=point(rows,4.83,.72,side,.002)
  var lower_left=point(rows,5,-.72,side,.002)
  var lower_right=point(rows,5,.72,side,.002)
  triangle(surface,left,right,lower_right,GOLD);triangle(surface,left,lower_right,lower_left,GOLD)
 cuts[key]=surface.commit()
 return cuts[key]

static func point(rows: Array,along: float,across: float,side: int,lift=0.0) -> Vector3:
 var index=mini(int(along),rows.size()-2)
 var profile: Vector4=rows[index].lerp(rows[index+1],along-index)
 var face=profile.z-across*.021+(1-across*across)*.005
 return Vector3(side*(profile.x+across*profile.w),profile.y,face+lift)

static func triangle(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,color: Color):
 var normal=(b-a).cross(c-a).normalized()
 var front=normal.z>0
 surface.set_normal(normal if front else -normal);surface.set_color(color)
 for vertex in [a,c,b] if front else [a,b,c]:surface.add_vertex(vertex)
