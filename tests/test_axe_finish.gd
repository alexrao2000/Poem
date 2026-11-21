extends SceneTree
const Models=preload("res://scripts/debug_source_models.gd")
const Vertices=preload("helpers/authored_vertices.gd")
func _initialize():call_deferred("run")
func run():
 var world=Node3D.new();root.add_child(world)
 var models=Models.new(["corsair_female","corsair_male"])
 var rules=load("res://scripts/rules.gd").new();var count=0;var lowest=INF;var peak_lift=0.0;var max_step=0.0
 for id in ["mara","dax","hale"]:
  var source=rules.roster.filter(func(unit):return unit.id==id)[0]
  var promotions=[""]
  promotions.append_array(rules.promotions.filter(func(value):return value.base==source.job).map(func(value):return value.id))
  for promotion in promotions:
   for item in ["iron_axe","hatchet","great_axe","war_hammer"]:
    var unit=source.duplicate(true);unit.team="player";unit.promotion=promotion;unit.item=item
    var actor=models.build(world,unit,Vector3(35,.65,0));assert(actor!=null and models.models.issues.is_empty());await process_frame;actor.set_process(false)
    var rig=actor.model.get_node("Rig/Armature/Skeleton3D");var driver=rig.get_node("AxeFinish");var grip=rig.get_node("WeaponHand/Grip")
    assert(actor.poses.has("victory_flourish") and not driver.active)
    var cache=Vertices.prepare(actor).filter(func(entry):return grip.is_ancestor_of(entry[0]))
    var mapping=actor.poses.victory_flourish;var animation=actor.player.get_animation(mapping.clip);animation.loop_mode=Animation.LOOP_NONE
    for facing in [-PI/2,PI/2]:
     actor.rotation.y=facing;var previous=[];var start_hand=Vector3.ZERO
     for step in range(65):
      for listener in actor.pose_listeners:listener.combat_pose("victory_flourish")
      actor.player.play(mapping.clip,0);actor.player.seek(lerpf(mapping.from,mapping.to,step/64.0),true,true);actor.player.pause();actor.refresh_skeleton()
      var floor=Vertices.minimum(actor,cache)-actor.global_position.y;lowest=minf(lowest,floor);assert(floor>.1,"Finishing weapon stays clearly above the floor")
      var rests=[]
      for bone in range(rig.get_bone_count()):rests.append([rig.get_bone_pose_position(bone),rig.get_bone_pose_scale(bone)])
      var original=driver.solve();var hand=rig.get_bone_global_pose(driver.chain[0]).origin
      if step==0:start_hand=hand
      peak_lift=maxf(peak_lift,hand.y-start_hand.y)
      var current=[]
      for bone in driver.chain:current.append(rig.get_bone_pose_rotation(bone))
      if not previous.is_empty():
       for index in range(current.size()):max_step=maxf(max_step,previous[index].angle_to(current[index]));assert(max_step<.08,"Small finishing gesture has continuous sampled joint rotations")
      previous=current
      for index in range(driver.chain.size()):rig.set_bone_pose_rotation(driver.chain[index],original[index])
      for bone in range(rig.get_bone_count()):assert(rig.get_bone_pose_position(bone).is_equal_approx(rests[bone][0]) and rig.get_bone_pose_scale(bone).is_equal_approx(rests[bone][1]),"Flourish never stretches or translates bones")
      count+=1
     for key in ["idle","windup","strike","hit","down","victory"]:
      for listener in actor.pose_listeners:listener.combat_pose(key)
      assert(not driver.active and driver.lift==0,"Leaving the flourish restores ordinary equipment behavior")
    actor.queue_free();await process_frame
 assert(peak_lift>.085 and peak_lift<.12,"The actual wrist makes the intended restrained weapon settle")
 var incomplete=models.models.scene_cache.values()[0].instantiate()
 var incomplete_player=incomplete.get_node("Rig/AnimationPlayer")
 var private_library=incomplete_player.get_animation_library("").duplicate(true)
 incomplete_player.remove_animation_library("");incomplete_player.add_animation_library("",private_library);private_library.remove_animation("Idle")
 assert(incomplete.get_node("Rig/Armature/Skeleton3D/WeaponHand/Grip").configure_animations(incomplete_player)=="The axe rig needs its idle clip","Missing finishing source returns a normal catalog error instead of a script failure")
 incomplete.free()
 world.queue_free();await process_frame
 print("PASS: ",count," axe finish samples, nine base/promoted outfits, four axes/hammers, both headings, weapon floor ",lowest," m, wrist lift ",peak_lift," m, fixed bone lengths, continuous arm motion and reset on every other pose")
 quit()
