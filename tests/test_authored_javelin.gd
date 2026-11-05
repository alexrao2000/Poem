extends SceneTree
const Projectile=preload("res://scripts/combat_projectile.gd")
const Vertices=preload("helpers/authored_vertices.gd")
var study_key="knight_female"
var character_id="petra"
func _initialize():call_deferred("run")
func sample(actor,key: String,fraction: float):
 for listener in actor.pose_listeners:listener.combat_pose(key)
 var mapping=actor.poses[key];actor.player.get_animation(mapping.clip).loop_mode=Animation.LOOP_NONE
 actor.player.stop();actor.player.play(mapping.clip,0);actor.player.seek(lerpf(mapping.from,mapping.to,fraction),true,true);actor.player.pause();actor.refresh_skeleton()
func run():
 var world=Node3D.new();root.add_child(world);var rules=load("res://scripts/rules.gd").new()
 var unit=rules.roster.filter(func(value):return value.id==character_id)[0].duplicate(true);unit.team="player";unit.item="javelin"
 var models=load("res://scripts/debug_source_models.gd").new([study_key]);var actor=models.build(world,unit,Vector3(35,.65,0));assert(actor!=null);await process_frame;actor.set_process(false)
 var rig=actor.model.get_node("Rig/Armature/Skeleton3D");var grip=rig.get_node("WeaponHand/Grip");var weapon=grip.get_node("Weapon");var arms=grip.arms
 var count=0;var worst_step=0.0;var launch_gap=0.0;var floor_y=INF;var cache=Vertices.prepare(actor)
 assert(actor.projectile_source()==weapon and arms.chain.size()==5)
 for side in [-1,1]:
  actor.rotation.y=-side*PI/2
  for height in [1.1,1.85]:
   for depth in [-.15,.15]:
    var destination=actor.position+Vector3(side*4,height,depth);actor.aim_at(destination)
    for key in ["throw_windup","throw","throw_recover"]:
     var previous=[]
     for step in range(129):
      sample(actor,key,step/128.0);var inputs=arms.solve();var current=[]
      for bone in arms.chain:current.append(rig.get_bone_pose_rotation(bone))
      if not previous.is_empty():
       for index in range(current.size()):
        var delta=previous[index].angle_to(current[index]);worst_step=maxf(worst_step,delta);assert(delta<.12,"Dense throw %s side %s height %s depth %s step %s bone %s delta %s"%[key,side,height,depth,step,rig.get_bone_name(arms.chain[index]),delta])
      previous=current
      for index in range(arms.chain.size()):rig.set_bone_pose_rotation(arms.chain[index],inputs[index])
      rig.force_update_all_bone_transforms()
      if step%16==0:
       var y=Vertices.minimum(actor,cache)-actor.position.y;floor_y=minf(floor_y,y);assert(y>.01,"Throwing keeps the complete armored outfit above the floor")
      count+=1
    await actor.pose("critical_throw_windup",.02).finished;assert(weapon.visible and actor.player.assigned_animation=="LanceThrowWindup")
    await actor.pose("throw",.02).finished;assert(not weapon.visible)
    for path in grip.grip_rotations:
     var bone=rig.find_bone(str(path.get_subname(0)))
     assert(rig.get_bone_pose_rotation(bone).angle_to(rig.get_bone_rest(bone).basis.get_rotation_quaternion())<.002,"Actual release opens the throwing fingers")
    for miss in [false,true]:
     var flight=Projectile.new();world.add_child(flight);flight.launch(actor.socket_position("projectile"),destination,"lance",.23,"",{},miss,actor.projectile_source()).pause()
     var copy=flight.body.get_node("HeldSpear");assert(copy.visible and not weapon.visible)
     for mesh in weapon.find_children("*","MeshInstance3D",true,false):
      var copied=copy.get_node(weapon.get_path_to(mesh))
      assert(copied.mesh==mesh.mesh and copied.material_override==mesh.material_override,"Flight retains the exact equipped geometry and private materials")
      for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
       var gap=mesh.to_global(vertex).distance_to(copied.to_global(vertex));launch_gap=maxf(launch_gap,gap);assert(gap<.0001,"All spear vertices agree at the actual handoff")
     assert(flight.origin.distance_to(weapon.get_node("TrailTip").global_position)<.00001)
     assert((flight.travel_end>1)==miss)
     for t in [0.0,.25,.5,.75,1.0,flight.travel_end]:
      flight.progress=t;flight._process(0)
      assert(copy.get_node("TrailTip").global_position.distance_to(flight.point_at(t))<.00001,"The real leading tip follows the complete hit/miss flight")
     assert(flight.point_at(1).distance_to(destination)<.00001)
     flight.queue_free();await process_frame
    await actor.pose("recover",.02).finished
    assert(actor.player.assigned_animation=="LanceThrowRecover" and not weapon.visible,"Ranged recovery keeps the hand empty and uses its separate clip")
    await actor.pose("idle",.02).finished;assert(weapon.visible)
    actor.aim_at(actor.position+Vector3(side*2.1,height,depth));await actor.pose("windup",.02).finished;await actor.pose("strike",.02).finished
    assert(actor.weapon_trail_points()[1].distance_to(actor.position+Vector3(side*2.1,height,depth))<.005,"The same javelin still thrusts at melee range")
    await actor.pose("recover",.02).finished;assert(actor.player.assigned_animation=="LanceRecover" and weapon.visible)
 var anchors=rig.find_children("*","BoneAttachment3D",true,false)
 for key in ["throw_windup","throw","throw_recover"]:
  for amount in [0.0,.5,1.0]:
   arms.influence=amount;sample(actor,key,.7);var direct=anchors.map(func(anchor):return anchor.transform);var inputs=[]
   for bone in arms.chain:inputs.append(rig.get_bone_pose_rotation(bone))
   actor.refresh_skeleton()
   for index in range(arms.chain.size()):assert(rig.get_bone_pose_rotation(arms.chain[index]).is_equal_approx(inputs[index]),"Direct sampling restores all five source rotations")
   await process_frame;await process_frame
   for index in range(anchors.size()):assert(anchors[index].transform.is_equal_approx(direct[index]),"All armor, face and cloak attachments agree with native partial influence")
 arms.influence=1;actor.aim_at(actor.position+Vector3(-4,1.1,0));await actor.pose("throw_windup",.02).finished;await actor.pose("throw",.02).finished
 var detached=Projectile.new();world.add_child(detached);detached.launch(actor.socket_position("projectile"),arms.aim_point,"lance",.23,"",{},false,weapon).pause()
 actor.queue_free();await process_frame;detached.progress=.5;detached._process(0);assert(detached.body.get_node("HeldSpear").is_visible_in_tree(),"In-flight geometry survives cleanup of its originating actor")
 detached.queue_free();world.queue_free();await process_frame
 print("PASS: ",count," dense javelin poses, joint step ",worst_step," rad, whole-outfit floor ",floor_y," m, eight actual melee/ranged targets, sixteen hit/miss snapshots within ",launch_gap," m, open-hand recovery, native attachments and independent flight cleanup")
 quit()
