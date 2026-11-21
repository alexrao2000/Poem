extends SceneTree
const Vertices=preload("helpers/authored_vertices.gd")
const RiderFit=preload("res://tests/test_authored_rider.gd")
var character_ids=["petra","oren","rook"]
var study_ids=["knight_female","knight_male"]
func _initialize():call_deferred("run")
func sample(actor,key,fraction):
 for listener in actor.pose_listeners:listener.combat_pose(key)
 var mapping=actor.poses[key];actor.player.get_animation(mapping.clip).loop_mode=Animation.LOOP_NONE
 actor.player.play(mapping.clip,0);actor.player.seek(lerpf(mapping.from,mapping.to,fraction),true,true);actor.player.pause();actor.refresh_skeleton()
func run():
 var world=Node3D.new();root.add_child(world);var rules=load("res://scripts/rules.gd").new();var models=load("res://scripts/debug_source_models.gd").new(study_ids)
 var count=0;var gap=0.0;var minimum=INF;var continuity=0.0;var smallest_draw=INF
 for id in character_ids:
  var source=rules.roster.filter(func(value):return value.id==id)[0];var promotions=[""]
  promotions.append_array(rules.promotions.filter(func(value):return value.base==source.job).map(func(value):return value.id))
  for promotion in promotions:
   for item in ["iron_lance","light_lance","pike","riders_bane"]:
    var unit=source.duplicate(true);unit.team="player";unit.promotion=promotion;unit.item=item
    var actor=models.build(world,unit,Vector3.ZERO);assert(actor!=null and models.models.issues.is_empty());await process_frame;actor.set_process(false)
    if actor.get("mount")!=null:actor.mount.set_process(false)
    var rig=actor.model.get_node("Rig/Armature/Skeleton3D");var grip=rig.get_node("WeaponHand/Grip");var arms=grip.arms;var weapon=grip.get_node("Weapon")
    var seating=[]
    if actor.get("mount")!=null:
     var costume=actor.model.get_node("Identity").promotion;var outfit=[]
     if costume!=null:
      outfit.append_array(costume.panels)
      for anchor in costume.anchors:outfit.append_array(anchor.find_children("*","MeshInstance3D",true,false))
     seating=Vertices.prepare(actor).filter(func(entry):return "Peasant" in str(entry[0].name) or str(entry[0].name) in ["Cuirass","Pauldron","ElbowGuard"] or entry[0] in outfit)
    for side in [-1,1]:
     actor.rotation.y=-side*PI/2
     for height in [1.1,1.85]:
      var target=Vector3(side*2.1,height,0);actor.aim_at(target)
      sample(actor,"windup",1);var ordinary_tip=actor.sockets.trail_tip.global_position
      sample(actor,"critical_windup",1);var drawn=ordinary_tip.distance_to(actor.sockets.trail_tip.global_position);smallest_draw=minf(smallest_draw,drawn)
      assert(drawn>.04,"Critical preparation visibly draws the lance farther back")
      for key in ["critical_windup","strike"]:
       var previous=[]
       for step in range(33):
        sample(actor,key,step/32.0)
        var originals=[]
        for bone in range(rig.get_bone_count()):originals.append([rig.get_bone_pose_position(bone),rig.get_bone_pose_scale(bone)])
        var input=arms.solve();var rotations=[]
        for bone in arms.chain:rotations.append(rig.get_bone_pose_rotation(bone))
        if not previous.is_empty():
         for index in range(rotations.size()):
          var delta=rotations[index].angle_to(previous[index]);continuity=maxf(continuity,delta);assert(delta<.22,"Dense critical arm and shoulder motion stays continuous")
        previous=rotations
        if not seating.is_empty() and item=="iron_lance" and side==1 and height==1.1 and step%8==0:check_seating(actor,rig,seating)
        for bone in range(rig.get_bone_count()):assert(rig.get_bone_pose_position(bone)==originals[bone][0] and rig.get_bone_pose_scale(bone)==originals[bone][1],"Critical preparation keeps the source bone lengths and scales")
        for index in range(arms.chain.size()):rig.set_bone_pose_rotation(arms.chain[index],input[index])
        rig.force_update_all_bone_transforms()
        for mesh in weapon.find_children("*","MeshInstance3D",true,false):
         for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
          var y=mesh.to_global(vertex).y;minimum=minf(minimum,y);assert(y>.01,"Critical spear shaft and head stay above the floor")
        count+=1
       if key=="strike":
        var error=actor.sockets.trail_tip.global_position.distance_to(target);gap=maxf(gap,error);assert(error<.006,"Critical thrust reaches the exact standing/mounted target")
      for key in ["idle","windup","recover","hit","critical_hit","down","guard","throw_windup","critical_throw_windup"]:
       grip.combat_pose("critical_windup");grip.combat_pose(key);assert(not grip.critical_prepared,"Other actions clear critical melee preparation, including throws")
    actor.queue_free();await process_frame
 world.queue_free();await process_frame
 print("PASS: ",count," critical lance samples, nine base/promoted outfits, four weapons, two directions/heights, minimum draw ",smallest_draw," m, floor ",minimum," m, contact gap ",gap," m, joint step ",continuity," rad, fixed bones and action resets")
 quit()

static func check_seating(actor,rig,cache):
 for entry in cache:
  var mesh=entry[0];var arrays=entry[1];var vertices=arrays[Mesh.ARRAY_VERTEX];var transforms=[]
  for bind in range(entry[2].size()):transforms.append(rig.get_bone_global_pose(entry[2][bind])*mesh.skin.get_bind_pose(bind))
  for vertex in range(vertices.size()):
   var point=vertices[vertex]
   if not transforms.is_empty():
    point=Vector3.ZERO;var bones=arrays[Mesh.ARRAY_BONES];var weights=arrays[Mesh.ARRAY_WEIGHTS];var influences=bones.size()/vertices.size()
    for influence in range(influences):
     var at=vertex*influences+influence;point+=(transforms[bones[at]]*vertices[vertex])*weights[at]
    point=rig.to_global(point)
   else:point=mesh.to_global(point)
   var local=actor.mount.bones.Horse.to_local(point)
   assert(not RiderFit.profile_inside(local,false) and not RiderFit.profile_inside(local,true),"Critical torso turn keeps the seated body and promotion costume outside the horse: "+str(mesh.name))
