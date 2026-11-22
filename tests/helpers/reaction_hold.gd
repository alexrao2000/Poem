extends RefCounted
# Check actual revised contact ownership while the scene's local hit stop is
# active. Pausing its timer makes the two frozen-frame samples deterministic.

const Imported=preload("res://scripts/imported_fighter.gd")
static func verify(node,critical: bool):
 var tree=node.get_tree()
 await tree.process_frame
 node.motion.pause()
 var targets=node.held.filter(func(entry):return entry.actor.pose_name in ["hit","critical_hit"])
 assert(targets.size()==1 and targets[0].actor is Imported)
 var target=targets[0].actor;var mapping=target.poses[target.pose_name]
 assert(mapping.clip=="Hit_Chest" and (is_equal_approx(mapping.to,.1) if critical else mapping.to==target.player.get_animation(mapping.clip).length),"Actual resolved contacts choose the critical recoil segment or unchanged ordinary interval")
 var rig=target.model.get_node("Rig/Armature/Skeleton3D");var frozen=rig.get_bone_global_pose(rig.find_bone("spine_03"));var cursor=target.player.current_animation_position
 for frame in range(2):await tree.process_frame
 assert(rig.get_bone_global_pose(rig.find_bone("spine_03"))==frozen and target.player.current_animation_position==cursor,"Actual revised reaction and source cursor remain frozen during local hit stop")
 node.motion.play()
