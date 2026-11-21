extends SceneTree
const BowFit=preload("res://tests/test_authored_bow.gd")
var critical=true
func _initialize():call_deferred("run")
func sample(actor,key,fraction):
 for listener in actor.pose_listeners:listener.combat_pose(key)
 var mapping=actor.poses[key];actor.player.get_animation(mapping.clip).loop_mode=Animation.LOOP_NONE
 actor.player.play(mapping.clip,0);actor.player.seek(lerpf(mapping.from,mapping.to,fraction),true,true);actor.player.pause();actor.refresh_skeleton()
func run():
 var world=Node3D.new();root.add_child(world);var rules=load("res://scripts/rules.gd").new();var models=load("res://scripts/debug_source_models.gd").new(["ranger_female","ranger_male"])
 var count=0;var lowest=INF;var finger_gap=0.0;var worst_step=0.0
 for id in ["sera","ari","faye"]:
  var source=rules.roster.filter(func(value):return value.id==id)[0]
  for promotion in ["","sharpshooter","pathfinder"]:
   for item in ["scout_bow","recurve","longbow"]:
    var unit=source.duplicate(true);unit.team="player";unit.promotion=promotion;unit.item=item
    var actor=models.build(world,unit,Vector3.ZERO);assert(actor!=null and models.models.issues.is_empty());await process_frame;actor.set_process(false)
    var rig=actor.model.get_node("Rig/Armature/Skeleton3D");var bow=rig.get_node("WeaponHand/Bow");var weapon=bow.get_node("Weapon");var arrow=weapon.get_node("NockedArrow");var arms=bow.arms
    for side in [-1,1]:
     actor.rotation.y=-side*PI/2
     for height in [1.1,1.85]:
      var target=Vector3(side*4,height,0);actor.aim_at(target)
      for key in ["critical_windup" if critical else "windup","strike","recover"]:
       var previous=[]
       for step in range(129):
        sample(actor,key,step/128.0);var original=arms.solve();var rotations=[]
        for bone in arms.chain:rotations.append(rig.get_bone_pose_rotation(bone))
        if not previous.is_empty():
         for index in range(rotations.size()):
          var angle=previous[index].angle_to(rotations[index]);worst_step=maxf(worst_step,angle);assert(angle<.13,"Critical joint continuity: %s %s %s height %s %s step %s %s angle %s"%[id,promotion,item,height,key,step,rig.get_bone_name(arms.chain[index]),angle])
        previous=rotations
        for index in range(arms.chain.size()):rig.set_bone_pose_rotation(arms.chain[index],original[index])
        rig.force_update_all_bone_transforms()
        var nock=weapon.to_global(Vector3(0,0,.22+(.36 if critical else .30)*bow.draw))
        for index in range(2):
         var string=weapon.get_node("BowStringTop" if index==0 else "BowStringBottom")
         assert(string.to_global(Vector3.DOWN*.5).distance_to(nock)<.00001,"Critical string segments meet the deeper nock")
        if key in ["windup","critical_windup"] and step==128:
         var gap=BowFit.draw_pad(rig).distance_to(nock);finger_gap=maxf(finger_gap,gap);assert(gap<.001,"Critical drawing fingertips remain on the string: "+str(gap))
         assert((-arrow.global_basis.z.normalized()).dot((target-arrow.global_position).normalized())>.999999,"The drawn arrow points at the actual elevated target")
        for mesh in weapon.find_children("*","MeshInstance3D",true,false):
         if not mesh.is_visible_in_tree():continue
         for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
          var y=mesh.to_global(vertex).y;lowest=minf(lowest,y);assert(y>.01)
        count+=1
       if key=="strike":
        bow.pose_finished("strike");assert(bow.projectile_spent and not arrow.visible and is_zero_approx(bow.draw) and is_equal_approx(bow.hand_draw,1))
      sample(actor,"idle",1);assert(not bow.critical_prepared and arrow.visible and not bow.projectile_spent)
      sample(actor,"windup",1);assert(is_equal_approx(bow.draw_length(),.30),"Ordinary shots restore their original draw")
      actor.clear_aim();assert(not arms.has_aim)
    actor.queue_free();await process_frame
 world.queue_free();await process_frame
 print("PASS: ",count," critical" if critical else " ordinary", " bow draw/release/recovery samples, nine outfits, three bows, both directions/heights, connected fingertips gap ",finger_gap," m, floor ",lowest," m, maximum joint step ",worst_step," rad, aimed arrows, ordinary reset and clear aim")
 quit()
