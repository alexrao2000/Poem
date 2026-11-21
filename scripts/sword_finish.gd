extends "res://scripts/weapon_floor.gd"
# A small blade lift punctuates the resolved win, then returns to the existing
# relaxed hold. Only the fitted arm rotates; body animation and grips stay intact.
var lift=0.0

func setup(skeleton: Skeleton3D,grip: Node3D):
 configure(skeleton,Transform3D.IDENTITY)
 fit_prop(grip.get_parent(),grip.get_node("Weapon"));active=false

func configure_animations(player: AnimationPlayer):
 var animation=player.get_animation("Idle").duplicate(true);animation.length=.2
 var track=animation.add_track(Animation.TYPE_VALUE)
 animation.track_set_path(track,NodePath("Armature/Skeleton3D/SwordFinish:lift"))
 animation.track_set_interpolation_type(track,Animation.INTERPOLATION_CUBIC)
 for pair in [[0,0],[.04,.25],[.10,1],[.20,0]]:animation.track_insert_key(track,pair[0],float(pair[1]))
 var library=player.get_animation_library("")
 if library.has_animation("SwordFinishFlourish"):library.remove_animation("SwordFinishFlourish")
 library.add_animation("SwordFinishFlourish",animation)

func combat_pose(key: String):
 active=key=="victory_flourish"
 if not active:lift=0

func target_pose() -> Transform3D:
 var goal=rig.get_bone_global_pose(chain[0]);var amount=smoothstep(0,1,lift)
 goal.origin+=Vector3(0,.10,.02)*amount
 goal.basis=Basis(Vector3.RIGHT,-.35*amount)*goal.basis
 return clear_floor(goal)

func solve() -> Array[Quaternion]:
 if active:return super()
 var originals: Array[Quaternion]=[]
 for bone in chain:originals.append(rig.get_bone_pose_rotation(bone))
 return originals
