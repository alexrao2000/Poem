extends SceneTree
const Neck=preload("res://tests/test_authored_gaze.gd")
var character_ids=["petra","oren","rook"]
var study_ids=["knight_female","knight_male"]
var action_keys=["throw_windup","critical_throw_windup","throw","critical_throw","throw_recover"]
func _initialize():call_deferred("run")
func run():
 var world=Node3D.new();root.add_child(world);world.position=Vector3(13,0,9)
 var rules=load("res://scripts/rules.gd").new();var models=load("res://scripts/debug_source_models.gd").new(study_ids);var count=0;var minimum_dot=1.0
 for id in character_ids:
  var source=rules.roster.filter(func(unit):return unit.id==id)[0];var promotions=[""]
  promotions.append_array(rules.promotions.filter(func(path):return path.base==source.job).map(func(path):return path.id))
  for promotion in promotions:
   var unit=source.duplicate(true);unit.team="player";unit.promotion=promotion
   if unit.weapon=="lance":unit.item="javelin"
   var actor=models.build(world,unit,Vector3(1,0,0));assert(actor!=null);await process_frame
   var gaze=actor.model.get_node("Identity").gaze;var rig=gaze.rig;var face=rig.get_node("Face");var neck=rig.get_node("PortraitNeck");var poses=[]
   rig.skeleton_updated.connect(func():
    poses.clear()
    for bone in range(rig.get_bone_count()):poses.append(rig.get_bone_global_pose(bone)))
   var target=Marker3D.new();world.add_child(target);actor.face_opponent(target)
   for heading in [-PI/2,PI/2]:
    actor.rotation.y=heading
    for height in [1.5,2.4]:
     target.global_position=actor.to_global(Vector3(.8,height,-4));actor.aim_at(target.global_position)
     actor.pose("idle",.02);await create_timer(.45).timeout
     assert(gaze.modifier.active and gaze.modifier.influence>.98)
     for key in action_keys:
      var weight=gaze.modifier.influence
      await actor.pose(key,.04).finished
      assert(gaze.modifier.active and gaze.modifier.influence>=weight,"Special actions never drop the existing gaze blend")
      var origin=rig.get_bone_pose_position(gaze.head);var scale=rig.get_bone_pose_scale(gaze.head)
      await create_timer(.16).timeout
      var direction=(gaze.target.global_position-face.global_position).normalized();var dot=face.global_basis.z.normalized().dot(direction);minimum_dot=minf(minimum_dot,dot)
      assert(dot>.998,"Special-action head follows bounded target: %s %s %s dot %s"%[id,promotion,key,dot])
      var local=actor.global_basis.orthonormalized().inverse()*direction
      assert(absf(atan2(-local.x,-local.z))<=gaze.YAW+.001 and absf(atan2(local.y,Vector2(local.x,local.z).length()))<=gaze.PITCH+.001)
      assert(rig.get_bone_pose_position(gaze.head)==origin and rig.get_bone_pose_scale(gaze.head)==scale,"Gaze retains head origin and scale")
      assert(poses[gaze.head].is_equal_approx(face.transform),"Original face and skin share the final native head pose")
      var neck_bone=rig.find_bone("neck_01")
      for vertex in Neck.skin_vertices(rig,neck,poses):assert(vertex.is_finite() and vertex.distance_to(poses[neck_bone].origin)<.22,"Special-action gaze retains the fitted neck skin")
      count+=1
   for key in ["hit","critical_hit","evade","down","victory","victory_flourish"]:
    actor.pose(key,.02);assert(not gaze.modifier.active and gaze.modifier.influence==0)
    await create_timer(.04).timeout;assert(not gaze.modifier.active,"Reaction and finishing head poses remain authored")
   actor.pose(action_keys[0],.04);await create_timer(.2).timeout;assert(gaze.modifier.active)
   target.hide();await process_frame;await process_frame;assert(not gaze.modifier.active,"Hidden recipients release special-action tracking")
   target.show();actor.pose(action_keys[0],.02);await create_timer(.2).timeout;assert(gaze.modifier.active)
   target.queue_free();await process_frame;await process_frame;assert(not gaze.modifier.active,"Freed recipients release special-action tracking")
   actor.queue_free();await process_frame
 world.queue_free();await process_frame
 print("PASS: ",count," special-action native gaze cases across nine base/promoted outfits, both headings and target heights; minimum alignment ",minimum_dot,"; continuous blend, fixed head origin/scale, fitted neck, authored reactions and hidden/freed target cleanup");quit()
