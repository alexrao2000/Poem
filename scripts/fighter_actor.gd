extends Node3D
# Presentation rig with separate pose and locomotion ownership. Actors face -Z;
# arms lift forward with positive X, knees bend back, and mounted sockets rise.
# Infantry hips and legs lower together to the lowest ellipsoidal boot sole.
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
var grounded_stance=false
var support_height=0.0
var bow_draw=0.0:
 set(value):
  bow_draw=clampf(value,0,1);update_bow()
var drawing_arm_rotation=Vector3.ZERO
var drawing_elbow_rotation=Vector3.ZERO
var bow_hand_weight=0.0
var cape_motion=preload("res://scripts/cape_motion.gd").new()

func register_bone(key: String,node: Node3D):
 bones[key]=node
 rest[key]={"rotation":node.rotation,"position":node.position}

func bone(key: String) -> Node3D:
 return bones.get(key)

func _process(dt):
 elapsed+=dt
 cape_motion.update(elapsed,pose_name,dt)
 if bones.has("HorseTail"):bones.HorseTail.rotation.z=sin(elapsed*2.3)*(.10 if pose_name=="advance" else .045)
 if bones.has("HorseHead"):bones.HorseHead.rotation.x=sin(elapsed*(8.0 if pose_name=="advance" else 1.6))*(.04 if pose_name=="advance" else .015)
 if bones.has("Cape"):
  bones.Cape.rotation.x=sin(elapsed*2.7)*.07+(.18 if pose_name in ["advance","strike","recover"] else .04)
 if pose_name=="idle":
  if bones.has("Body"):bones.Body.position.y=rest.Body.position.y+support_height+sin(elapsed*2.4)*.006
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
 apply_constraints()

func apply_constraints():
 if kind=="magic" and pose_name!="down" and bones.has("Weapon"):
  var grip=bones.Weapon
  var reading_basis=global_basis*Basis(Vector3.RIGHT,PI*.5+.18)
  grip.quaternion=(grip.get_parent().global_basis.inverse()*reading_basis).get_rotation_quaternion()
  for key in ["LeftHand","RightHand"]:
   if not bones.has(key):continue
   var palm=bones[key]
   var palm_basis=reading_basis if key=="LeftHand" else global_basis*Basis(Vector3.RIGHT,PI*.5)
   palm.quaternion=(palm.get_parent().global_basis.inverse()*palm_basis).get_rotation_quaternion()
 if kind=="staff" and pose_name in ["cast_windup","cast"] and bones.has("Weapon"):
  var grip=bones.Weapon
  grip.quaternion=(grip.get_parent().global_basis.inverse()*global_basis).get_rotation_quaternion()
 if kind in ["lance","bow"] and pose_name in ["windup","critical_windup","strike","recover"] and bones.has("Weapon"):
  var grip=bones.Weapon
  var direction=aim_target-grip.global_position if has_aim_target else -global_transform.basis.z
  if direction.length_squared()>.001:
   var desired=Basis.looking_at(direction.normalized(),Vector3.UP)
   var local_basis=grip.get_parent().global_transform.basis.inverse()*desired
   grip.quaternion=Quaternion.from_euler(rest.Weapon.rotation).slerp(local_basis.get_rotation_quaternion(),weapon_aim)
 if kind=="bow":align_drawing_hand()

func align_drawing_hand():
 if not bones.has("NockedArrow") or not bones.has("LeftElbow"):return
 var arm=bones.LeftArm;var elbow=bones.LeftElbow
 arm.rotation=drawing_arm_rotation;elbow.rotation=drawing_elbow_rotation
 if bow_hand_weight<=0:return
 var target=bones.NockedArrow.to_global(Vector3(0,0,preload("res://scripts/combat_projectile.gd").ARROW_LENGTH*.5))
 var origin=arm.global_position;var delta=target-origin
 var length=clampf(delta.length(),.001,.5799);var direction=delta.normalized()
 var pole=global_basis*Vector3(-1,.15,.8)
 pole=(pole-direction*pole.dot(direction)).normalized()
 if pole.length_squared()<.001:pole=direction.cross(Vector3.UP).normalized()
 var elbow_point=origin+direction*length*.5+pole*sqrt(maxf(0,.29*.29-length*length*.25))
 var arm_direction=(arm.get_parent().global_basis.inverse()*(elbow_point-origin)).normalized()
 arm.quaternion=arm.quaternion.slerp(Quaternion(Vector3.DOWN,arm_direction),bow_hand_weight)
 var hand_direction=(arm.global_basis.inverse()*(origin+direction*length-elbow.global_position)).normalized()
 elbow.quaternion=elbow.quaternion.slerp(Quaternion(Vector3.DOWN,hand_direction),bow_hand_weight)

func update_bow():
 if not bones.has("BowStringTop") or not bones.has("NockedArrow"):return
 var nock=Vector3(0,0,.22+.30*bow_draw)
 bones.NockedArrow.position=nock-Vector3(0,0,preload("res://scripts/combat_projectile.gd").ARROW_LENGTH*.5)
 for i in range(2):
  var segment=bones["BowStringTop" if i==0 else "BowStringBottom"]
  var tip=Vector3(0,.45 if i==0 else -.45,.22)
  segment.position=(nock+tip)*.5
  segment.quaternion=Quaternion(Vector3.UP,(tip-nock).normalized())
  segment.scale=Vector3(1,tip.distance_to(nock),1)

func aim_at(point: Vector3):
 aim_target=point;has_aim_target=true

static func melee_spacing(weapon: String) -> float:
 return {"sword":1.4,"axe":1.3,"lance":2.1}.get(weapon,1.4)

func stance_height(target: Dictionary) -> float:
 var lowest=INF
 for side in ["Left","Right"]:
  var leg=Basis.from_euler(target[side+"Leg"]);var knee=leg*Basis.from_euler(target[side+"Knee"])
  var center=rest[side+"Leg"].position+leg*Vector3(0,-.36,0)+knee*Vector3(0,-.38,-.07)
  var radius=sqrt(pow(knee.x.y*.09,2)+pow(knee.y.y*.075,2)+pow(knee.z.y*.145,2))
  lowest=minf(lowest,center.y-radius)
 return -lowest

func pose(key: String,duration=.18) -> Tween:
 if pose_tween and pose_tween.is_valid():pose_tween.kill()
 if bones.has("Weapon") and key not in ["throw","throw_windup","critical_throw_windup","recover"]:bones.Weapon.visible=true
 if bones.has("NockedArrow") and key in ["idle","advance","windup","critical_windup"]:bones.NockedArrow.visible=true
 pose_name=key
 var target={
  "Body":Vector3(0,0,0),"Head":Vector3(0,0,0),
  "Arm":Vector3(-.58,-.12,-.16),"Elbow":Vector3(-.48,0,0),
  "LeftArm":Vector3(-.25,0,.18),"LeftElbow":Vector3(-.4,0,0),
  "LeftLeg":Vector3(-.14,0,-.035),"LeftKnee":Vector3(.14,0,0),
  "RightLeg":Vector3(.12,0,.035),"RightKnee":Vector3(.20,0,0)
 }
 if rest.has("Weapon"):target.Weapon=rest.Weapon.rotation
 for key_name in ["LeftHand","RightHand"]:
  if rest.has(key_name):target[key_name]=rest[key_name].rotation
 if kind=="bow":
  target.Arm=Vector3(-1.35,.15,-.18);target.Elbow=Vector3(-.3,0,0)
  target.LeftArm=Vector3(-.9,0,.25);target.LeftElbow=Vector3(-.8,0,0)
 elif kind in ["magic","staff"]:
  target.Arm=Vector3(-.1,0,-.12);target.Elbow=Vector3(-.18,0,0)
 if key in ["windup","critical_windup"]:
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
   target.Arm=Vector3(-1.5,.15,-.15);target.Elbow=Vector3(0,0,0)
   target.LeftArm=Vector3(-1.2,.6,.5);target.LeftElbow=Vector3(-1.8,0,0)
  elif kind in ["magic","staff"]:
   target.Arm=Vector3(-1.8,0,-.4);target.Elbow=Vector3(-.2,0,0)
   target.LeftArm=Vector3(-.9,0,.45);target.LeftElbow=Vector3(-.5,0,0)
  if key=="critical_windup":
   # A stronger anticipation resolves into the same tested contact pose.
   # Keep the bow shoulder geometry so the hand can still reach the nock.
   target.Head=Vector3(.08,.12,-.04)
   if kind!="bow":
    target.Body.y-=.2;target.LeftLeg.x=-.38;target.RightLeg.x=.4;target.RightKnee.x=.58
    if kind in ["sword","axe"]:
     target.Arm.x-=.28;target.Elbow.x-=.15;target.LeftArm.z+=.15
    elif kind=="lance":target.Elbow.x-=.18;target.LeftArm=Vector3(-.8,0,.5)
    elif kind in ["magic","staff"]:
     target.Arm=Vector3(-2.15,0,-.55);target.LeftArm=Vector3(-1.5,0,.65)
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
   target.Arm=Vector3(-1.5,.15,-.15);target.Elbow=Vector3(0,0,0)
   target.LeftArm=Vector3(-.8,.9,.7);target.LeftElbow=Vector3(-1.6,0,0)
  elif kind in ["magic","staff"]:
   target.Arm=Vector3(-1.1,0,-.35);target.LeftArm=Vector3(-1.3,0,.3)
 elif key=="recover":
  target.Body=Vector3(.12,.46,-.04);target.Arm=Vector3(.10,-.32,.36);target.Elbow=Vector3(-.22,0,0)
  target.LeftArm=Vector3(.15,0,.28);target.LeftLeg.x=-.30;target.RightLeg.x=.34;target.RightKnee.x=.45
  if kind=="axe":
   target.Body=Vector3(.21,.53,.05);target.Arm=Vector3(.16,-.18,.25)
  elif kind=="lance":
   target.Body=Vector3(.06,.08,0);target.Arm=Vector3(-.65,.1,-.08);target.Elbow=Vector3(-.85,0,0)
  elif kind=="bow":
   target.Body=Vector3(.06,.1,0);target.Arm=Vector3(-1.35,.15,-.18);target.Elbow=Vector3(-.15,0,0)
   target.LeftArm=Vector3(-.7,.3,.4);target.LeftElbow=Vector3(-.7,0,0)
  elif kind in ["magic","staff"]:
   target.Body=Vector3(.04,.06,0);target.Arm=Vector3(-.65,0,-.25);target.LeftArm=Vector3(-.7,0,.3)
 elif key in ["cast_windup","cast"]:
  target.Body=Vector3(0,-.08,0)
  target.Arm=Vector3(-1.1 if key=="cast_windup" else -.9,0,-.18);target.Elbow=Vector3(-.55,0,0)
  target.LeftArm=Vector3(-.6 if key=="cast_windup" else -1.0,0,.3);target.LeftElbow=Vector3(-.35,0,0)
 elif key in ["throw_windup","critical_throw_windup"]:
  target.Body=Vector3(.08,-.4,0);target.Arm=Vector3(-2.5,0,-.25);target.Elbow=Vector3(-1.1,0,0)
  if key=="critical_throw_windup":
   target.Body.y=-.65;target.Arm.x=-2.8;target.Elbow.x=-1.25
   target.LeftArm=Vector3(-.7,0,.65);target.Head=Vector3(.06,.15,0)
   target.LeftLeg.x=-.38;target.RightLeg.x=.4;target.RightKnee.x=.58
 elif key=="throw":
  target.Body=Vector3(.15,.35,0);target.Arm=Vector3(-1.3,0,.05);target.Elbow=Vector3(0,0,0)
 elif key=="guard":
  target.Body=Vector3(-.07,0,0)
  target.LeftArm=Vector3(-1.0,-.1,.1);target.LeftElbow=Vector3(-1.3,0,0)
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
 if kind=="magic" and key!="down":
  # The book stays in the left palm while the free right hand casts.
  target.LeftArm=Vector3(-.55,-.12,-.22);target.LeftElbow=Vector3(-1.05,0,0)
  if key=="strike":
   target.Body=Vector3(.12,.06,0);target.Arm=Vector3(-1.3,-.12,.08);target.Elbow=Vector3(-.1,0,0)
 if mounted:
  for leg in ["LeftLeg","RightLeg"]:target[leg].x=.85
  target.LeftLeg.z=-.18;target.RightLeg.z=.18
  target.LeftKnee.x=1.25;target.RightKnee.x=1.25
  if key!="advance":
   for i in range(4):target["HorseLeg"+str(i)]=Vector3.ZERO
 if key=="advance" and not mounted:
  for leg in ["LeftLeg","RightLeg","LeftKnee","RightKnee"]:target.erase(leg)
 var aiming=kind in ["lance","bow"] and key in ["windup","critical_windup","strike","recover"] and bones.has("Weapon")
 if aiming:target.erase("Weapon")
 elif key!="strike":weapon_aim=0.0
 pose_tween=create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
 if kind=="bow":pose_tween.tween_property(self,"bow_draw",1.0 if key in ["windup","critical_windup"] else 0.0,duration)
 if kind=="bow":pose_tween.tween_property(self,"bow_hand_weight",1.0 if key in ["idle","advance","windup","critical_windup"] else 0.0,duration)
 if aiming:pose_tween.tween_property(self,"weapon_aim",1.0,duration)
 for name_value in target:
  if name_value in ["Arm","Elbow","LeftArm","LeftElbow","LeftKnee","RightKnee","Body","Head"]:
   target[name_value].x=-target[name_value].x
  if key=="down" and name_value in ["LeftLeg","RightLeg"]:target[name_value].x=-target[name_value].x
  if kind=="bow" and name_value in ["LeftArm","LeftElbow"]:
   pose_tween.tween_property(self,"drawing_arm_rotation" if name_value=="LeftArm" else "drawing_elbow_rotation",target[name_value],duration)
  elif bones.has(name_value):pose_tween.tween_property(bones[name_value],"rotation",target[name_value],duration)
 var lift=stance_height(target) if grounded_stance and key!="advance" else 0.0
 pose_tween.tween_property(self,"support_height",lift,duration)
 if grounded_stance:
  for side in ["LeftLeg","RightLeg"]:pose_tween.tween_property(bones[side],"position:y",rest[side].position.y+lift,duration)
 if bones.has("Body"):
  pose_tween.tween_property(bones.Body,"position:y",rest.Body.position.y+lift-(.43 if key=="down" and not grounded_stance else 0.0),duration)
 # Apply constraints after this frame's parallel pose writes, avoiding a frame
 # of separation between the drawing hand, nock and newly aimed weapon.
 pose_tween.tween_method(func(_progress):apply_constraints(),0.0,1.0,duration)
 return pose_tween

func socket_position(key: String) -> Vector3:
 if key=="projectile" and kind=="magic" and bones.has("RightHand"):return bones.RightHand.to_global(Vector3(0,0,-.10))
 if key=="projectile" and kind=="staff" and bones.has("Weapon"):return bones.Weapon.to_global(Vector3(0,.78,0))
 if key=="projectile" and kind=="bow" and bones.has("NockedArrow"):return bones.NockedArrow.global_position
 if key=="projectile" and bones.has("Weapon"):
  var offset=Vector3(0,0,-.22) if kind=="bow" else Vector3.ZERO
  return bones.Weapon.to_global(offset)
 return global_position+Vector3(0,(1.2 if key=="projectile" else 1.1)+(.75 if mounted else 0.0),0)

func release_projectile():
 if kind=="lance" and bones.has("Weapon"):bones.Weapon.visible=false
 elif kind=="bow" and bones.has("NockedArrow"):bones.NockedArrow.visible=false
