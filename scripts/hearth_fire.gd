extends "res://scripts/beacon_flame.gd"
## A shared cluster of firebox flames with a phase seeded by the mapped hearth.

const TONGUES=[
 [Vector3(-.125,0,-.025),.082,.27,-.047],
 [Vector3(.006,0,.005),.104,.38,.027],
 [Vector3(.133,0,-.044),.081,.31,.059],
]
const COAL_RED=Color("ab492d")
const GOLD=Color("f4b15b")
const ORANGE=Color("d76433")
static var flame_mesh: ArrayMesh
static var flame_paint: StandardMaterial3D

func configure(site: Vector2):
 name="HearthFire";position=Vector3(0,.18,.242)
 set_meta("hearth_site",site);seek_phase(site.x*.71+site.y*.37)
 var flame=MeshInstance3D.new();flame.name="Tongues"
 flame.mesh=shape();flame.material_override=paint()
 flame.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(flame)

static func paint() -> StandardMaterial3D:
 if flame_paint==null:
  flame_paint=StandardMaterial3D.new()
  flame_paint.vertex_color_use_as_albedo=true;flame_paint.vertex_color_is_srgb=true
  flame_paint.emission_enabled=true;flame_paint.emission=Color("d75b2e")
  flame_paint.emission_energy_multiplier=.48;flame_paint.roughness=1.0
 return flame_paint

static func shape() -> ArrayMesh:
 if flame_mesh!=null:return flame_mesh
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for tongue in TONGUES:
  var center: Vector3=tongue[0];var width: float=tongue[1];var height: float=tongue[2];var lean: float=tongue[3]
  var bottom=[];var waist=[]
  for axis in [Vector3.RIGHT,Vector3.FORWARD*.56,Vector3.LEFT,Vector3.BACK*.56]:
   bottom.append(center+axis*width*.7)
   waist.append(center+Vector3(lean*.22,height*.34,.012)+axis*width)
  var tip=center+Vector3(lean,height,-.041)
  for edge in 4:
   var next=(edge+1)%4
   triangle(tool,bottom[edge],waist[edge],waist[next],COAL_RED,GOLD,GOLD)
   triangle(tool,bottom[edge],waist[next],bottom[next],COAL_RED,GOLD,COAL_RED)
   triangle(tool,waist[edge],tip,waist[next],GOLD,ORANGE,GOLD)
  triangle(tool,bottom[0],bottom[1],bottom[2],COAL_RED,COAL_RED,COAL_RED)
  triangle(tool,bottom[0],bottom[2],bottom[3],COAL_RED,COAL_RED,COAL_RED)
 flame_mesh=tool.commit()
 return flame_mesh

static func triangle(tool: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,base: Color,middle: Color,edge: Color):
 var normal=(c-a).cross(b-a).normalized()
 for vertex in [[a,base],[b,middle],[c,edge]]:
  tool.set_color(vertex[1]);tool.set_normal(normal);tool.add_vertex(vertex[0])
