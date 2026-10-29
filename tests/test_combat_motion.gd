extends SceneTree
const Actor=preload("res://scripts/fighter_actor.gd")
const Trail=preload("res://scripts/combat_trail.gd")

func _initialize():call_deferred("run")

func make_actor(mounted=false):
 var actor=Actor.new();root.add_child(actor);actor.mounted=mounted;actor.set_process(false)
 for key in ["Body","Head","Arm","Elbow","LeftArm","LeftElbow","LeftLeg","RightLeg","LeftKnee","RightKnee","HorseLeg0","HorseLeg1","HorseLeg2","HorseLeg3"]:
  var joint=Node3D.new();actor.add_child(joint);actor.register_bone(key,joint)
 return actor

func run():
 var walker=make_actor()
 var advance=walker.pose("advance",.04)
 walker._process(.07)
 var gait=walker.bone("LeftLeg").rotation.x
 assert(absf(gait)>.2,"Approach has an actual stride")
 await advance.finished
 assert(is_equal_approx(walker.bone("LeftLeg").rotation.x,gait),"Pose tween cannot overwrite locomotion joints")
 await walker.pose("idle",.01).finished
 assert(is_equal_approx(walker.bone("LeftLeg").rotation.x,-.14),"Idle owns legs after locomotion ends")
 await walker.pose("windup",.01).finished
 var sword_windup=walker.bone("Arm").rotation
 walker.kind="axe";await walker.pose("windup",.01).finished
 assert(not walker.bone("Arm").rotation.is_equal_approx(sword_windup),"Axes have distinct overhead preparation")
 var rider=make_actor(true)
 await rider.pose("advance",.01).finished;rider._process(.09)
 assert(absf(rider.bone("HorseLeg0").rotation.x)>.2,"Horse advances with a gait")
 await rider.pose("idle",.01).finished
 for i in range(4):assert(rider.bone("HorseLeg"+str(i)).rotation.is_zero_approx(),"Horse returns to a standing pose")
 assert(is_equal_approx(rider.bone("LeftLeg").rotation.x,.85),"Rider remains seated")
 assert(is_equal_approx(rider.bone("RightKnee").rotation.x,-1.25),"Seated knees bend backward")
 assert(is_equal_approx(rider.socket_position("impact").y-walker.socket_position("impact").y,.75),"Mounted impacts follow the rider")
 assert(is_equal_approx(rider.socket_position("projectile").y-walker.socket_position("projectile").y,.75),"Mounted projectile launch follows the rider")
 var trails=[]
 for weapon in ["sword","lance","axe"]:
  for direction in [-1.0,1.0]:
   var trail=Trail.new();root.add_child(trail);trail.start(Vector3.ZERO,weapon,direction,true);trails.append(weakref(trail))
   var mesh=trail.get_node("Stroke").mesh
   assert(mesh.get_surface_count()==1 and mesh.get_aabb().size.x>.5,"Every weapon produces a visible stroke")
 await create_timer(.3).timeout
 for trail in trails:assert(trail.get_ref()==null,"Transient strokes release their nodes")
 var fighters=load("res://scripts/fighters.gd").new();var rules=load("res://scripts/rules.gd").new()
 var stage=Node3D.new();root.add_child(stage)
 for job in ["Vanguard","Knight","Corsair","Duelist","Rider"]:
  var unit=rules.roster.filter(func(u):return u.job==job)[0].duplicate(true);unit.team="player"
  var actor=fighters.build(stage,unit,Vector3.ZERO);actor.rotation.y=-PI/2
  var target=Vector3(Actor.melee_spacing(unit.weapon),1.1,0);actor.aim_at(target)
  await actor.pose("windup",.01).finished;await actor.pose("strike",.01).finished;actor._process(0)
  var tip=Vector3(0,0,-1.62 if unit.weapon=="lance" else -.97 if unit.weapon=="axe" else -1.075)
  var contact=actor.bone("Weapon").to_global(tip)
  assert(contact.distance_to(target)<.45,"Melee weapon reaches the opponent's torso rather than passing above it")
  if unit.weapon=="lance":
   actor.aim_at(Vector3(target.x,1.85,0));actor._process(0)
   assert(actor.bone("Weapon").to_global(tip).distance_to(Vector3(target.x,1.85,0))<.25,"Spear grip tracks mounted as well as infantry targets")
  actor.queue_free()
 stage.queue_free()
 walker.queue_free();rider.queue_free();await process_frame
 print("PASS: locomotion, mounted gait/sockets, actual melee contact, spear target heights and trail cleanup")
 quit()
