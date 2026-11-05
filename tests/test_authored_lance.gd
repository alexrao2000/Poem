extends SceneTree
var study_key="knight_female"
var character_id="petra"
func _initialize():call_deferred("run")
func sample(actor,key: String,fraction: float):
 for listener in actor.pose_listeners:listener.combat_pose(key)
 var mapping=actor.poses[key];actor.player.get_animation(mapping.clip).loop_mode=Animation.LOOP_NONE
 actor.player.stop();actor.player.play(mapping.clip,0);actor.player.seek(lerpf(mapping.from,mapping.to,fraction),true,true);actor.player.pause();actor.refresh_skeleton()
func run():
 var models=load("res://scripts/debug_source_models.gd").new([study_key]);var game=load("res://scripts/rules.gd").new();var unit=game.roster.filter(func(value):return value.id==character_id)[0].duplicate(true);unit.team="player"
 var world=Node3D.new();root.add_child(world);var count=0;var lowest=INF;var worst_gap=0.0;var worst_step=0.0;var grip_gap=0.0
 for item in ["iron_lance","light_lance","pike","riders_bane"]:
  unit.item=item;var actor=models.build(world,unit,Vector3(35,.65,0));assert(actor!=null and models.models.issues.is_empty());await process_frame;actor.set_process(false)
  var rig=actor.model.get_node("Rig/Armature/Skeleton3D");var hand=rig.get_node("WeaponHand");var grip=hand.get_node("Grip");var weapon=grip.get_node("Weapon");var arms=grip.arms;var fixed=grip.transform
  assert(arms.model==actor.model and arms.chain.size()==5 and actor.contact==null and grip.equipped==item)
  assert(actor.player.get_animation_list().size()==18 and is_equal_approx(actor.player.get_animation("LanceIdle").length,2.5))
  for key in ["idle","advance","windup","strike","recover","hit","evade","down","victory"]:
   var steps=513 if key=="down" else 17;var previous=[]
   for step in range(steps):
    sample(actor,key,float(step)/(steps-1));var inputs=arms.solve();var current=[]
    for bone in arms.chain:current.append(rig.get_bone_pose_rotation(bone))
    if key=="down" and not previous.is_empty():
     for index in range(3):
      var delta=previous[index].angle_to(current[index]);worst_step=maxf(worst_step,delta);assert(delta<.12,"Dense fall poses preserve smooth wrist, elbow and shoulder rotation")
    previous=current
    for index in range(arms.chain.size()):rig.set_bone_pose_rotation(arms.chain[index],inputs[index])
    rig.force_update_all_bone_transforms()
    var originals=[]
    for bone in range(rig.get_bone_count()):originals.append([rig.get_bone_pose_position(bone),rig.get_bone_pose_rotation(bone),rig.get_bone_pose_scale(bone)])
    var before=hand.transform;actor.refresh_skeleton();assert(hand.transform.is_equal_approx(before) and grip.transform==fixed)
    for bone in range(rig.get_bone_count()):assert(rig.get_bone_pose_position(bone).is_equal_approx(originals[bone][0]) and rig.get_bone_pose_rotation(bone).is_equal_approx(originals[bone][1]) and rig.get_bone_pose_scale(bone).is_equal_approx(originals[bone][2]))
    for mesh in weapon.find_children("*","MeshInstance3D",true,false):
     for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
      var y=mesh.to_global(vertex).y-actor.position.y;lowest=minf(lowest,y);assert(y>.01,"Fitted spear, head and lugs stay above the floor")
    for name_value in ["index_04_leaf_r","middle_04_leaf_r","ring_04_leaf_r","pinky_04_leaf_r"]:
     var local=rig.get_bone_global_pose(rig.find_bone("hand_r")).affine_inverse()*rig.get_bone_global_pose(rig.find_bone(name_value)).origin
     var finger=hand.to_global(local);var shaft=weapon.get_node("LanceShaft");var closest=Geometry3D.get_closest_point_to_segment(finger,shaft.to_global(Vector3.UP*.9),shaft.to_global(Vector3.DOWN*.9))
     grip_gap=maxf(grip_gap,finger.distance_to(closest));assert(finger.distance_to(closest)<.045,"Original fingers remain wrapped around the shifted shaft grip")
    count+=1
  for side in [-1,1]:
   actor.rotation.y=-side*PI/2
   for height in [1.1,1.85]:
    for depth in [-.12,.12]:
     var point=actor.position+Vector3(side*2.1,height,depth);actor.aim_at(point);await actor.pose("windup",.02).finished;await actor.pose("strike",.02).finished
     var gap=actor.weapon_trail_points()[1].distance_to(point);worst_gap=maxf(worst_gap,gap);assert(gap<.005,"Every lance tip reaches actual standing/mounted and off-axis shield targets on either side")
     await actor.pose("recover",.02).finished;assert(weapon.visible)
  var target=arms.aim_point;actor.aim_at(Vector3(INF,0,0));assert(arms.aim_point==target);actor.clear_aim();assert(not arms.has_aim)
  var clips={}
  for key in actor.player.get_animation_list():clips[key]=actor.player.get_animation(key).get_track_count()
  assert(grip.configure_animations(actor.player).is_empty())
  for key in clips:assert(actor.player.get_animation(key).get_track_count()==clips[key],"Private clip setup is repeatable without accumulating tracks")
  actor.queue_free();await process_frame
 world.queue_free();await process_frame
 print("PASS: ",count," four-lance grip/floor poses, floor minimum ",lowest," m, finger gap ",grip_gap," m, maximum fall joint step ",worst_step," rad, eight two-sided foot/mounted/shield targets per item with tip error ",worst_gap," m, input restoration, private repeatable clips and private animation isolation")
 quit()
