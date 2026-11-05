extends SceneTree
const Rider=preload("res://scripts/imported_rider.gd")
func _initialize():call_deferred("run")
func run():
 var world=Node3D.new();root.add_child(world);var rules=load("res://scripts/rules.gd").new()
 for pair in [["female","una"],["male","bram"]]:
  var unit=rules.roster.filter(func(value):return value.id==pair[1])[0].duplicate(true);unit.team="player";unit.item="iron_lance"
  var models=load("res://scripts/debug_source_models.gd").new(["rider_"+pair[0]])
  var actor=models.build(world,unit,Vector3(35,.65,0));assert(actor is Rider and models.models.issues.is_empty());actor.rotation.y=.7;await actor.pose("idle",.02).finished;actor.set_process(false);actor.player.pause()
  var rig=actor.model.get_node("Rig/Armature/Skeleton3D");var arms=rig.get_node("WeaponHand/Grip").arms;var mount=actor.model.get_node("Mount");var foot_gap=0.0;var hand_gap=0.0;var floor_gap=0.0;mount.set_process(false)
  for weight in [0.0,.5,1.0]:
   for step in range(257):
    mount.gait_weight=weight;mount.set_clock(TAU*step/256.0);actor.refresh_skeleton();var original=arms.solve()
    for side in ["r","l"]:
     var ball=rig.to_global(rig.get_bone_global_pose(rig.find_bone("ball_"+side)).origin)
     var stirrup=mount.bones.Horse.get_node("RightStirrup" if side=="r" else "LeftStirrup")
     foot_gap=maxf(foot_gap,ball.distance_to(stirrup.global_position+Vector3.UP*.0275))
    for index in range(arms.chain.size()):rig.set_bone_pose_rotation(arms.chain[index],original[index])
    rig.force_update_all_bone_transforms();mount.reins.update()
    var pad=rig.get_node("ReinHand").to_global(rig.get_node("WeaponHand/Grip").rein_pad)
    for path in mount.reins.paths:hand_gap=maxf(hand_gap,mount.reins.to_global(path[-1]).distance_to(pad))
    var lowest=INF
    for index in range(4):lowest=minf(lowest,mount.bones["HorseFoot"+str(index)].to_global(Vector3(0,0,-.015)).y-.055)
    floor_gap=maxf(floor_gap,absf(lowest-actor.global_position.y))
    assert(actor.ground_contact_position().y-actor.global_position.y<.00001)
  assert(foot_gap<.0001 and hand_gap<.0121 and floor_gap<.00001)
  print("PASS: ",pair[1]," 771 mounted gait samples; toe/stirrup gap ",foot_gap," m, rein grip gap ",hand_gap," m, hoof floor gap ",floor_gap," m")
  var anchors=rig.find_children("*","BoneAttachment3D",true,false)
  for amount in [0.0,.5,1.0]:
   arms.influence=amount;actor.refresh_skeleton();var direct=anchors.map(func(anchor):return anchor.transform)
   var grip=actor.socket_position("rein_grip")
   await process_frame;await process_frame
   for index in range(anchors.size()):assert(anchors[index].transform.is_equal_approx(direct[index]),"Mounted feet, hands, armor and face agree in native/direct partial influence")
   assert(actor.socket_position("rein_grip").distance_to(grip)<.00001)
  arms.influence=1
  var contacts=[];actor.travel_contact.connect(func(index):contacts.append(index))
  await actor.pose("advance",.02).finished
  for step in range(72):
   actor.global_position-=actor.global_basis.z*(1.8/72);actor.update_locomotion()
  assert(contacts==[0,1] and absf(actor.stride_phase)<.0001,"One real ground-distance cycle emits the two alternating hoof contacts")
  assert(mount.clock<.0001 and actor.player.current_animation_position<.0001)
  var before=contacts.size();actor.advance_stride(INF);actor.advance_stride(4.0);assert(contacts.size()==before,"Non-finite travel and discontinuous relocations are not hoofbeats")
  await actor.pose("idle",.02).finished;assert(mount.gait_weight==0)
  var originals={}
  for mesh in mount.find_children("*","MeshInstance3D",true,false):originals[mesh]=mesh.get_active_material(0)
  var departure=load("res://scripts/combat_defeat.gd").new();world.add_child(departure);departure.begin(actor);departure.motion.pause();departure.apply_visibility(.5)
  for mesh in originals:
   var material=mesh.get_active_material(0);assert(material!=originals[mesh] and departure.copies[originals[mesh]]==material,"Defeat owns every horse and rein material")
   if material is ShaderMaterial:assert(is_equal_approx(material.get_shader_parameter("defeat_visibility"),.5))
   elif material is BaseMaterial3D:assert(material.albedo_color.a<originals[mesh].albedo_color.a)
  departure.finish();assert(not actor.visible);departure.queue_free()
  actor.queue_free();await process_frame
 world.queue_free();await process_frame;quit()
