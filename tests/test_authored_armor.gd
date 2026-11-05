extends SceneTree
const Vertices=preload("helpers/authored_vertices.gd")
var study_key="knight_female"
var character_id="petra"
func _initialize():call_deferred("run")
func run():
 var world=Node3D.new();root.add_child(world);var rules=load("res://scripts/rules.gd").new()
 var unit=rules.roster.filter(func(value):return value.id==character_id)[0].duplicate(true);unit.team="player";unit.item="riders_bane"
 var models=load("res://scripts/debug_source_models.gd").new([study_key]);var actor=models.build(world,unit,Vector3(35,.65,0));var other=models.build(world,unit,Vector3(40,0,0));await process_frame
 actor.set_process(false);var rig=actor.model.get_node("Rig/Armature/Skeleton3D");var identity=actor.model.get_node("Identity");var armor=identity.armor
 assert(armor!=null and armor.anchors.size()==11 and identity.identity==character_id)
 var steel=rig.get_node("KnightCuirass/Plate/Cuirass").material_override
 assert(steel!=other.model.get_node("Rig/Armature/Skeleton3D/KnightCuirass/Plate/Cuirass").material_override)
 assert(is_equal_approx(steel.get_shader_parameter("fabric_detail"),.15) and steel.get_shader_parameter("paint_average").is_equal_approx(Vector3(.229348,.231699,.239027)))
 assert(not steel.get_shader_parameter("cloth_floor_enabled"),"Rigid plates are never flattened by the cloth shader")
 var mounts=rig.find_children("*","MeshInstance3D",true,false).filter(func(mesh):return mesh.get_meta("shield_mount",false))
 assert(mounts.size()==4)
 for mesh in mounts:assert(mesh.get_active_material(0) is StandardMaterial3D and mesh.get_active_material(0).albedo_color==Color("554337"))
 var cache=Vertices.prepare(actor);var lowest=INF;var count=0;var arms=rig.get_node("WeaponHand/Grip").arms
 for key in ["idle","advance","windup","strike","recover","hit","evade","down","victory"]:
  for listener in actor.pose_listeners:listener.combat_pose(key)
  var mapping=actor.poses[key];actor.player.get_animation(mapping.clip).loop_mode=Animation.LOOP_NONE
  var steps=513 if key=="down" else 33
  for step in range(steps):
   actor.player.stop();actor.player.play(mapping.clip,0);actor.player.seek(lerpf(mapping.from,mapping.to,float(step)/(steps-1)),true,true);actor.player.pause();actor.refresh_skeleton()
   var poses=[]
   for bone in range(rig.get_bone_count()):poses.append([rig.get_bone_pose_position(bone),rig.get_bone_pose_rotation(bone)])
   var y=Vertices.minimum(actor,cache)-actor.position.y;lowest=minf(lowest,y);count+=1
   assert(y>.01,"Actual skinned body, shield, armor and lance stay above the relocated floor throughout the fitted fall")
   for bone in range(rig.get_bone_count()):assert(rig.get_bone_pose_position(bone).is_equal_approx(poses[bone][0]) and rig.get_bone_pose_rotation(bone).is_equal_approx(poses[bone][1]))
 var anchors=rig.find_children("*","BoneAttachment3D",true,false)
 for key in ["windup","down"]:
  for listener in actor.pose_listeners:listener.combat_pose(key)
  var mapping=actor.poses[key];actor.player.stop();actor.player.play(mapping.clip,0);actor.player.seek(lerpf(mapping.from,mapping.to,.7),true,true);actor.player.pause()
  for amount in [0.0,.5,1.0]:
   arms.influence=amount;actor.refresh_skeleton();var direct=anchors.map(func(anchor):return anchor.transform)
   await process_frame;await process_frame
   for index in range(anchors.size()):assert(anchors[index].transform.is_equal_approx(direct[index]),"Late-added armor and shield match native skeleton updates at partial influence")
 arms.influence=1
 assert(actor.socket_position("guard").is_equal_approx(rig.get_node("KnightShield/Plate/Guard").global_position))
 var fade=load("res://scripts/combat_defeat.gd").new();world.add_child(fade);fade.begin(actor);fade.motion.pause();fade.apply_visibility(.4)
 assert(armor.surfaces[0].get_shader_parameter("defeat_visibility")==.4)
 assert(not other.model.get_node("Identity").armor.surfaces[0].shader.code.contains("defeat_visibility"))
 fade.queue_free();actor.queue_free();other.queue_free();await process_frame;world.queue_free();await process_frame
 print("PASS: ",count," full skinned Knight outfit poses, minimum floor clearance ",lowest," m, fitted rigid armor and shield, private subdued metal, leather mounts, all-attachment native/direct influence, shield impact and defeat isolation")
 quit()
