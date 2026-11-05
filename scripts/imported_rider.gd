extends "res://scripts/imported_fighter.gd"
# Preserve the imported actor's pose/events interface while the horse supplies
# its stride, hoof contacts and the mounted body's support height.
const Stride=preload("res://scripts/mount_stride.gd")
var mount: Node3D
func configure(scene: Node3D,spec: Dictionary) -> String:
 var error=super(scene,spec)
 if not error.is_empty():return error
 mount=model.get_node_or_null(NodePath(spec.get("mount","")))
 if mount==null or not mount.has_method("begin_pose") or not mount.configured:return "Mounted actor needs a configured horse"
 var equipment=model.get_node(NodePath(spec.equipment))
 mount.fit_reins(equipment.rein_pad);stride_length=Stride.LENGTH;stride_contacts=[.25,.75]
 set_meta("mount_appearance",mount.get_meta("mount_appearance"));return ""
func pose(key: String,duration=.18) -> Tween:
 # Start the support blend first so it settles before the public pose
 # completion signal advances combat to the next action.
 if is_instance_valid(mount):mount.begin_pose(key,duration)
 return super(key,duration)
func advance_stride(travelled: float):
 if pose_name!="advance" or not is_finite(travelled):return
 var length=stride_length*model.global_basis.z.length()
 if absf(travelled)>length*2:return
 mount.set_clock(fposmod(stride_phase+travelled/length,1.0)*TAU)
 super(travelled)
func nominal_stride_speed() -> float:return 2.7*model.global_basis.z.length()
func ground_contact_position() -> Vector3:return mount.ground_contact_position() if is_instance_valid(mount) else global_position
func refresh_skeleton():
 super()
 if is_instance_valid(mount):mount.refresh_reins()
