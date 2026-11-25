extends Node
# The original Vanguard shoulder mantle follows the supplied upper spine.
# Preserve its lapels, fastening and personal palette without editing the source
# outfit. Private painted materials follow the actor's floor and defeat fade.
const COLLAR_SEGMENTS=14
const HEM_HEIGHT=.85
static var collar_meshes: Array[ArrayMesh]=[]
var model: Node3D
var anchor: BoneAttachment3D
var garment: Node3D
var surfaces=[]

func configure(body: Node3D,rig: Skeleton3D,painter,appearance: Dictionary,depth_scale=1.0,portrait_collar=false):
 model=body;anchor=BoneAttachment3D.new();anchor.name="ShoulderMantle";rig.add_child(anchor);anchor.bone_name="spine_03"
 var chest=rig.get_bone_global_rest(rig.find_bone("spine_03"));var neck=rig.get_bone_global_rest(rig.find_bone("neck_01")).origin
 var shoulder=rig.get_bone_global_rest(rig.find_bone("upperarm_l")).origin
 garment=Node3D.new();garment.name="IvoryMantle";anchor.add_child(garment)
 var width=(absf(shoulder.x)+.04)/.28
 garment.transform=chest.affine_inverse()*Transform3D(Basis(Vector3.UP,PI).scaled(Vector3(width,1,depth_scale)),neck+Vector3(0,-.47,0))
 var ivory=Color(appearance.cape);var gold=Color("bca26b")
 painter.shell(garment,Vector3(0,0,.025),[[.34,.30,.23],[.425,.30,.20],[.455,.25,.15],[.48,.11,.10]],ivory)
 for side in [-1,1]:
  painter.cloth(garment,[Vector3(side*.09,.44,-.13),Vector3(side*.27,.34,-.15),Vector3(side*.24,.20,-.24),Vector3(0,.34,-.26)],ivory)
  var chain=painter.geo.block(garment,Vector3(side*.13,.31,-.27),Vector3(.23,.016,.018),gold);chain.rotation.z=side*.42
 painter.ellipsoid(garment,Vector3(0,.34,-.275),Vector3(.04,.045,.018),gold)
 var cloth=painter.painted(ivory,0).duplicate();var metal=painter.painted(gold,1,true).duplicate();surfaces=[cloth,metal]
 cloth.set_shader_parameter("fabric_detail",.25)
 for mesh in garment.find_children("*","MeshInstance3D",true,false):
  var material=mesh.get_active_material(0);mesh.material_override=metal if material.albedo_color.is_equal_approx(gold) else cloth
 if portrait_collar:
  var navy=painter.painted(Color(appearance.cloth),0).duplicate()
  navy.set_shader_parameter("fabric_detail",.25);surfaces.append(navy)
  var collar=standing_collar()
  painter.geo.mesh(garment,collar[0],Vector3.ZERO,Vector3.ONE,navy).name="StandingCollar"
  painter.geo.mesh(garment,collar[1],Vector3.ZERO,Vector3.ONE,metal).name="CollarPiping"
  clasp_inlay(painter,navy)
 for material in surfaces:
  material.set_shader_parameter("cloth_amount",0.0);material.set_shader_parameter("cloth_floor_enabled",true);material.set_shader_parameter("cloth_floor_y",.018)
 painter.geo.batcher.combine(garment,false);anchor.on_skeleton_update()

# The collar opens below the chin. Its lining meets a narrow gold binding,
# and the back rises above the fitted ivory mantle.
static func collar_point(angle: float,height: float,inset=0.0) -> Vector3:
 var upper=.498+.019*(1.0-cos(angle))
 return Vector3(sin(angle)*(lerpf(.147,.139,height)-inset),
  lerpf(.430,upper,height),-.012-cos(angle)*(lerpf(.114,.103,height)-inset))

static func collar_quad(surface: SurfaceTool,points: Array,normal: Vector3):
 var winding=[0,1,2,0,2,3]
 if (points[1]-points[0]).cross(points[2]-points[0]).dot(normal)>0:winding=[0,2,1,0,3,2]
 var uv=[Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]
 for index in winding:
  surface.set_normal(normal);surface.set_uv(uv[index]);surface.add_vertex(points[index])

static func standing_collar() -> Array[ArrayMesh]:
 if not collar_meshes.is_empty():return collar_meshes
 var cloth=SurfaceTool.new();cloth.begin(Mesh.PRIMITIVE_TRIANGLES)
 var piping=SurfaceTool.new();piping.begin(Mesh.PRIMITIVE_TRIANGLES)
 var opening=.43
 for index in COLLAR_SEGMENTS:
  var start=lerpf(opening,TAU-opening,float(index)/COLLAR_SEGMENTS)
  var stop=lerpf(opening,TAU-opening,float(index+1)/COLLAR_SEGMENTS)
  var center=(start+stop)*.5
  var outward=Vector3(sin(center),0,-cos(center))
  var bottom=[collar_point(start,0),collar_point(stop,0)]
  var hem=[collar_point(start,HEM_HEIGHT),collar_point(stop,HEM_HEIGHT)]
  var edge=[collar_point(start,1),collar_point(stop,1)]
  var lip=[collar_point(start,1,.008),collar_point(stop,1,.008)]
  var inside=[collar_point(start,0,.008),collar_point(stop,0,.008)]
  collar_quad(cloth,[bottom[0],bottom[1],hem[1],hem[0]],outward)
  collar_quad(cloth,[inside[0],inside[1],lip[1],lip[0]],-outward)
  collar_quad(cloth,[bottom[0],bottom[1],inside[1],inside[0]],Vector3.DOWN)
  collar_quad(piping,[hem[0],hem[1],edge[1],edge[0]],outward)
  collar_quad(piping,[edge[0],edge[1],lip[1],lip[0]],Vector3.UP)
  if index==0 or index==COLLAR_SEGMENTS-1:
   var end=0 if index==0 else 1
   var normal=Vector3(cos(opening)*(-1 if end==0 else 1),0,-sin(opening))
   collar_quad(cloth,[bottom[end],inside[end],lip[end],edge[end]],normal)
 piping.index()
 collar_meshes=[cloth.commit(),piping.commit()]
 return collar_meshes

func clasp_inlay(painter,navy: ShaderMaterial):
 var center=Vector3(0,.34,-.295)
 for sign_value in [-1,1]:
  var middle=center+Vector3(sign_value*.019,0,0)
  var top=center+Vector3(sign_value*.004,.021,0)
  var bottom=center+Vector3(sign_value*.004,-.021,0)
  var inner=middle-Vector3(sign_value*.007,0,0)
  var pattern=painter.cloth(garment,[top,middle,bottom,inner],Color.WHITE)
  pattern.name="ClaspInlay";pattern.material_override=navy

func materials_remapped(copies: Dictionary):
 for index in range(surfaces.size()):surfaces[index]=copies.get(surfaces[index],surfaces[index])

func _process(_delta):
 if not is_instance_valid(model) or not model.is_visible_in_tree():return
 for material in surfaces:material.set_shader_parameter("cloth_floor_y",model.get_parent().global_position.y+.018)
