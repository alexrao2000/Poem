extends SceneTree
const Vertices=preload("helpers/authored_vertices.gd")
const LanceFit=preload("res://tests/test_lance_anticipation.gd")
var character_ids=["petra","oren","rook"]
var study_ids=["knight_female","knight_male"]
func _initialize():call_deferred("run")
func sample(actor,key,fraction):
 for listener in actor.pose_listeners:listener.combat_pose(key)
 var mapping=actor.poses[key]
 actor.player.get_animation(mapping.clip).loop_mode=Animation.LOOP_NONE
 actor.player.play(mapping.clip,0);actor.player.seek(lerpf(mapping.from,mapping.to,fraction),true,true);actor.player.pause();actor.refresh_skeleton()
func run():
 var world=Node3D.new();root.add_child(world);var rules=load("res://scripts/rules.gd").new();var models=load("res://scripts/debug_source_models.gd").new(study_ids)
 var samples=0;var minimum=INF;var max_step=0.0;var min_swing=INF;var max_gap=0.0
 for id in character_ids:
  var source=rules.roster.filter(func(unit):return unit.id==id)[0];var promotions=[""]
  promotions.append_array(rules.promotions.filter(func(path):return path.base==source.job).map(func(path):return path.id))
  for promotion in promotions:
   var unit=source.duplicate(true);unit.team="player";unit.item="javelin";unit.promotion=promotion
   var actor=models.build(world,unit,Vector3.ZERO);assert(actor!=null and models.models.issues.is_empty());await process_frame;actor.set_process(false)
   if actor.get("mount")!=null:actor.mount.set_process(false)
   var rig=actor.model.get_node("Rig/Armature/Skeleton3D");var grip=rig.get_node("WeaponHand/Grip");var arms=grip.arms
   var weapon=grip.get_node("Weapon");var geometry=Vertices.prepare(actor)
   var seating=[]
   if actor.get("mount")!=null:
    var costume=actor.model.get_node("Identity").promotion;var outfit=[]
    if costume!=null:
     outfit.append_array(costume.panels)
     for anchor in costume.anchors:outfit.append_array(anchor.find_children("*","MeshInstance3D",true,false))
    seating=geometry.filter(func(entry):return "Peasant" in str(entry[0].name) or str(entry[0].name) in ["Cuirass","Pauldron","ElbowGuard"] or entry[0] in outfit)
   for side in [-1,1]:
    actor.rotation.y=-side*PI/2
    for height in [1.1,1.85]:
     actor.aim_at(Vector3(side*4,height,0))
     sample(actor,"throw_windup",1);var ordinary=actor.socket_position("projectile")
     sample(actor,"throw",1);var launch=weapon.global_transform
     sample(actor,"critical_throw_windup",1);var swing=actor.socket_position("projectile").distance_to(ordinary);min_swing=minf(min_swing,swing)
     assert(grip.critical_throw_prepared and not grip.critical_prepared and swing>.08,"Critical javelin preparation has a distinct backswing without arming melee critical state")
     for key in ["critical_throw_windup","throw","throw_recover"]:
      var previous=[]
      for step in range(129):
       sample(actor,key,step/128.0)
       var bones=[]
       for bone in range(rig.get_bone_count()):bones.append([rig.get_bone_pose_position(bone),rig.get_bone_pose_scale(bone)])
       var input=arms.solve();var rotations=[]
       for bone in arms.chain:rotations.append(rig.get_bone_pose_rotation(bone))
       if not previous.is_empty():
        for i in range(rotations.size()):
         var delta=rotations[i].angle_to(previous[i]);max_step=maxf(max_step,delta)
         assert(delta<.12,"Critical throw stays continuous: %s %s %s step %s bone %s delta %s"%[id,promotion,key,step,rig.get_bone_name(arms.chain[i]),delta])
       previous=rotations
       if not seating.is_empty() and side==1 and height==1.1 and step%32==0:LanceFit.check_seating(actor,rig,seating)
       for bone in range(rig.get_bone_count()):assert(rig.get_bone_pose_position(bone)==bones[bone][0] and rig.get_bone_pose_scale(bone)==bones[bone][1],"Critical throwing retains bone lengths and scales")
       for i in range(arms.chain.size()):rig.set_bone_pose_rotation(arms.chain[i],input[i])
       rig.force_update_all_bone_transforms()
       if step%16==0:
        var lowest=Vertices.minimum(actor,geometry);minimum=minf(minimum,lowest);assert(lowest>(-.005 if actor.get("mount")!=null else .005),"Complete critical throwing outfit stays above the floor")
       samples+=1
      if key=="throw":
       var gap=weapon.global_transform.origin.distance_to(launch.origin);max_gap=maxf(max_gap,gap)
       assert(gap<.0001 and weapon.global_basis.is_equal_approx(launch.basis),"Critical release returns to the exact ordinary weapon position and orientation")
     for key in ["idle","windup","critical_windup","recover","hit","critical_hit","down","guard","throw_windup"]:
      grip.combat_pose("critical_throw_windup");grip.combat_pose(key);assert(not grip.critical_throw_prepared,"Other actions clear critical ranged preparation")
   actor.queue_free();await process_frame
 world.queue_free();await process_frame
 print("PASS: ",samples," critical javelin samples across nine base/promoted outfits, two directions/heights, minimum backswing ",min_swing," m, whole-outfit floor ",minimum," m, joint step ",max_step," rad and ordinary-release gap ",max_gap," m");quit()
