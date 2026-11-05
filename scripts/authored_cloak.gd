extends Node
# The original company cloak follows the supplied upper spine. Rest-space
# fitting leaves the same shoulder edge and forked hem on both body proportions.
const Motion=preload("res://scripts/cape_motion.gd")
var anchor: BoneAttachment3D
var cloth: MeshInstance3D
var motion=Motion.new()
var model: Node3D
var elapsed=0.0
var pose_name="idle"

func configure(body: Node3D,rig: Skeleton3D,painter,appearance: Dictionary,cut="forked"):
 model=body
 anchor=BoneAttachment3D.new();anchor.name="CompanyCloak";rig.add_child(anchor);anchor.bone_name="spine_03"
 var rest=rig.get_bone_global_rest(rig.find_bone("spine_03"))
 var neck=rig.get_bone_global_rest(rig.find_bone("neck_01")).origin
 var arm=rig.get_bone_global_rest(rig.find_bone("upperarm_l")).origin
 var cape=Node3D.new();cape.name="Cape";anchor.add_child(cape)
 var width=(absf(arm.x)+.06)*4.0
 cape.transform=rest.affine_inverse()*Transform3D(Basis(Vector3.UP,PI).scaled(Vector3(width,1,1)),neck+Vector3(0,-.025,-.07))
 var color=Color(appearance.cape)
 painter.cape_surface(cape,color,true,Color("bca26b"),cut)
 cloth=cape.get_child(0);cloth.name="CompanyFabric"
 var material=painter.painted(color,0).duplicate()
 material.set_shader_parameter("fabric_detail",.25)
 material.set_shader_parameter("cloth_amount",1.0)
 material.set_shader_parameter("cloth_floor_enabled",true)
 material.set_shader_parameter("cloth_floor_y",.018)
 material.set_shader_parameter("cape_mark",painter.COMPANY_CAPE)
 material.set_shader_parameter("cape_trim",Color("bca26b").lightened(.10))
 cloth.material_override=material;motion.surfaces.append(material);motion.update(0,pose_name,0)
 anchor.on_skeleton_update()

func combat_pose(key: String):pose_name=key

func materials_remapped(copies: Dictionary):
 for index in range(motion.surfaces.size()):motion.surfaces[index]=copies.get(motion.surfaces[index],motion.surfaces[index])

func _process(delta):
 if not is_instance_valid(model) or not model.is_visible_in_tree():return
 elapsed+=maxf(0,delta);motion.update(elapsed,pose_name,delta)
 for material in motion.surfaces:material.set_shader_parameter("cloth_floor_y",model.get_parent().global_position.y+.018)
