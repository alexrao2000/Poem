extends RefCounted
# Steer the existing slash into its resolved contact point. The upper arm and
# rigid forearm/gripped blade form two segments; preserve their authored twist
# and elbow side, never stretch bones, and blend back out during recovery.

static func apply(actor):
 if actor.kind not in ["sword","axe"]:return
 var arm=actor.bones.get("Arm");var elbow=actor.bones.get("Elbow")
 if arm==null or elbow==null:return
 arm.rotation=actor.slash_arm_rotation;elbow.rotation=actor.slash_elbow_rotation
 if actor.slash_weight<=0 or not actor.has_aim_target or not actor.bones.has("Weapon") or actor.trail_edge.size()!=2:return
 var weapon=actor.bones.Weapon
 var lower_vector=elbow.to_local(weapon.to_global(actor.trail_edge[1]))
 var upper_vector=elbow.position
 var upper=upper_vector.length();var lower=lower_vector.length()
 var origin=arm.global_position;var displacement=actor.aim_target-origin
 if displacement.length()<.001 or upper<.001 or lower<.001:return
 var direction=displacement.normalized()
 var distance=clampf(displacement.length(),absf(upper-lower)+.0001,upper+lower-.0001)
 var pole=elbow.global_position-origin
 pole=(pole-direction*pole.dot(direction)).normalized()
 if pole.length_squared()<.001:
  pole=actor.global_basis.x;pole=(pole-direction*pole.dot(direction)).normalized()
 if pole.length_squared()<.001:pole=direction.cross(Vector3.UP).normalized()
 var along=(upper*upper-lower*lower+distance*distance)/(2*distance)
 var elbow_point=origin+direction*along+pole*sqrt(maxf(0,upper*upper-along*along))
 var endpoint=origin+direction*distance
 var raw_arm=arm.quaternion;var raw_elbow=elbow.quaternion
 var arm_turn=Quaternion((arm.global_basis*upper_vector).normalized(),(elbow_point-origin).normalized())
 var aimed_arm=arm_turn*arm.global_basis.get_rotation_quaternion()
 arm.quaternion=arm.get_parent().global_basis.get_rotation_quaternion().inverse()*aimed_arm
 var elbow_turn=Quaternion((elbow.global_basis*lower_vector).normalized(),(endpoint-elbow.global_position).normalized())
 var aimed_elbow=elbow_turn*elbow.global_basis.get_rotation_quaternion()
 elbow.quaternion=arm.global_basis.get_rotation_quaternion().inverse()*aimed_elbow
 var local_arm=arm.quaternion;var local_elbow=elbow.quaternion
 arm.quaternion=raw_arm.slerp(local_arm,actor.slash_weight)
 elbow.quaternion=raw_elbow.slerp(local_elbow,actor.slash_weight)
