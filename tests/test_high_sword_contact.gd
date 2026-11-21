extends SceneTree
# Revised mounted chests reach above the original 1.85 m contact fixtures.
const Models=preload("res://scripts/combat_models.gd")
const Rules=preload("res://scripts/rules.gd")
var pairs=[["vanguard","lyra"],["vanguard_male","cassian"]]
var items=["iron_sword","dueling_sword","tempered_sword"]
func _initialize():call_deferred("run")
func run():
 var stage=Node3D.new();root.add_child(stage);var game=Rules.new();var studies=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json"))
 var enemy=game.roster.filter(func(unit):return unit.id=="bram")[0].duplicate(true);enemy.team="enemy";enemy.id="target";enemy.item="iron_lance"
 var enemy_spec=studies.enemy_rider.duplicate(true);enemy_spec.appearance="Identity";var enemy_models=Models.new("");enemy_models.catalog={"characters":{enemy.id:enemy_spec}}
 var rider=enemy_models.build(stage,enemy,Vector3.ZERO);await process_frame
 var count=0;var largest_gap=0.0;var largest_step=0.0
 for pair in pairs:
  var unit=game.roster.filter(func(value):return value.id==pair[1])[0].duplicate(true);unit.team="player"
  for item in items:
   unit.item=item;var models=Models.new("");models.catalog={"characters":{unit.id:studies[pair[0]]}}
   var actor=models.build(stage,unit,Vector3(35,.6,0));await process_frame
   var spacing=actor.approach_spacing(unit.item)
   var contact=actor.contact;var rig=contact.rig;assert(contact.chain.size()==4)
   var positions=[];var scales=[]
   for bone in contact.chain:positions.append(rig.get_bone_pose_position(bone));scales.append(rig.get_bone_pose_scale(bone))
   for side in [-1,1]:
    actor.rotation.y=-side*PI/2;rider.rotation.y=side*PI/2;rider.position=actor.position+Vector3(side*spacing,0,0);rider.refresh_skeleton()
    var target_pose=rider.poses.idle;rider.player.stop();rider.player.play(target_pose.clip,0);rider.player.pause()
    actor.aim_at(rider.socket_position("impact"));await actor.pose("strike",.02).finished
    var previous=[]
    for step in range(33):
     rider.player.seek(lerpf(target_pose.from,target_pose.to,step/32.0),true,true);rider.player.pause();rider.refresh_skeleton()
     var target=rider.socket_position("impact");actor.aim_at(target);actor.refresh_skeleton()
     var edge=actor.weapon_trail_points();var gap=target.distance_to(Geometry3D.get_closest_point_to_segment(target,edge[0],edge[1]));largest_gap=maxf(gap,largest_gap)
     assert(gap<.006,str([pair,item,side,step,gap]))
     var original=contact.solve();var current=[]
     for index in range(contact.chain.size()):
      var bone=contact.chain[index];current.append(rig.get_bone_pose_rotation(bone))
      assert(original[index].angle_to(current[index])<=contact.LIMITS[index]+.0001)
      assert(rig.get_bone_pose_position(bone)==positions[index] and rig.get_bone_pose_scale(bone)==scales[index])
      if not previous.is_empty():largest_step=maxf(largest_step,previous[index].angle_to(current[index]))
     for index in range(contact.chain.size()):rig.set_bone_pose_rotation(contact.chain[index],original[index])
     previous=current;count+=1
    var direct=actor.weapon_trail_points();await process_frame;await process_frame
    assert(actor.weapon_trail_points()[1].distance_to(direct[1])<.001,"Native and direct corrections agree")
   actor.queue_free();await process_frame
 assert(largest_step<.12,"Small changes in mounted target height keep the reach continuous")
 stage.queue_free();await process_frame
 print("PASS: ",count," elevated slash targets, both bodies/directions, ",items.size()," weapons, fixed bone lengths/scales, bounded chest correction, native/direct agreement; gap ",largest_gap," m and step ",largest_step," rad")
 quit()
