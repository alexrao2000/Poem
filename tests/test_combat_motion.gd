extends SceneTree
const Actor=preload("res://scripts/fighter_actor.gd")
const Trail=preload("res://scripts/combat_trail.gd")
const Impact=preload("res://scripts/combat_impact.gd")
const Projectile=preload("res://scripts/combat_projectile.gd")

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
 var camera=Camera3D.new();root.add_child(camera);camera.position=Vector3(4,3,7)
 var impacts=[];var normal_vertices=0
 for event in [{"damage":7,"crit":false,"hit":true},{"damage":21,"crit":true,"hit":true},{"damage":0,"crit":false,"hit":false}]:
  var effect=Impact.new();root.add_child(effect);effect.configure(Vector3(2,1,0),event,camera);impacts.append(weakref(effect))
  assert(effect.amount.text==(str(event.damage) if event.hit else "MISS"),"Impact numbers reflect the resolved event")
  if event.hit:
   var vertices=effect.burst.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
   if event.crit:assert(vertices>normal_vertices,"Critical adds angular forks to the spark burst")
   else:normal_vertices=vertices
   var direction=(camera.position-effect.plane.global_position).normalized()
   assert((-effect.plane.global_basis.z).dot(direction)>.999,"Contact burst faces the shot camera")
   assert(effect.glow.material_override.blend_mode==BaseMaterial3D.BLEND_MODE_ADD,"Glow is local and additive")
  else:assert(effect.plane==null,"Misses never show a damaging contact burst")
 await create_timer(.35).timeout
 for reference in impacts:
  var effect=reference.get_ref();assert(effect!=null and effect.amount.modulate.a>0,"Damage remains readable after the initial flash")
  if effect.glow!=null:assert(effect.glow.material_override.albedo_color.a==0,"Bright contact fades promptly")
 await create_timer(.35).timeout
 for effect in impacts:assert(effect.get_ref()==null,"Impact geometry and number release together")
 camera.queue_free()
 var fighters=load("res://scripts/fighters.gd").new();var rules=load("res://scripts/rules.gd").new()
 var stage=Node3D.new();root.add_child(stage)
 stage.position=Vector3(35,0,0)
 for weapon in ["bow","lance","magic"]:
  for direction in [-1,1]:
   var from=Vector3(35,1.2 if direction>0 else 1.95,0);var to=Vector3(35+direction*4,1.85 if direction>0 else 1.1,0)
   var shot=Projectile.new();stage.add_child(shot);shot.launch(from,to,weapon,2).kill();shot.set_process(false)
   for t in [0.0,.5,1.0]:
    shot.progress=t;shot._process(0)
    assert(shot.global_position.distance_to(shot.point_at(t))<.0001,"Projectile path uses world-space sockets beneath transformed stages")
    var tangent=to-from+Vector3.UP*cos(t*PI)*PI*shot.arc
    assert((-shot.body.global_basis.z).dot(tangent.normalized())>.999,"Arrow and spear tips follow actual flight direction")
    if t==.5:assert(shot.global_position.y>from.lerp(to,.5).y,"Ranged shot follows a restrained arc")
   assert(shot.global_position.distance_to(to)<.0001,"Projectile reaches mounted or infantry impact socket")
   if weapon=="magic":assert(shot.trail.size()==6 and shot.trail[0].visible,"Magic leaves a bounded trailing wake")
   shot.queue_free()
 var final_shot=Projectile.new();stage.add_child(final_shot);var reference=weakref(final_shot)
 await final_shot.launch(Vector3.ZERO,Vector3.RIGHT*4,"bow",.02).finished
 await process_frame;assert(reference.get_ref()==null,"Completed flight releases its meshes")
 stage.position=Vector3.ZERO
 for job in ["Ranger","Arcanist","Knight","Rider"]:
  var unit=rules.roster.filter(func(u):return u.job==job)[0].duplicate(true);unit.team="player"
  var actor=fighters.build(stage,unit,Vector3.ZERO);actor.rotation.y=-PI/2
  await actor.pose("idle",.01).finished;var resting=actor.socket_position("projectile")
  await actor.pose("throw" if unit.weapon=="lance" else "strike",.01).finished
  var release=actor.socket_position("projectile")
  assert(release.x>.3 and release.distance_to(actor.bone("Weapon").global_position)<.25,"Ranged release follows the animated weapon instead of spawning from the torso")
  assert(release.distance_to(resting)>.1,"Release socket follows pose changes")
  if job=="Rider":assert(release.y>1.8,"Mounted throw launches from the rider's hand")
  actor.release_projectile()
  assert(actor.bone("Weapon").visible==(unit.weapon!="lance"),"Thrown spear leaves the hand; bows and books stay held")
  await actor.pose("idle",.01).finished
  assert(actor.bone("Weapon").visible,"Ready stance restores a reusable thrown weapon")
  actor.queue_free()
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
 print("PASS: locomotion, mounted gait/sockets, melee contact, spear target heights, hit/miss/critical accents and effect cleanup")
 quit()
