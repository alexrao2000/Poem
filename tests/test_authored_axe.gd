extends SceneTree
const Models=preload("res://scripts/debug_source_models.gd")
const Rules=preload("res://scripts/rules.gd")
var character_id="mara"
func _initialize():call_deferred("run")
func sample(actor,key: String,fraction: float):
 var mapping=actor.poses[key];actor.player.stop();actor.player.play(mapping.clip,0);actor.player.seek(lerpf(mapping.from,mapping.to,fraction),true,true);actor.player.pause();actor.refresh_skeleton()
func run():
 var models=Models.new(["corsair_female","corsair_male"]);var rules=Rules.new();var unit=rules.roster.filter(func(value):return value.id==character_id)[0].duplicate(true);unit.team="player"
 var stage=Node3D.new();root.add_child(stage);var lowest=INF;var worst_extra=0.0;var contact_gap=0.0;var count=0
 for item in ["iron_axe","hatchet","great_axe","war_hammer"]:
  unit.item=item;var actor=models.build(stage,unit,Vector3(35,0,0));assert(actor!=null and models.models.issues.is_empty());await process_frame;actor.set_process(false)
  var rig=actor.model.get_node("Rig/Armature/Skeleton3D");var hand=rig.get_node("WeaponHand");var grip=hand.get_node("Grip");var weapon=grip.get_node("Weapon");var hold=grip.floor_fit;var fixed=grip.transform
  assert(hold.model==actor.model and hold.corners.size()==8 and actor.pose_constraints.has(hold))
  assert(grip.equipped==item and actor.contact!=null and actor.model.get_node("Identity").cloak_cut=="mantle")
  var head=weapon.get_node("HammerHead" if item=="war_hammer" else "AxeBlade")
  assert(head.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==load("res://scripts/equipment_visuals.gd").blade(item).surface_get_arrays(0)[Mesh.ARRAY_VERTEX],"The original axe head is preserved")
  var meshes=weapon.find_children("*","MeshInstance3D",true,false);var originals=[]
  for bone in range(rig.get_bone_count()):originals.append([rig.get_bone_pose_position(bone),rig.get_bone_pose_scale(bone)])
  for height in [0.0,.65]:
   actor.position.y=height;actor.rotation.y=-PI/2 if height==0 else PI/2
   for key in ["idle","advance","windup","strike","recover","hit","evade","down","victory"]:
    var previous=null;var previous_source=null;var steps=129 if key=="down" else 17
    for step in range(steps):
     sample(actor,key,float(step)/(steps-1))
     var actual=hand.basis.get_rotation_quaternion();var source=rig.get_bone_global_pose(rig.find_bone("hand_r")).basis.get_rotation_quaternion()
     if previous!=null:
      var extra=previous.angle_to(actual)-previous_source.angle_to(source);worst_extra=maxf(worst_extra,extra)
      assert(extra<.065,"Floor correction does not introduce a wrist flip between dense fall samples")
     previous=actual;previous_source=source
     if key!="down":assert(hand.transform.is_equal_approx(rig.get_bone_global_pose(rig.find_bone("hand_r"))),"Standing attacks retain the original source arm pose")
     var rotations=[];var positions=[]
     for bone in range(rig.get_bone_count()):rotations.append(rig.get_bone_pose_rotation(bone));positions.append(rig.get_bone_pose_position(bone))
     var transform=hand.transform;actor.refresh_skeleton();assert(hand.transform.is_equal_approx(transform) and grip.transform==fixed)
     for bone in range(rig.get_bone_count()):
      assert(rig.get_bone_pose_rotation(bone).is_equal_approx(rotations[bone]) and rig.get_bone_pose_position(bone).is_equal_approx(positions[bone]) and rig.get_bone_pose_scale(bone)==originals[bone][1],"Sampling restores input rotations and never translates or stretches a source bone")
     for mesh in meshes:
      for surface in range(mesh.mesh.get_surface_count()):
       for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
        var point=mesh.to_global(vertex);lowest=minf(lowest,point.y-height)
        assert(point.is_finite() and point.y>=height+.01,"Broad axe and hammer heads clear the floor on either side, including relocated dense falls")
     count+=1
  actor.position.y=0
  for side in [-1,1]:
   actor.rotation.y=-side*PI/2
   for target_height in [1.1,1.85]:
    var point=actor.position+Vector3(side*1.3,target_height,0);actor.aim_at(point);actor.contact.influence=1;sample(actor,"strike",1)
    var edge=actor.weapon_trail_points();var gap=Geometry3D.get_closest_point_to_segment(point,edge[0],edge[1]).distance_to(point);contact_gap=maxf(contact_gap,gap)
    assert(gap<.01,"Every fitted blade edge reaches infantry and mounted targets on either side")
  actor.contact.influence=0;sample(actor,"down",.7)
  for influence in [0.0,.5,1.0]:
   hold.influence=influence;actor.refresh_skeleton();var direct=hand.transform
   await process_frame;await process_frame
   assert(hand.transform.is_equal_approx(direct),"Native and direct floor correction agree at partial influence")
  hold.influence=1
  var fade=load("res://scripts/combat_defeat.gd").new();stage.add_child(fade);fade.begin(actor);fade.motion.pause();fade.apply_visibility(.4)
  assert(weapon.get_node("AxeShaft").material_override.albedo_color.a<.401)
  fade.queue_free();actor.queue_free();await process_frame
 stage.queue_free();await process_frame
 print("PASS: ",count," fitted axe/hammer poses, original heads, unchanged standing swings and source bones, floor minimum ",lowest," m, dense wrist correction excess ",worst_extra," rad, two-sided foot/mounted contact gap ",contact_gap," m, native/direct partial influence and fade")
 quit()
