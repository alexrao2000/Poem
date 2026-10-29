extends Node3D
# Presentation rig with separate pose and locomotion ownership. Actors face -Z;
# arms lift forward with positive X, knees bend back, and mounted sockets rise.
var bones: Dictionary = {}
var rest: Dictionary = {}
var kind = "sword"
var mounted = false
var pose_name = "idle"
var elapsed = 0.0
var pose_tween: Tween
var facing = 1.0
var weapon_aim=0.0
var aim_target=Vector3.ZERO
var has_aim_target=false

func register_bone(key: String,node: Node3D):
 bones[key]=node
 rest[key]={"rotation":node.rotation,"position":node.position}

func bone(key: String) -> Node3D:
 return bones.get(key)

func _process(dt):
 elapsed+=dt
 if bones.has("Cape"):
  bones.Cape.rotation.x=sin(elapsed*2.7)*.07+(.18 if pose_name in ["advance","strike"] else .04)
 if pose_name=="idle":
  if bones.has("Body"):bones.Body.position.y=rest.Body.position.y+sin(elapsed*2.4)*.006
  if bones.has("Head"):bones.Head.rotation.z=sin(elapsed*1.3)*.012
 elif pose_name=="advance":
  var gait=sin(elapsed*18)*.48
  if mounted:
   for i in range(4):
    var key="HorseLeg"+str(i)
    if bones.has(key):bones[key].rotation.x=sin(elapsed*15+i*PI*.5)*.42
  else:
   bones.LeftLeg.rotation.x=gait;bones.RightLeg.rotation.x=-gait
   bones.LeftKnee.rotation.x=-maxf(0,-gait)*.75;bones.RightKnee.rotation.x=-maxf(0,gait)*.75
 if kind=="lance" and pose_name in ["windup","strike"] and bones.has("Weapon"):
  var grip=bones.Weapon
  var direction=aim_target-grip.global_position if has_aim_target else -global_transform.basis.z
  if direction.length_squared()>.001:
   var desired=Basis.looking_at(direction.normalized(),Vector3.UP)
   var local_basis=grip.get_parent().global_transform.basis.inverse()*desired
   grip.quaternion=Quaternion.from_euler(rest.Weapon.rotation).slerp(local_basis.get_rotation_quaternion(),weapon_aim)

func aim_at(point: Vector3):
 aim_target=point;has_aim_target=true

static func melee_spacing(weapon: String) -> float:
 return {"sword":1.4,"axe":1.3,"lance":2.1}.get(weapon,1.4)

func pose(key: String,duration=.18) -> Tween:
 if pose_tween and pose_tween.is_valid():pose_tween.kill()
 pose_name=key
 var target={
  "Body":Vector3(0,0,0),"Head":Vector3(0,0,0),
  "Arm":Vector3(-.58,-.12,-.16),"Elbow":Vector3(-.48,0,0),
  "LeftArm":Vector3(-.25,0,.18),"LeftElbow":Vector3(-.4,0,0),
  "LeftLeg":Vector3(-.14,0,-.035),"LeftKnee":Vector3(.14,0,0),
  "RightLeg":Vector3(.12,0,.035),"RightKnee":Vector3(.20,0,0)
 }
 if rest.has("Weapon"):target.Weapon=rest.Weapon.rotation
 if kind=="bow":
  target.Arm=Vector3(-1.35,0,-.18);target.Elbow=Vector3(-.3,0,0)
  target.LeftArm=Vector3(-.9,0,.25);target.LeftElbow=Vector3(-.8,0,0)
 elif kind in ["magic","staff"]:
  target.Arm=Vector3(-.1,0,-.12);target.Elbow=Vector3(-.18,0,0)
 if key=="windup":
  target.Body=Vector3(.08,-.25,0)
  target.Arm=Vector3(-2.2,-.15,-.45);target.Elbow=Vector3(-.8,0,0)
  target.LeftArm=Vector3(-.3,0,.5)
  target.LeftLeg.x=-.28;target.RightLeg.x=.3;target.RightKnee.x=.42
  if kind=="axe":
   target.Body=Vector3(.1,-.4,-.08);target.Arm=Vector3(-2.65,-.2,-.35);target.Elbow=Vector3(-.95,0,0)
   target.LeftArm=Vector3(-.7,0,.5);target.RightKnee.x=.55
  elif kind=="lance":
   target.Arm=Vector3(-.3,.2,-.1);target.Elbow=Vector3(-1.2,0,0)
  elif kind=="bow":
   target.Arm=Vector3(-1.5,0,-.15);target.Elbow=Vector3(0,0,0)
   target.LeftArm=Vector3(-1.2,.6,.5);target.LeftElbow=Vector3(-1.8,0,0)
  elif kind in ["magic","staff"]:
   target.Arm=Vector3(-1.8,0,-.4);target.Elbow=Vector3(-.2,0,0)
   target.LeftArm=Vector3(-.9,0,.45);target.LeftElbow=Vector3(-.5,0,0)
 elif key=="strike":
  target.Body=Vector3(.17,.3,0)
  target.Arm=Vector3(-.45,-.25,.23);target.Elbow=Vector3(-.1,0,0)
  target.LeftArm=Vector3(.28,0,.3)
  target.LeftLeg.x=-.35;target.RightLeg.x=.4;target.RightKnee.x=.45
  if kind=="axe":
   target.Body=Vector3(.27,.38,.05);target.Arm=Vector3(-.3,-.15,.2);target.Elbow=Vector3(-.06,0,0)
  elif kind=="lance":
   target.Arm=Vector3(-1.0,0,-.05)
  elif kind=="bow":
   target.Arm=Vector3(-1.5,0,-.15);target.Elbow=Vector3(0,0,0)
   target.LeftArm=Vector3(-.8,.9,.7);target.LeftElbow=Vector3(-1.6,0,0)
  elif kind in ["magic","staff"]:
   target.Arm=Vector3(-1.1,0,-.35);target.LeftArm=Vector3(-1.3,0,.3)
 elif key=="throw_windup":
  target.Body=Vector3(.08,-.4,0);target.Arm=Vector3(-2.5,0,-.25);target.Elbow=Vector3(-1.1,0,0)
 elif key=="throw":
  target.Body=Vector3(.15,.35,0);target.Arm=Vector3(-1.3,0,.05);target.Elbow=Vector3(0,0,0)
 elif key=="hit":
  target.Body=Vector3(-.25,0,0);target.Head=Vector3(-.15,0,.08)
  target.Arm=Vector3(.1,0,-.4);target.LeftArm=Vector3(.2,0,.4)
  target.LeftKnee.x=.38;target.RightKnee.x=.42
 elif key=="evade":
  target.Body=Vector3(-.36,0,.10);target.LeftKnee.x=.45;target.RightKnee.x=.55
 elif key=="down":
  target.Body=Vector3(.6,0,.25);target.Head=Vector3(.3,0,0)
  target.LeftLeg.x=-.7;target.LeftKnee.x=1.45;target.RightLeg.x=-.3;target.RightKnee.x=1.25
  target.Arm=Vector3(.2,0,-.3);target.LeftArm=Vector3(.3,0,.2)
 if mounted:
  for leg in ["LeftLeg","RightLeg"]:target[leg].x=.85
  target.LeftLeg.z=-.18;target.RightLeg.z=.18
  target.LeftKnee.x=1.25;target.RightKnee.x=1.25
  if key!="advance":
   for i in range(4):target["HorseLeg"+str(i)]=Vector3.ZERO
 if key=="advance" and not mounted:
  for leg in ["LeftLeg","RightLeg","LeftKnee","RightKnee"]:target.erase(leg)
 var aiming=kind=="lance" and key in ["windup","strike"] and bones.has("Weapon")
 if aiming:target.erase("Weapon")
 elif key!="strike":weapon_aim=0.0
 pose_tween=create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
 if aiming:pose_tween.tween_property(self,"weapon_aim",1.0,duration)
 for name_value in target:
  if name_value in ["Arm","Elbow","LeftArm","LeftElbow","LeftKnee","RightKnee","Body","Head"]:
   target[name_value].x=-target[name_value].x
  if key=="down" and name_value in ["LeftLeg","RightLeg"]:target[name_value].x=-target[name_value].x
  if bones.has(name_value):pose_tween.tween_property(bones[name_value],"rotation",target[name_value],duration)
 if bones.has("Body"):
  pose_tween.tween_property(bones.Body,"position:y",rest.Body.position.y-(.43 if key=="down" else 0.0),duration)
 return pose_tween

func socket_position(key: String) -> Vector3:
 return global_position+Vector3(0,(1.2 if key=="projectile" else 1.1)+(.75 if mounted else 0.0),0)
