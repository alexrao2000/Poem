extends SceneTree
const Models=preload("res://scripts/debug_source_models.gd")
var study_key="ranger_female"
var character_id="sera"
func _initialize():call_deferred("run")
func sample(actor,key: String,fraction: float):
 for listener in actor.pose_listeners:listener.combat_pose(key)
 var mapping=actor.poses[key];actor.player.get_animation(mapping.clip).loop_mode=Animation.LOOP_NONE
 actor.player.stop();actor.player.play(mapping.clip,0);actor.player.seek(lerpf(mapping.from,mapping.to,fraction),true,true);actor.player.pause();actor.refresh_skeleton()
func draw_pad(rig: Skeleton3D) -> Vector3:
 var hand=rig.get_bone_global_pose(rig.find_bone("hand_l"));var point=Vector3.ZERO
 for name_value in ["index_04_leaf_l","middle_04_leaf_l"]:point+=hand.affine_inverse()*rig.get_bone_global_pose(rig.find_bone(name_value)).origin*.5
 return rig.get_node("DrawingHand").to_global(point)
func run():
 var models=Models.new([study_key]);var rules=load("res://scripts/rules.gd").new();var unit=rules.roster.filter(func(value):return value.id==character_id)[0].duplicate(true);unit.team="player"
 var stage=Node3D.new();root.add_child(stage);var lowest=INF;var extra_turn=0.0;var grip_gap=0.0;var count=0
 for item in ["scout_bow","recurve","longbow"]:
  unit.item=item;var actor=models.build(stage,unit,Vector3(35,0,0));assert(actor!=null and models.models.issues.is_empty());await process_frame;actor.set_process(false)
  var rig=actor.model.get_node("Rig/Armature/Skeleton3D");var hand=rig.get_node("WeaponHand");var bow=hand.get_node("Bow");var weapon=bow.get_node("Weapon");var arrow=weapon.get_node("NockedArrow");var hold=bow.arms;var fixed=bow.transform
  assert(hold.model==actor.model and hold.corners.size()==8 and hold.chain.size()==8 and actor.pose_constraints.has(hold))
  assert(actor.contact==null and actor.weapon_trail_points().is_empty() and bow.equipped==item)
  assert(actor.player.get_animation_list().size()==15,"Four private bow clips accompany the eleven retained source clips")
  assert(is_equal_approx(actor.player.get_animation("BowIdle").length,actor.player.get_animation("Idle").length),"The ready loop retains the complete source breathing cycle")
  for height in [0.0,.65]:
   actor.position.y=height;actor.rotation.y=-PI/2 if height==0 else PI/2
   for key in ["idle","advance","windup","strike","recover","hit","evade","down","victory"]:
    var previous=null;var previous_source=null;var prior_arm=[];var steps=513 if key=="down" else 17
    for step in range(steps):
     sample(actor,key,float(step)/(steps-1))
     var actual=hand.basis.get_rotation_quaternion();var source=rig.get_bone_global_pose(rig.find_bone("hand_r")).basis.get_rotation_quaternion()
     if previous!=null and key=="down":
      var extra=previous.angle_to(actual)-previous_source.angle_to(source);extra_turn=maxf(extra_turn,extra);assert(previous.angle_to(actual)<.12 and extra<.08,"Sub-frame fall sampling rules out sudden bow-wrist flips")
     previous=actual;previous_source=source
     if key=="down":
      var inputs=hold.solve();var final_arm=[]
      for bone in hold.right_chain:final_arm.append(rig.get_bone_pose_rotation(bone))
      if not prior_arm.is_empty():
       for index in range(3):assert(prior_arm[index].angle_to(final_arm[index])<.12,"Floor contact preserves elbow bend direction without a hidden shoulder or elbow snap")
      prior_arm=final_arm
      for index in range(hold.chain.size()):rig.set_bone_pose_rotation(hold.chain[index],inputs[index])
      rig.force_update_all_bone_transforms()
     var originals=[]
     for bone in range(rig.get_bone_count()):originals.append([rig.get_bone_pose_position(bone),rig.get_bone_pose_rotation(bone),rig.get_bone_pose_scale(bone)])
     var right=hand.transform;var left=rig.get_node("DrawingHand").transform;actor.refresh_skeleton()
     assert(hand.transform.is_equal_approx(right) and rig.get_node("DrawingHand").transform.is_equal_approx(left) and bow.transform==fixed,"Repeated samples retain both hand attachments and the fitted grip")
     for bone in range(rig.get_bone_count()):assert(rig.get_bone_pose_position(bone).is_equal_approx(originals[bone][0]) and rig.get_bone_pose_rotation(bone).is_equal_approx(originals[bone][1]) and rig.get_bone_pose_scale(bone).is_equal_approx(originals[bone][2]),"Both-arm solving restores source inputs without stretching or translating bones")
     for mesh in weapon.find_children("*","MeshInstance3D",true,false):
      if not mesh.is_visible_in_tree():continue
      for surface in range(mesh.mesh.get_surface_count()):
       for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
        var point=mesh.to_global(vertex);lowest=minf(lowest,point.y-height);assert(point.is_finite() and point.y>height+.01,"Actual limbs, string and arrow clear relocated floors")
     var nock=weapon.to_global(Vector3(0,0,.22+.30*bow.draw))
     for i in range(2):
      var segment=weapon.get_node("BowStringTop" if i==0 else "BowStringBottom");var tip=weapon.to_global(Vector3(0,weapon.get_meta("bow_height")*(1 if i==0 else -1),.22))
      assert(segment.to_global(Vector3.UP*.5).distance_to(tip)<.00001 and segment.to_global(Vector3.DOWN*.5).distance_to(nock)<.00001,"Both string segments meet the actual bow tips and nock throughout drawing")
     for name_value in ["index_04_leaf_r","middle_04_leaf_r","ring_04_leaf_r","pinky_04_leaf_r"]:
      var point=rig.get_bone_global_pose(rig.find_bone("hand_r")).affine_inverse()*rig.get_bone_global_pose(rig.find_bone(name_value)).origin
      var finger=hand.to_global(point);var nearest=Geometry3D.get_closest_point_to_segment(finger,weapon.to_global(Vector3(0,-.065,0)),weapon.to_global(Vector3(0,.065,0)))
      grip_gap=maxf(grip_gap,finger.distance_to(nearest));assert(finger.distance_to(nearest)<.045)
     if key=="windup" and step==steps-1:assert(draw_pad(rig).distance_to(nock)<.0001,"Actual animated left fingertips reach the drawn nock")
     count+=1
  for side in [-1,1]:
   actor.rotation.y=-side*PI/2
   for target_height in [1.1,1.85]:
    var target=actor.position+Vector3(side*4,target_height,0);actor.aim_at(target);await actor.pose("windup",.02).finished
    var nock=weapon.to_global(Vector3(0,0,.52));assert(draw_pad(rig).distance_to(nock)<.0001 and is_equal_approx(bow.draw,1) and is_equal_approx(bow.lift,1))
    assert((-arrow.global_basis.z.normalized()).dot((target-arrow.global_position).normalized())>.999999,"The actual held arrow aims at foot/mounted targets on either side")
    await actor.pose("strike",.02).finished
    assert(not arrow.visible and bow.projectile_spent and is_zero_approx(bow.draw) and is_equal_approx(bow.hand_draw,1),"Release returns the string while the drawing hand stays back and the nocked arrow disappears")
    assert(actor.socket_position("projectile").distance_to(arrow.global_position)<.00001)
    await actor.pose("recover",.02).finished;assert(not arrow.visible,"Recovery does not create another arrow before the next ready pose")
    await actor.pose("idle",.02).finished;assert(arrow.visible and not bow.projectile_spent)
  var valid=hold.aim_point;actor.aim_at(Vector3(INF,0,0));assert(hold.aim_point==valid)
  for key in ["windup","down"]:
   sample(actor,key,.7)
   for influence in [0.0,.5,1.0]:
    hold.influence=influence;actor.refresh_skeleton();var direct=[]
    for anchor in rig.find_children("*","BoneAttachment3D",true,false):direct.append(anchor.transform)
    await process_frame;await process_frame
    var anchors=rig.find_children("*","BoneAttachment3D",true,false)
    for index in range(anchors.size()):assert(anchors[index].transform.is_equal_approx(direct[index]),"Native and direct torso/head/both-arm and late-added cloak attachments agree at partial influence")
   hold.influence=1
  actor.queue_free();await process_frame
 stage.queue_free();await process_frame
 print("PASS: ",count," fitted bow poses, floor minimum ",lowest," m, fall correction excess ",extra_turn," rad, grip gap ",grip_gap," m, connected string/fingertips, two-sided aimed shots, private clips, release/recovery visibility and native/direct both-arm influence")
 quit()
