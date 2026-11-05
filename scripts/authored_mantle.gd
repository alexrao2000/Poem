extends Node
# Lyra's original ivory shoulder mantle follows the supplied upper spine.
# Preserve its lapels, fastening and personal palette without editing the source
# outfit. Private painted materials follow the actor's floor and defeat fade.
var model: Node3D
var anchor: BoneAttachment3D
var garment: Node3D
var surfaces=[]

func configure(body: Node3D,rig: Skeleton3D,painter,appearance: Dictionary):
 model=body;anchor=BoneAttachment3D.new();anchor.name="ShoulderMantle";rig.add_child(anchor);anchor.bone_name="spine_03"
 var chest=rig.get_bone_global_rest(rig.find_bone("spine_03"));var neck=rig.get_bone_global_rest(rig.find_bone("neck_01")).origin
 var shoulder=rig.get_bone_global_rest(rig.find_bone("upperarm_l")).origin
 garment=Node3D.new();garment.name="IvoryMantle";anchor.add_child(garment)
 var width=(absf(shoulder.x)+.04)/.28
 garment.transform=chest.affine_inverse()*Transform3D(Basis(Vector3.UP,PI).scaled(Vector3(width,1,1)),neck+Vector3(0,-.47,0))
 var ivory=Color(appearance.cape);var gold=Color("bca26b")
 painter.shell(garment,Vector3(0,0,.025),[[.34,.30,.23],[.425,.30,.20],[.455,.25,.15],[.48,.11,.10]],ivory)
 for side in [-1,1]:
  painter.cloth(garment,[Vector3(side*.09,.44,-.13),Vector3(side*.27,.34,-.15),Vector3(side*.24,.20,-.24),Vector3(0,.34,-.26)],ivory)
  var chain=painter.geo.block(garment,Vector3(side*.13,.31,-.27),Vector3(.23,.016,.018),gold);chain.rotation.z=side*.42
 painter.ellipsoid(garment,Vector3(0,.34,-.275),Vector3(.04,.045,.018),gold)
 var cloth=painter.painted(ivory,0).duplicate();var metal=painter.painted(gold,1,true).duplicate();surfaces=[cloth,metal]
 cloth.set_shader_parameter("fabric_detail",.25)
 for material in surfaces:
  material.set_shader_parameter("cloth_amount",0.0);material.set_shader_parameter("cloth_floor_enabled",true);material.set_shader_parameter("cloth_floor_y",.018)
 for mesh in garment.find_children("*","MeshInstance3D",true,false):
  var material=mesh.get_active_material(0);mesh.material_override=metal if material.albedo_color.is_equal_approx(gold) else cloth
 painter.geo.batcher.combine(garment,false);anchor.on_skeleton_update()

func materials_remapped(copies: Dictionary):
 for index in range(surfaces.size()):surfaces[index]=copies.get(surfaces[index],surfaces[index])

func _process(_delta):
 if not is_instance_valid(model) or not model.is_visible_in_tree():return
 for material in surfaces:material.set_shader_parameter("cloth_floor_y",model.get_parent().global_position.y+.018)
