extends SceneTree
const Models=preload("res://scripts/debug_source_models.gd")
const Vertices=preload("helpers/authored_vertices.gd")
func _initialize():call_deferred("run")
func run():
 var world=Node3D.new();root.add_child(world)
 var models=Models.new(["knight_female","knight_male","rider_female","rider_male"])
 var rules=load("res://scripts/rules.gd").new();var count=0;var lowest=INF;var peak_lift=0.0;var max_step=0.0
 for id in ["petra","oren","rook","una","bram","elian"]:
  var source=rules.roster.filter(func(unit):return unit.id==id)[0]
  var promotions=[""]
  promotions.append_array(rules.promotions.filter(func(value):return value.base==source.job).map(func(value):return value.id))
  for promotion in promotions:
   for item in ["pike","riders_bane","javelin"]:
    var unit=source.duplicate(true);unit.team="player";unit.promotion=promotion;unit.item=item
    var actor=models.build(world,unit,Vector3(35,.65,0));assert(actor!=null and models.models.issues.is_empty());await process_frame;actor.set_process(false)
    if actor.get("mount")!=null:actor.mount.set_process(false)
    var rig=actor.model.get_node("Rig/Armature/Skeleton3D");var grip=rig.get_node("WeaponHand/Grip");var driver=grip.arms
    assert(actor.poses.has("victory_flourish") and grip.finish==0)
    var cache=Vertices.prepare(actor).filter(func(entry):return grip.is_ancestor_of(entry[0]))
    var mapping=actor.poses.victory_flourish;var animation=actor.player.get_animation(mapping.clip);animation.loop_mode=Animation.LOOP_NONE
    for facing in [-PI/2,PI/2]:
     actor.rotation.y=facing;var previous=[];var start_hand=Vector3.ZERO
     for step in range(65):
      for listener in actor.pose_listeners:listener.combat_pose("victory_flourish")
      actor.player.play(mapping.clip,0);actor.player.seek(lerpf(mapping.from,mapping.to,step/64.0),true,true);actor.player.pause();actor.refresh_skeleton()
      var floor=Vertices.minimum(actor,cache)-actor.global_position.y;lowest=minf(lowest,floor);assert(floor>.01,"Finishing weapon stays clearly above the floor")
      var rests=[]
      for bone in range(rig.get_bone_count()):rests.append([rig.get_bone_pose_position(bone),rig.get_bone_pose_scale(bone)])
      var original=driver.solve();var hand=rig.get_bone_global_pose(driver.right_chain[0]).origin
      if step==0:start_hand=hand
      peak_lift=maxf(peak_lift,hand.distance_to(start_hand))
      var current=[]
      for bone in driver.chain:current.append(rig.get_bone_pose_rotation(bone))
      if not previous.is_empty():
       for index in range(current.size()):max_step=maxf(max_step,previous[index].angle_to(current[index]));assert(max_step<.08,"Joint discontinuity %s %s %s face %s step %s bone %s angle %s"%[id,promotion,item,facing,step,rig.get_bone_name(driver.chain[index]),max_step])
      previous=current
      for index in range(driver.chain.size()):rig.set_bone_pose_rotation(driver.chain[index],original[index])
      for bone in range(rig.get_bone_count()):assert(rig.get_bone_pose_position(bone).is_equal_approx(rests[bone][0]) and rig.get_bone_pose_scale(bone).is_equal_approx(rests[bone][1]),"Flourish never stretches or translates bones")
      assert(grip.get_node("Weapon").visible and not grip.throwing and not grip.critical_prepared,"Finishing settles a held spear and clears attack preparation")
      count+=1
     for key in ["victory","idle","windup","strike","hit","down"]:
      for listener in actor.pose_listeners:listener.combat_pose(key)
      assert(grip.finish==0,"Leaving the flourish restores ordinary equipment behavior")
    actor.queue_free();await process_frame
 assert(peak_lift>.05 and peak_lift<.09,"The actual wrist makes the intended seven-centimeter spear settle")
 world.queue_free();await process_frame
 print("PASS: ",count," lance finish samples, eighteen base/promoted outfits, three spears, both headings, weapon floor ",lowest," m, wrist movement ",peak_lift," m, maximum joint step ",max_step," rad, fixed bone lengths, continuous arm motion and reset on every other pose")
 quit()
