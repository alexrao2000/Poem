extends RefCounted
# Fitted roof geometry shares the house's existing gable equation. Tile courses
# add shallow lips and staggered joints; one cached mesh/material per palette
# keeps repeated buildings inexpensive to instantiate and batch.
const RIDGE=1.78
const SLOPE=.625
const HALF_WIDTH=.98
const HALF_DEPTH=.8
const THICKNESS=.08
const PALETTES=[Color("596c76"),Color("896255"),Color("7c8174")]
static var meshes={}
static var surface: StandardMaterial3D

static func variant_at(point: Vector3) -> int:return posmod(roundi(point.x*7+point.z*11),PALETTES.size())
static func height_at(x: float) -> float:return RIDGE-absf(x)*SLOPE

static func material() -> StandardMaterial3D:
 if surface==null:
  surface=StandardMaterial3D.new();surface.vertex_color_use_as_albedo=true;surface.vertex_color_is_srgb=true;surface.roughness=.95
 return surface

static func quad(tool: SurfaceTool,points: Array,normal: Vector3,color: Color):
 var indices=[0,1,2,0,2,3]
 if (points[1]-points[0]).cross(points[2]-points[0]).dot(normal)>0:indices=[0,2,1,0,3,2]
 var uv=[Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]
 for i in indices:
  tool.set_normal(normal.normalized());tool.set_color(color);tool.set_uv(uv[i]);tool.add_vertex(points[i])

static func roof(variant=0) -> ArrayMesh:
 variant=posmod(variant,PALETTES.size())
 if meshes.has(variant):return meshes[variant]
 var base=PALETTES[variant];var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for side in [-1,1]:
  var top=[Vector3(0,RIDGE,-HALF_DEPTH),Vector3(side*HALF_WIDTH,height_at(HALF_WIDTH),-HALF_DEPTH),Vector3(side*HALF_WIDTH,height_at(HALF_WIDTH),HALF_DEPTH),Vector3(0,RIDGE,HALF_DEPTH)]
  var bottom=top.map(func(point):return point-Vector3.UP*THICKNESS)
  quad(tool,top,Vector3(side*SLOPE,1,0),base.darkened(.12))
  quad(tool,bottom,Vector3(-side*SLOPE,-1,0),base.darkened(.30))
  for edge in [[0,1,Vector3.BACK*-1],[1,2,Vector3.RIGHT*side],[2,3,Vector3.BACK],[3,0,Vector3.LEFT*side]]:
   quad(tool,[top[edge[0]],bottom[edge[0]],bottom[edge[1]],top[edge[1]]],edge[2],base.darkened(.22))
  for row in range(6):
   var inner=row*HALF_WIDTH/6.0+.003;var outer=(row+1)*HALF_WIDTH/6.0-.003
   for column in range(9):
    var a=maxf(-HALF_DEPTH,-HALF_DEPTH+column*.2-(.1 if row%2 else 0))+.003
    var b=minf(HALF_DEPTH,-HALF_DEPTH+(column+1)*.2-(.1 if row%2 else 0))-.003
    if b<=a:continue
    var color=base.lightened(float((row*13+column*7+variant)%7)*.014)
    var y_inner=height_at(inner)+.009;var y_outer=height_at(outer)+.016
    var points=[Vector3(side*inner,y_inner,a),Vector3(side*outer,y_outer,a),Vector3(side*outer,y_outer,b),Vector3(side*inner,y_inner,b)]
    quad(tool,points,Vector3(side*(SLOPE-.007/(outer-inner)),1,0),color)
    quad(tool,[points[1],Vector3(side*outer,height_at(outer),a),Vector3(side*outer,height_at(outer),b),points[2]],Vector3.RIGHT*side,color.darkened(.14))
  for segment in range(8):
   var a=-HALF_DEPTH+segment*.2+.002;var b=a+.196
   quad(tool,[Vector3(0,RIDGE+.025,a),Vector3(side*.055,height_at(.055)+.025,a),Vector3(side*.055,height_at(.055)+.025,b),Vector3(0,RIDGE+.025,b)],Vector3(side*SLOPE,1,0),base.lightened(.12))
 var result=tool.commit();meshes[variant]=result;return result
