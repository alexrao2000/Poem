extends RefCounted
## Authored crest profiles form continuous distant hills; no gameplay RNG.

const COLUMNS=48
const ROWS=8
const WIDTH=192.0
const PROFILES=[
 [.18,.36,.78,.55,.95,.42,.63,1.0,.59,.32,.72,.48,.18],
 [.16,.43,.91,.54,.72,.34,1.0,.58,.87,.40,.68,.29,.12]]
const DEPTHS=[Vector2(-26,-48),Vector2(-40,-66),Vector2(-56,-86)]
static var meshes={}
static var materials={}

static func height_at(x: float,z: float,layer: int,mountain: bool) -> float:
 var u=clampf((x+WIDTH*.5)/WIDTH,0,1)
 var at=u*12;var index=mini(11,floori(at));var mix_value=at-index
 var profile=PROFILES[1 if mountain else 0]
 var a=profile[(index+layer*3)%profile.size()];var b=profile[(index+layer*3+1)%profile.size()]
 var crest=lerpf(a,b,mix_value if mountain else smoothstep(0,1,mix_value))
 crest+=sin(x*.59+layer*2.3)*(.035 if mountain else .016)
 var t=clampf((z-DEPTHS[layer].x)/(DEPTHS[layer].y-DEPTHS[layer].x),0,1)
 var peak=.45+sin(x*.11+layer)*.06
 var slope=t/peak if t<peak else (1-t)/(1-peak)
 slope=smoothstep(0,1,clampf(slope,0,1))
 var edge=smoothstep(0,.07,u)*smoothstep(0,.07,1-u)
 var height=(8.5+layer*4.5) if mountain else (5.8+layer*2.0)
 return maxf(0,crest)*slope*edge*height-.06

static func mesh(layer: int,mountain: bool) -> ArrayMesh:
 var key=str(layer)+str(mountain)
 if meshes.has(key):return meshes[key]
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in range(ROWS):
  for column in range(COLUMNS):
   var points=[]
   for corner in [[column,row],[column+1,row],[column+1,row+1],[column,row+1]]:
    var x=-WIDTH*.5+float(corner[0])/COLUMNS*WIDTH
    var z=lerpf(DEPTHS[layer].x,DEPTHS[layer].y,float(corner[1])/ROWS)
    points.append(Vector3(x,height_at(x,z,layer,mountain),z))
   for index in [0,2,1,0,3,2]:
    var point=points[index]
    var dx=(height_at(point.x+.1,point.z,layer,mountain)-height_at(point.x-.1,point.z,layer,mountain))/.2
    var dz=(height_at(point.x,point.z+.1,layer,mountain)-height_at(point.x,point.z-.1,layer,mountain))/.2
    surface.set_normal(Vector3(-dx,1,-dz).normalized())
    var shade=.83+clampf(point.y/(17.5 if mountain else 9.8),0,1)*.21+sin(point.x*.21+point.z*.13)*.025
    surface.set_color(Color(shade,shade,shade,1));surface.set_uv(Vector2(point.x,point.z)*.125);surface.add_vertex(point)
 meshes[key]=surface.commit();return meshes[key]

static func material(layer: int,mountain: bool) -> StandardMaterial3D:
 var key=str(layer)+str(mountain)
 if materials.has(key):return materials[key]
 var surface=StandardMaterial3D.new()
 surface.albedo_color=Color("626d73") if mountain else Color("617466")
 surface.albedo_color=surface.albedo_color.lerp(Color("869394"),layer*.15)
 surface.vertex_color_use_as_albedo=true;surface.vertex_color_is_srgb=true
 surface.roughness=1.0
 materials[key]=surface;return surface

static func build(parent: Node3D,center: Vector3,mountain: bool):
 for layer in range(3):
  var ridge=MeshInstance3D.new();ridge.name="ArenaRidge"+str(layer)
  ridge.mesh=mesh(layer,mountain);ridge.material_override=material(layer,mountain);ridge.position=center
  ridge.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  parent.add_child(ridge)
