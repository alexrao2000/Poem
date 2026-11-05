extends Node3D
# Horse travel and source-body support share one distance clock. The rider's
# seat and stirrups move with the same measured hoof support height.
const Mount=preload("res://scripts/mount_visuals.gd")
const Stride=preload("res://scripts/mount_stride.gd")
var bones={}
var rest={}
var reins: MeshInstance3D
var source_rig: Node3D
var skeleton: Skeleton3D
var rein_grip: Node3D
var base_lift=0.0
var support_height=0.0
var clock=0.0
var gait_weight=0.0
var elapsed=0.0
var pose_name="idle"
var transition: Tween
var configured=false
func register_bone(key: String,node: Node3D):
 bones[key]=node;rest[key]={"rotation":node.rotation,"position":node.position}
func configure_mount(id: String) -> String:
 if configured:return "Mount is already configured"
 var model=get_parent();source_rig=model.get_node_or_null("Rig");skeleton=model.get_node_or_null("Rig/Armature/Skeleton3D") as Skeleton3D;rein_grip=model.get_node_or_null("Rig/Armature/Skeleton3D/ReinHand/Grip")
 if source_rig==null or skeleton==null or rein_grip==null:return "Mounted model needs its source rig and rein grip"
 base_lift=source_rig.position.y
 var painter=load("res://scripts/fighters.gd").new();var look=painter.profiles.get(id,{}).get("appearance",{})
 Mount.build(painter,self,id,Color(look.get("cloth","3d566d")),Color(look.get("metal","bca26b")),Color("554337"))
 for bone in bones.values():bone.set_meta("dynamic",true)
 for name_value in ["LeftStirrup","RightStirrup"]:bones.Horse.get_node(name_value).set_meta("dynamic",true)
 reins.set_meta("dynamic",true)
 var parts=[self];parts.append_array(bones.values())
 for part in parts:painter.geo.batcher.combine(part,false)
 configured=true;update_pose();return ""
func _ready():
 if skeleton!=null:skeleton.skeleton_updated.connect(refresh_reins)
func fit_reins(pad: Vector3):rein_grip.position=pad
func rein_grip_position() -> Vector3:return rein_grip.global_position
func refresh_reins():
 if is_instance_valid(reins) and is_inside_tree():reins.update()
func begin_pose(key: String,duration: float):
 if transition and transition.is_valid():transition.kill()
 pose_name=key
 if key=="advance":clock=0.0
 transition=create_tween();transition.tween_property(self,"gait_weight",1.0 if key=="advance" else 0.0,maxf(.001,duration)).set_trans(Tween.TRANS_SINE)
func set_clock(value: float):
 clock=value;update_pose()
func update_pose():
 if not configured:return
 var poses=Stride.solve(clock)
 for key in poses:bones[key].rotation=poses[key]*gait_weight
 for index in range(4):
  var basis=bones["HorseLeg"+str(index)].basis*bones["HorseKnee"+str(index)].basis
  bones["HorseFoot"+str(index)].quaternion=basis.get_rotation_quaternion().inverse()
 var lowest=INF
 for index in range(4):
  var leg=bones["HorseLeg"+str(index)];var knee=bones["HorseKnee"+str(index)];var foot=bones["HorseFoot"+str(index)]
  var point=rest.Horse.position+leg.position+leg.basis*knee.position+leg.basis*knee.basis*foot.position+Mount.LEVEL_HOOF_CENTER
  lowest=minf(lowest,point.y-Mount.HOOF_RADII.y)
 support_height=-lowest;bones.Horse.position.y=rest.Horse.position.y+support_height;source_rig.position.y=base_lift+support_height
func _process(delta):
 if not configured or not is_visible_in_tree():return
 elapsed+=maxf(0,delta);update_pose()
 bones.HorseHead.rotation.x=rest.HorseHead.rotation.x+sin(clock*2 if pose_name=="advance" else elapsed*1.6)*(.04 if pose_name=="advance" else .015)
 bones.HorseTail.rotation.z=sin(elapsed*2.3)*(.10 if pose_name=="advance" else .045)
func ground_contact_position() -> Vector3:
 var point=Vector3(0,INF,0)
 for index in range(4):
  var foot=bones["HorseFoot"+str(index)];var axes=foot.global_basis.scaled_local(Mount.HOOF_RADII)
  var extent=Vector3(axes.x.y,axes.y.y,axes.z.y).length()
  var candidate=foot.to_global(Mount.LEVEL_HOOF_CENTER)-(axes.x*axes.x.y+axes.y*axes.y.y+axes.z*axes.z.y)/maxf(extent,.00001)
  if candidate.y<point.y:point=candidate
 return point
