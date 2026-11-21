extends SceneTree
const Models=preload("res://scripts/combat_models.gd")
const Rules=preload("res://scripts/rules.gd")
var pairs=[["female","nell"],["male","silas"]]
var finger_gap=0.0
func _initialize():call_deferred("run")
func sample(actor,key: String,fraction: float):
 for listener in actor.pose_listeners:listener.combat_pose(key)
 var mapping=actor.poses[key];actor.player.stop();actor.player.play(mapping.clip,0);actor.player.seek(lerpf(mapping.from,mapping.to,fraction),true,true);actor.player.pause();actor.refresh_skeleton()
 var rig=actor.model.get_node("Rig/Armature/Skeleton3D");var grip=rig.get_node("WeaponHand/Grip");var arm=grip.thrust_arm
 var original=arm.solve();var weapon=grip.get_node("Weapon")
 var a=weapon.to_global(Vector3(0,0,-.195));var b=weapon.to_global(Vector3(0,0,.035))
 for digit in ["thumb","index","middle","ring","pinky"]:
  var point=rig.to_global(rig.get_bone_global_pose(rig.find_bone(digit+"_04_leaf_r")).origin)
  var gap=point.distance_to(Geometry3D.get_closest_point_to_segment(point,a,b));finger_gap=maxf(finger_gap,gap)
  assert(gap<.045,"Estoc fingertips retain their actual hilt fit through every fitted pose")
 for index in range(arm.chain.size()):rig.set_bone_pose_rotation(arm.chain[index],original[index])
func run():
 var world=Node3D.new();root.add_child(world);var rules=Rules.new();var studies=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json"));var contacts=0;var lowest=INF;var worst_turn=0.0;var worst_gap=0.0
 for pair in pairs:
  var spec=studies[pair[0]].duplicate(true);spec.appearance="Identity"
  var unit=rules.roster.filter(func(value):return value.id==pair[1])[0].duplicate(true);unit.team="player";unit.item="estoc"
  var source=load(spec.scene).instantiate();var shared=source.get_node(NodePath(spec.player)).get_animation("Sword_Attack");var source_tracks=shared.get_track_count()
  var models=Models.new("");models.catalog={"characters":{unit.id:spec}}
  var actor=models.build(world,unit,Vector3(35,.65,0));assert(actor!=null and models.issues.is_empty(),str(models.issues));await process_frame;actor.set_process(false)
  var rig=actor.model.get_node("Rig/Armature/Skeleton3D");var grip=rig.get_node("WeaponHand/Grip");var arm=grip.thrust_arm
  assert(actor.contact==null and arm!=null and actor.pose_constraints.has(arm) and actor.pose_listeners.has(arm))
  var fixed=grip.transform;var weapon=grip.get_node("Weapon");var meshes=weapon.find_children("*","MeshInstance3D",true,false)
  var original_positions=[];var original_scales=[]
  for bone in range(rig.get_bone_count()):original_positions.append(rig.get_bone_pose_position(bone));original_scales.append(rig.get_bone_pose_scale(bone))
  for side in [-1,1]:
   actor.rotation.y=-side*PI/2
   for height in [1.0,1.1,1.35,1.65,1.85]:
    var target=actor.global_position+Vector3(side*1.4,height,.12);actor.aim_at(target)
    var prior=null
    for key in ["windup","strike","recover"]:
     for step in range(65):
      sample(actor,key,step/64.0);var original=arm.solve();var pose=[]
      for bone in arm.chain:pose.append(rig.get_bone_pose_rotation(bone))
      if prior!=null:
       for index in range(pose.size()):worst_turn=maxf(worst_turn,pose[index].angle_to(prior[index]))
      prior=pose
      for index in range(arm.chain.size()):rig.set_bone_pose_rotation(arm.chain[index],original[index])
      rig.force_update_all_bone_transforms()
      assert(grip.transform==fixed)
      if key=="strike" and step==64:
       var edge=PackedVector3Array([actor.sockets.trail_inner.global_position,actor.sockets.trail_tip.global_position]);var trail=actor.weapon_trail_points();assert(is_equal_approx(trail[0].distance_to(trail[1]),.032) and ((trail[0]+trail[1])*.5).distance_to(edge[1])<.00001);var gap=edge[1].distance_to(target);worst_gap=maxf(worst_gap,gap)
       assert(gap<.006,"Estoc tip reaches the actual target: %s %s gap %s"%[pair,height,gap])
       assert((edge[1]-edge[0]).normalized().dot((target-rig.get_node("WeaponHand").global_position).normalized())>.98,"Thrust arrives point first")
       contacts+=1
    actor.clear_aim()
   for key in ["idle","advance","hit","evade","guard","down","victory"]:
    for step in range(129 if key=="down" else 17):
     sample(actor,key,step/(128.0 if key=="down" else 16.0))
     for mesh in meshes:
      for surface in range(mesh.mesh.get_surface_count()):
       for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
        var height=mesh.to_global(vertex).y-actor.global_position.y;lowest=minf(lowest,height)
        assert(height>.01,"Estoc clears the relocated floor in reactions and defeat: %s %s %s"%[pair,key,height])
  assert(worst_turn<.12,"Dense thrust transitions keep the arm continuous: "+str(worst_turn))
  actor.aim_at(actor.global_position+Vector3(0,1.1,-1.4));sample(actor,"strike",1)
  for amount in [0.0,.5,1.0]:
   arm.influence=amount;actor.refresh_skeleton();var anchors=rig.find_children("*","BoneAttachment3D",true,false);var direct=anchors.map(func(anchor):return anchor.transform)
   await process_frame;await process_frame
   for index in range(anchors.size()):assert(anchors[index].transform.is_equal_approx(direct[index]),"Native/direct estoc poses agree on every attachment")
  arm.influence=1
  assert(shared.get_track_count()==source_tracks and actor.player.get_animation("Sword_Attack")!=shared,"The source attack remains shared and unchanged")
  assert(actor.player.get_animation("Sword_Attack").find_track(NodePath("Armature/Skeleton3D/EstocArm:thrust"),Animation.TYPE_VALUE)>=0)
  for bone in arm.chain:assert(rig.get_bone_pose_position(bone).is_equal_approx(original_positions[bone]) and rig.get_bone_pose_scale(bone).is_equal_approx(original_scales[bone]))
  actor.queue_free();source.free();await process_frame
 world.queue_free();await process_frame
 print("PASS: ",contacts," fitted estoc tips, both bodies/facings and five target heights, dense preparation/thrust/recovery, fingertip gap ",finger_gap," m, fixed grip/bone lengths, reaction/fall clearance ",lowest," m, maximum joint turn ",worst_turn," rad, tip gap ",worst_gap," m, private clips and native/direct attachment agreement")
 quit()
