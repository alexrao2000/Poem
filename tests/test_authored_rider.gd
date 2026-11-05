extends SceneTree
const Vertices=preload("helpers/authored_vertices.gd")
const Body=preload("res://scripts/mount_body.gd")
const Projectile=preload("res://scripts/combat_projectile.gd")
var gender="female"
var character_id="una"
func _initialize():call_deferred("run")
func profile_inside(point: Vector3,neck: bool) -> bool:
 var rows=Body.NECK if neck else Body.TORSO;var along=point.y if neck else point.z
 if along<rows[0][0] or along>rows[-1][0]:return false
 var index=0
 while index<rows.size()-2 and along>rows[index+1][0]:index+=1
 var share=(along-rows[index][0])/(rows[index+1][0]-rows[index][0]);var row=[]
 for column in range(4):row.append(lerpf(rows[index][column],rows[index+1][column],share))
 var q=pow(point.x/row[2],2)+pow((point.z-row[1])/row[3],2) if neck else pow(point.x/row[1],2)+pow((point.y-(row[2]+row[3])*.5)/((row[3]-row[2])*.5),2)
 return q<.94
func run():
 var world=Node3D.new();root.add_child(world);var rules=load("res://scripts/rules.gd").new()
 var unit=rules.roster.filter(func(value):return value.id==character_id)[0].duplicate(true);unit.team="player";unit.item="javelin"
 var models=load("res://scripts/debug_source_models.gd").new(["rider_"+gender]);var actor=models.build(world,unit,Vector3(35,.65,0));assert(actor!=null and models.models.issues.is_empty());await process_frame;actor.set_process(false)
 var rig=actor.model.get_node("Rig/Armature/Skeleton3D");var grip=rig.get_node("WeaponHand/Grip");var arms=grip.arms;var mount=actor.mount;mount.set_process(false)
 assert(actor.model.get_node("Identity").armor.anchors.size()==5 and not rig.has_node("KnightShield"))
 assert(actor.player.get_animation_list().size()==19 and arms.chain.size()==14)
 var worst=0.0;var collisions={};var lowest=INF;var count=0;var all_geometry=Vertices.prepare(actor)
 var cache=all_geometry.filter(func(entry):return "Peasant" in str(entry[0].name) or str(entry[0].name) in ["Cuirass","Pauldron","ElbowGuard"])
 for key in ["idle","windup","strike","recover","hit","evade","throw_windup","throw","throw_recover","down"]:
  actor.aim_at(actor.to_global(Vector3(0,1.1,-4 if key.begins_with("throw") else -2.1)))
  var mapping=actor.poses[key];actor.player.get_animation(mapping.clip).loop_mode=Animation.LOOP_NONE;var previous=[]
  for step in range(129):
   for listener in actor.pose_listeners:listener.combat_pose(key)
   actor.player.stop();actor.player.play(mapping.clip,0);actor.player.seek(lerpf(mapping.from,mapping.to,step/128.0),true,true);actor.player.pause();actor.refresh_skeleton()
   var original=arms.solve();var current=[]
   for bone in arms.chain:current.append(rig.get_bone_pose_rotation(bone))
   if not previous.is_empty():
    for index in range(current.size()):
     var delta=previous[index].angle_to(current[index]);worst=maxf(worst,delta)
     assert(delta<.13,"Dense seated body, both arms and leg rotations remain continuous: %s %s %s"%[key,rig.get_bone_name(arms.chain[index]),delta])
   previous=current
   if step%8==0:
    for entry in cache:
     var mesh=entry[0];var arrays=entry[1];var positions=arrays[Mesh.ARRAY_VERTEX];var transforms=[]
     for bind in range(entry[2].size()):transforms.append(rig.get_bone_global_pose(entry[2][bind])*mesh.skin.get_bind_pose(bind))
     for vertex in range(positions.size()):
      var point=positions[vertex]
      if not transforms.is_empty():
       point=Vector3.ZERO;var bones=arrays[Mesh.ARRAY_BONES];var weights=arrays[Mesh.ARRAY_WEIGHTS];var influences=bones.size()/positions.size()
       for influence in range(influences):
        var at=vertex*influences+influence;point+=(transforms[bones[at]]*positions[vertex])*weights[at]
       point=rig.to_global(point)
      else:point=mesh.to_global(point)
      var local=mount.bones.Horse.to_local(point)
      if profile_inside(local,false) or profile_inside(local,true):collisions[key+":"+str(mesh.name)]=true
   for index in range(arms.chain.size()):rig.set_bone_pose_rotation(arms.chain[index],original[index])
   rig.force_update_all_bone_transforms()
   if step%8==0:lowest=minf(lowest,Vertices.minimum(actor,all_geometry)-actor.global_position.y)
   count+=1
 assert(collisions.is_empty(),"Seated clothing and light armor avoid the horse torso and neck: "+str(collisions))
 assert(lowest>-.0001,"Complete rider, horse and fitted lance remain above the floor")
 var anchors=rig.find_children("*","BoneAttachment3D",true,false)
 for key in ["windup","strike","throw_windup","throw_recover","down"]:
  await actor.pose(key,.02).finished
  for amount in [0.0,.5,1.0]:
   arms.influence=amount;actor.refresh_skeleton();var direct=anchors.map(func(anchor):return anchor.transform)
   await process_frame;await process_frame
   for index in range(anchors.size()):assert(anchors[index].transform.is_equal_approx(direct[index]),"Native and direct seated combat solve agree for all attachments and partial influence")
 arms.influence=1
 var tip_gap=0.0;var release_gap=0.0
 for side in [-1,1]:
  actor.rotation.y=-side*PI/2
  for height in [1.1,1.85]:
   var point=actor.position+Vector3(side*2.1,height,.12);actor.aim_at(point)
   await actor.pose("windup",.02).finished;await actor.pose("strike",.02).finished
   tip_gap=maxf(tip_gap,actor.weapon_trail_points()[1].distance_to(point));assert(tip_gap<.005,"Mounted thrust endpoint gap: "+str(tip_gap))
   point=actor.position+Vector3(side*4,height,.12);actor.aim_at(point)
   await actor.pose("throw_windup",.02).finished;await actor.pose("throw",.02).finished
   var weapon=actor.projectile_source();assert(not weapon.visible)
   var flight=Projectile.new();world.add_child(flight);flight.launch(actor.socket_position("projectile"),point,"lance",.23,"",{},false,weapon).pause()
   var copy=flight.body.get_node("HeldSpear")
   for mesh in weapon.find_children("*","MeshInstance3D",true,false):
    var copied=copy.get_node(weapon.get_path_to(mesh))
    for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:release_gap=maxf(release_gap,mesh.to_global(vertex).distance_to(copied.to_global(vertex)))
   assert(release_gap<.0001,"Actual mounted javelin release preserves the fitted weapon")
   await actor.pose("recover",.02).finished;assert(not weapon.visible and actor.player.assigned_animation=="LanceThrowRecover")
   flight.queue_free();await process_frame
 actor.queue_free();await process_frame;world.queue_free();await process_frame
 print("PASS: ",character_id," ",count," fitted seated poses, fourteen-bone continuity ",worst," rad, horse clearance, full outfit floor ",lowest," m, foot/mounted melee tip gap ",tip_gap," m and fitted flight gap ",release_gap," m")
 quit()
