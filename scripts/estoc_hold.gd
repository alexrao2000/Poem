extends "res://scripts/weapon_floor.gd"
# A point-first sword thrust over private copies of the source idle motion.
# The wrist follows the actual blade tip, preserving grip and arm lengths.
# The existing attack intervals remain compatible with playback and previews.

var equipment: Node3D
var lift=0.0
var thrust=0.0
var holding=true
var aim_point=Vector3.ZERO
var has_aim=false
var arm_chain: Array[int]=[]
var spine=-1
var head=-1

func setup(skeleton: Skeleton3D,grip: Node3D):
 configure(skeleton,Transform3D.IDENTITY);equipment=grip
 fit_prop(grip.get_parent(),grip.get_node("Weapon"))
 arm_chain=chain.duplicate();spine=rig.find_bone("spine_01");head=rig.find_bone("Head");chain.append(spine);chain.append(head)

func solve() -> Array[Quaternion]:
 var combined=chain.duplicate();var originals: Array[Quaternion]=[]
 for bone in combined:originals.append(rig.get_bone_pose_rotation(bone))
 if holding:
  var head_basis=rig.get_bone_global_pose(head).basis
  aim(spine,Basis(Vector3.RIGHT,.55*smoothstep(0,1,lift))*rig.get_bone_global_pose(spine).basis)
  aim(head,head_basis)
 chain=arm_chain;super();chain=combined;return originals

func configure_animations(player: AnimationPlayer):
 var library=player.get_animation_library("")
 var ready=player.get_animation("Idle").duplicate(true)
 library.remove_animation("Sword_Idle");library.add_animation("Sword_Idle",ready)
 var attack=ready.duplicate(true);attack.length=1.5333333
 for pair in [["lift",[0,1,1,0]],["thrust",[0,0,1,0]]]:
  var track=attack.add_track(Animation.TYPE_VALUE);attack.track_set_path(track,NodePath("Armature/Skeleton3D/EstocArm:"+pair[0]))
  var times=[0,.36,.433,1.5333333]
  for index in range(times.size()):attack.track_insert_key(track,times[index],float(pair[1][index]))
 library.remove_animation("Sword_Attack");library.add_animation("Sword_Attack",attack)

func combat_pose(key: String):
 holding=key in ["idle","guard","windup","critical_windup","strike","recover"]
 if key not in ["strike","recover"]:lift=0;thrust=0

func aim_at(point: Vector3):
 if point.is_finite():aim_point=point;has_aim=true

func clear_aim():has_aim=false

func target_pose() -> Transform3D:
 if not holding:return super()
 var shoulder=rig.get_bone_global_pose(chain[2]).origin
 var carry=shoulder+Vector3(-.03,-.25,.23)
 var destination=rig.to_local(aim_point) if has_aim else Vector3(0,1.1,1.4)
 var forward=(destination-shoulder).normalized()
 if absf(forward.dot(Vector3.UP))>.995:forward=Vector3.BACK
 var x=Vector3.UP.cross(forward).normalized();var basis=Basis(x,forward.cross(x),forward)
 var tip=equipment.transform*equipment.get_node("Weapon").transform*equipment.get_node("Weapon/TrailTip").position
 var goal=destination-basis*tip-forward*.28*(1-thrust)
 var up=Vector3(0,.32,.95).normalized();var carry_basis=Basis(Vector3.RIGHT,up.cross(Vector3.RIGHT),up)
 return clear_floor(Transform3D(carry_basis,carry).interpolate_with(Transform3D(basis,goal),smoothstep(0,1,lift)))

func bend_pole(desired: Transform3D,upper: Transform3D,elbow: Transform3D) -> Vector3:
 return Vector3(-1,-.4,0) if holding else super(desired,upper,elbow)
